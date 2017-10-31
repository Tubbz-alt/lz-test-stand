-------------------------------------------------------------------------------
-- File       : SadcBufferReader.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-14
-- Last update: 2017-07-14
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'LZ Test Stand Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LZ Test Stand Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPkg.all;
use work.SsiPkg.all;

entity SadcBufferReader is
   generic (
      TPD_G             : time                     := 1 ns;
      ADDR_BITS_G       : integer range 12 to 31   := 14;
      AXI_ERROR_RESP_G  : slv(1 downto 0)          := AXI_RESP_DECERR_C;
      PGP_LANE_G        : slv(3 downto 0)          := "0000";
      PGP_VC_G          : slv(3 downto 0)          := "0001"
   );
   port (
      -- ADC Clock Domain
      adcClk            : in  sl;
      adcRst            : in  sl;
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AXI Interface (adcClk)
      axiReadMaster     : out AxiReadMasterType;
      axiReadSlave      : in  AxiReadSlaveType;
      -- Trigger information from data writers (adcClk domain)
      hdrDout           : in  Slv32Array(7 downto 0);
      hdrValid          : in  slv(7 downto 0);
      hdrRd             : out slv(7 downto 0);
      -- Address information from data writers (adcClk domain)
      addrDout          : in  Slv32Array(7 downto 0);
      addrValid         : in  slv(7 downto 0);
      addrRd            : out slv(7 downto 0);
      -- AxiStream output (axisClk domain)
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisMaster        : out AxiStreamMasterType;
      axisSlave         : in  AxiStreamSlaveType
   );
end SadcBufferReader;

architecture rtl of SadcBufferReader is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 31,
      DATA_BYTES_C => 4,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8
   );
   
   constant AXI_BURST_C : slv(1 downto 0)     := "01";
   constant AXI_CACHE_C : slv(3 downto 0)     := "1111";
   constant ARLEN_C : slv(7 downto 0) := getAxiLen(AXI_CONFIG_C, 1024);
   
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   type BuffStateType is (
      IDLE_S,
      HDR_S,
      ADDR_S,
      MOVE_S
   );
   
   type TrigType is record
      reset          : slv(15 downto 0);
      hdrRd          : slv(7 downto 0);
      addrRd         : slv(7 downto 0);
      hdrDout        : slv(15 downto 0);
      trigSize       : slv(21 downto 0);
      trigType       : slv(4 downto 0);
      rdSize         : slv(8 downto 0);
      buffState      : BuffStateType;
      rMaster        : AxiReadMasterType;
      channelSel     : integer;
      smplCnt        : Slv32Array(7 downto 0);
      txMaster       : AxiStreamMasterType;
      hdrCnt         : integer;
      rdHigh         : sl;
      first          : sl;
      last           : sl;
      trigHdrType    : slv(2 downto 0);
   end record TrigType;
   
   constant TRIG_INIT_C : TrigType := (
      reset          => x"0001",
      hdrRd          => (others => '0'),
      addrRd         => (others => '0'),
      hdrDout        => (others => '0'),
      trigSize       => (others => '0'),
      trigType       => (others => '0'),
      rdSize         => (others => '0'),
      buffState      => IDLE_S,
      rMaster        => axiReadMasterInit(AXI_CONFIG_C, AXI_BURST_C, AXI_CACHE_C),
      channelSel     => 0,
      smplCnt        => (others => (others => '0')),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      hdrCnt         => 0,
      rdHigh         => '0',
      first          => '0',
      last           => '0',
      trigHdrType    => (others => '0')
   );
   
   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      smplCnt        : Slv32Array(7 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      smplCnt        => (others => (others => '0'))
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal txSlave : AxiStreamSlaveType;
   
   signal axiDataRd  : slv(31 downto 0);    -- ONLY FOR SIMULATION
   
   attribute keep : string;
   attribute keep of trig : signal is "true";
   
begin

   axiDataRd  <= axiReadSlave.rdata(31 downto 0);    -- ONLY FOR SIMULATION
   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, axiReadSlave, axilReadMaster, axilWriteMaster, txSlave, reg, trig,
      hdrDout, hdrValid, addrDout) is
      variable vreg        : RegType;
      variable vtrig       : TrigType;
      variable regCon      : AxiLiteEndPointType;
      variable rdAddrEnd   : slv(9 downto 0);
   begin
      -- Latch the current value
      vreg := reg;
      vtrig := trig;
      
      -- keep reset for several clock cycles
      vtrig.reset := trig.reset(14 downto 0) & '0';
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vreg.smplCnt         := trig.smplCnt;
      
      ------------------------------------------------
      -- register access
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      -- Map the registers
      for ch in 7 downto 0 loop
         axiSlaveRegisterR(regCon, x"000"+toSlv(ch*4, 12), 0, reg.smplCnt(ch));
      end loop;
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      ------------------------------------------------
      -- AXI read buffer transactions
      ------------------------------------------------
      
      -- Reset strobing Signals
      --if (axiReadSlave.rvalid = '1') then
         vtrig.rMaster.rready := '0';
      --end if;
      if (axiReadSlave.arready = '1') then
         vtrig.rMaster.arvalid := '0';
      end if;
      if (txSlave.tReady = '1') then
         vtrig.txMaster.tValid := '0';
         vtrig.txMaster.tLast  := '0';
         vtrig.txMaster.tUser  := (others => '0');
         vtrig.txMaster.tKeep  := (others => '1');
         vtrig.txMaster.tStrb  := (others => '1');
      end if;
      
      ----------------------------------------------------------------------
      -- Buffer read state machine
      ----------------------------------------------------------------------
      
      vtrig.hdrRd    := (others=>'0');
      vtrig.addrRd   := (others=>'0');
      
      case trig.buffState is
      
         when IDLE_S =>
            if trig.reset = 0 then
               if hdrValid(trig.channelSel) = '1' then
                  vtrig.trigSize    := hdrDout(trig.channelSel)(21 downto 0);    -- store trigSize
                  vtrig.trigType    := hdrDout(trig.channelSel)(31 downto 27);   -- store trigType
                  vtrig.buffState   := HDR_S;
               elsif trig.channelSel < 7 then
                  vtrig.channelSel := trig.channelSel + 1;
               else
                  vtrig.channelSel := 0;
               end if;
               vtrig.hdrCnt := 0;
            end if;            
         
         when HDR_S =>
            if vtrig.txMaster.tValid = '0' then
               vtrig.txMaster.tValid := '1';
               if trig.hdrCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, vtrig.txMaster, '1');
                  vtrig.txMaster.tData(15 downto 0) := x"00" & PGP_LANE_G & PGP_VC_G;           -- PGP lane and VC
               elsif trig.hdrCnt = 1 then
                  vtrig.txMaster.tData(15 downto 0) := x"0000";                                 -- reserved
               elsif trig.hdrCnt = 2 then
                  vtrig.txMaster.tData(15 downto 0) := x"00" & toSlv(trig.channelSel, 8);       -- Slow ADC channel number
               elsif trig.hdrCnt = 3 then
                  vtrig.txMaster.tData(15 downto 0) := x"1000";                                 -- reserved
               elsif trig.hdrCnt = 4 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- trigSize
                  vtrig.hdrRd(trig.channelSel)      := '1';
               elsif trig.hdrCnt = 5 then
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- trigSize
               elsif trig.hdrCnt = 6 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- trigOffset
                  vtrig.hdrRd(trig.channelSel)      := '1';
               elsif trig.hdrCnt = 7 then
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- trigOffset
               elsif trig.hdrCnt = 8 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- gTime
                  vtrig.hdrRd(trig.channelSel) := '1';
               elsif trig.hdrCnt = 9 then
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- gTime
               elsif trig.hdrCnt = 10 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- gTime
                  vtrig.hdrRd(trig.channelSel) := '1';
               else
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- gTime
                  vtrig.hdrCnt      := 0;
                  -- Set the memory address aligned to 32 bits
                  vtrig.rMaster.araddr := resize(addrDout(trig.channelSel)(30 downto 2) & "00", vtrig.rMaster.araddr'length);
                  -- check if the trigger has data
                  if trig.trigSize > 0 then
                     -- Validate address
                     vtrig.buffState   := ADDR_S;
                  else
                     vtrig.txMaster.tLast := '1';
                     -- move to the next channnel
                     if trig.channelSel < 7 then
                        vtrig.channelSel := trig.channelSel + 1;
                     else
                        vtrig.channelSel := 0;
                     end if;
                     vtrig.buffState   := IDLE_S;
                  end if;
               end if;
               vtrig.hdrCnt := trig.hdrCnt + 1;
            end if;
         
         when ADDR_S =>
            -- make sure that previous address was accepted
            -- make sure that the data from last transaction was read
            if (trig.rMaster.arvalid = '0')  and (trig.rMaster.rready = '0') then
               
               vtrig.rdSize := (others=>'0');
               
               -- Set the burst length               
               if trig.trigSize <= conv_integer(ARLEN_C)*2+1 then
                  -- trigger size divided by 2 as there are two samples in one read
                  vtrig.rMaster.arlen := trig.trigSize(8 downto 1);
               else
                  vtrig.rMaster.arlen := ARLEN_C;
               end if;
               
               -- correct ARLEN when burst exceeds the buffer
               rdAddrEnd := (2**10-1) - trig.rMaster.araddr(9 downto 0);
               if (((2**ADDR_BITS_G-1) - trig.rMaster.araddr(ADDR_BITS_G-1 downto 0) <= conv_integer(ARLEN_C)*4+1) and (vtrig.rMaster.arlen > rdAddrEnd(9 downto 2))) then
                  vtrig.rMaster.arlen := rdAddrEnd(9 downto 2);
               end if;
               
               -- Set the flag
               vtrig.rMaster.arvalid := '1';
               -- Next state
               vtrig.buffState := MOVE_S;
            end if;
            vtrig.rdHigh := '0';
            vtrig.first := '1';
            vtrig.last := '0';
         
         when MOVE_S =>
            
            -- Check if ready to move data
            if (vtrig.txMaster.tValid = '0') and (axiReadSlave.rvalid = '1') then
               
               -- stream valid flag and counter
               vtrig.txMaster.tValid := '1';
               vtrig.trigSize := trig.trigSize - 1;
               vtrig.smplCnt(trig.channelSel) := trig.smplCnt(trig.channelSel) + 1;
               
               vtrig.first := '0';
               if trig.rdSize = conv_integer(trig.rMaster.arlen) + 1 then
                  vtrig.last := '1';
               end if;
               
               -- switch in between lower and higher sample
               vtrig.rdHigh := not trig.rdHigh;
               if trig.rdHigh = '0' then
                  vtrig.txMaster.tData(15 downto 0) := axiReadSlave.rdata(15 downto 0);
                  -- Accept the data 
                  vtrig.rdSize := trig.rdSize + 1;
                  -- move addrress and make sure that it rolls at the end of the buffer space
                  vtrig.rMaster.araddr := trig.rMaster.araddr(63 downto ADDR_BITS_G) & (trig.rMaster.araddr(ADDR_BITS_G-1 downto 0) + 4);
                  -- acknowledge data readout
                  vtrig.rMaster.rready := '1';
               else
                  vtrig.txMaster.tData(15 downto 0) := axiReadSlave.rdata(31 downto 16);
               end if;
               
               -- if address is not 32 bit aligned must skip first and last sample in a burst (single or many)
               if (addrDout(trig.channelSel)(1 downto 0) /= 0) then
                  if (trig.first = '1' and trig.rdHigh = '0') then
                     -- stream not valid
                     vtrig.txMaster.tValid := '0';
                     -- do not count
                     vtrig.trigSize := trig.trigSize;
                     vtrig.smplCnt(trig.channelSel) := trig.smplCnt(trig.channelSel);
                  elsif (vtrig.last = '1' and trig.rdHigh = '1' and trig.rMaster.arlen = ARLEN_C) then
                     -- for unaligned triggers correct address to one cell before
                     -- make sure that it rolls at the end of the buffer space
                     vtrig.rMaster.araddr := trig.rMaster.araddr(63 downto ADDR_BITS_G) & (trig.rMaster.araddr(ADDR_BITS_G-1 downto 0) - 4);
                     -- stream not valid
                     vtrig.txMaster.tValid := '0';
                     -- do not count
                     vtrig.trigSize := trig.trigSize;
                     vtrig.smplCnt(trig.channelSel) := trig.smplCnt(trig.channelSel);
                  end if;
               end if;
               
               -- if all words in a burst are read move to next address state
               if vtrig.last = '1' then
                  vtrig.buffState := ADDR_S;
               end if;
               
               -- unless all samples in trigger are read
               -- then move to idle state
               if vtrig.trigSize = 0 then
                  -- repeat axi rready for the last in axi stream
                  vtrig.rMaster.rready := '1';
                  -- last in axi stream
                  vtrig.txMaster.tLast := '1';
                  vtrig.txMaster.tValid := '1';
                  -- move the read pointer
                  vtrig.addrRd(trig.channelSel) := '1';
                  -- move to the next channnel
                  if trig.channelSel < 7 then
                     vtrig.channelSel := trig.channelSel + 1;
                  else
                     vtrig.channelSel := 0;
                  end if;
                  vtrig.buffState := IDLE_S;
               end if;
               
            end if;
         
         when others =>
            vtrig.buffState := IDLE_S;
         
      end case;
      
      -- Reset      
      if (adcRst = '1') then
         vtrig := TRIG_INIT_C;
      end if;
      if (axilRst = '1') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn <= vreg;
      trigIn <= vtrig;

      -- Outputs
      axiReadMaster  <= trig.rMaster;
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      hdrRd          <= trig.hdrRd;
      addrRd         <= trig.addrRd;
      
   end process comb;

   seqR : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seqR;
   
   seqT : process (adcClk) is
   begin
      if (rising_edge(adcClk)) then
         trig <= trigIn after TPD_G;
      end if;
   end process seqT;
   
   ----------------------------------------------------------------------
   -- Streaming out FIFO
   ----------------------------------------------------------------------
   
   U_AxisOut : entity work.AxiStreamFifoV2
   generic map (
      -- General Configurations
      TPD_G               => TPD_G,
      PIPE_STAGES_G       => 1,
      SLAVE_READY_EN_G    => true,
      VALID_THOLD_G       => 1,     -- =0 = only when frame ready
      -- FIFO configurations
      BRAM_EN_G           => true,
      USE_BUILT_IN_G      => false,
      GEN_SYNC_FIFO_G     => false,
      CASCADE_SIZE_G      => 1,
      FIFO_ADDR_WIDTH_G   => 10,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 128,
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C
   )
   port map (
      -- Slave Port
      sAxisClk    => adcClk,
      sAxisRst    => adcRst,
      sAxisMaster => trig.txMaster,
      sAxisSlave  => txSlave,
      -- Master Port
      mAxisClk    => axisClk,
      mAxisRst    => axisRst,
      mAxisMaster => axisMaster,
      mAxisSlave  => axisSlave
   );
   
   

end rtl;
