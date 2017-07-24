-------------------------------------------------------------------------------
-- File       : SadcBufferReader.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-14
-- Last update: 2017-07-14
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of ''LZ Test Stand Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
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
      AXI_ERROR_RESP_G  : slv(1 downto 0)          := AXI_RESP_DECERR_C
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
      -- Trigger information from data writers (adcClk)
      hdrDout           : in  Slv32Array(7 downto 0);
      hdrValid          : in  slv(7 downto 0);
      hdrRd             : out slv(7 downto 0);
      -- Buffer handshake to/from data writers (adcClk)
      memWrAddr         : in  Slv32Array(7 downto 0);
      memFull           : out slv(7 downto 0);
      -- AxiStream output
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
      trigSize       : slv(31 downto 0);
      hdrDout        : slv(15 downto 0);
      rdSize         : slv(8 downto 0);
      memFull        : slv(7 downto 0);
      buffState      : BuffStateType;
      rMaster        : AxiReadMasterType;
      channelSel     : integer;
      ackCount       : Slv32Array(7 downto 0);
      errCount       : Slv32Array(7 downto 0);
      rdPtr          : Slv32Array(7 downto 0);
      rdPtrValid     : Slv2Array(7 downto 0);
      rdPtrRst       : slv(7 downto 0);
      txMaster       : AxiStreamMasterType;
      hdrCnt         : integer;
      rdHigh         : sl;
      first          : sl;
      last           : sl;
   end record TrigType;
   
   constant TRIG_INIT_C : TrigType := (
      reset          => x"0001",
      hdrRd          => (others => '0'),
      trigSize       => (others => '0'),
      hdrDout        => (others => '0'),
      rdSize         => (others => '0'),
      memFull        => (others => '0'),
      buffState      => IDLE_S,
      rMaster        => axiReadMasterInit(AXI_CONFIG_C, AXI_BURST_C, AXI_CACHE_C),
      channelSel     => 0,
      ackCount       => (others => (others => '0')),
      errCount       => (others => (others => '0')),
      rdPtr          => (others => (others => '0')),
      rdPtrValid     => (others => (others => '0')),
      rdPtrRst       => (others => '0'),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      hdrCnt         => 0,
      rdHigh         => '0',
      first          => '0',
      last           => '0'
   );
   
   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      ackCount       : Slv32Array(7 downto 0);
      errCount       : Slv32Array(7 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      ackCount       => (others => (others => '0')),
      errCount       => (others => (others => '0'))
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal txSlave : AxiStreamSlaveType;
   
   signal axiDataRd  : slv(31 downto 0);    -- ONLY FOR SIMULATION
   
begin

   axiDataRd  <= axiReadSlave.rdata(31 downto 0);    -- ONLY FOR SIMULATION
   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, axiReadSlave, axilReadMaster, axilWriteMaster, txSlave, reg, trig,
      hdrDout, hdrValid, memWrAddr) is
      variable vreg     : RegType;
      variable vtrig    : TrigType;
      variable regCon   : AxiLiteEndPointType;
   begin
      -- Latch the current value
      vreg := reg;
      vtrig := trig;
      
      -- keep reset for several clock cycles
      vtrig.reset := trig.reset(14 downto 0) & '0';
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vreg.ackCount        := trig.ackCount;
      vreg.errCount        := trig.errCount;
      
      ------------------------------------------------
      -- register access
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      -- Map the registers
      for ch in 7 downto 0 loop
         axiSlaveRegisterR(regCon, x"000"+toSlv(ch*4, 12), 0, reg.ackCount(ch));
         axiSlaveRegisterR(regCon, x"020"+toSlv(ch*4, 12), 0, reg.errCount(ch));
      end loop;
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      ------------------------------------------------
      -- stop reader when wrPtr approaches rdPtr
      ------------------------------------------------
      
      vtrig.memFull  := (others=>'0');
      vtrig.rdPtrRst := (others=>'0');
      vtrig.hdrRd    := (others=>'0');
      
      for ch in 7 downto 0 loop
         
         -- delayed signal to start the FSM after the 1st FIFO word is read
         vtrig.rdPtrValid(ch)(1) := trig.rdPtrValid(ch)(0);
         
         -- store the buffer pointer until it is read out
         if hdrValid(ch) = '1' and trig.rdPtrValid(ch)(0) = '0' then
            vtrig.rdPtr(ch)      := hdrDout(ch);
            vtrig.rdPtrValid(ch)(0) := '1';
            vtrig.hdrRd(ch)      := '1';
         elsif trig.rdPtrRst(ch) = '1' then
            vtrig.rdPtr(ch)      := (others=>'0');
            vtrig.rdPtrValid(ch) := "00";
         end if;
         
         -- stop the writer channel when full
         if trig.rdPtr(ch)(31) /= memWrAddr(ch)(31) and trig.rdPtrValid(ch) /= 0 then
            --if memWrAddr(ch)(ADDR_BITS_G-1 downto 0) + toSlv(4096, ADDR_BITS_G+1) >= trig.rdPtr(ch)(ADDR_BITS_G-1 downto 0) then
            if memWrAddr(ch)(ADDR_BITS_G-1 downto 0) >= trig.rdPtr(ch)(ADDR_BITS_G-1 downto 0) then
               vtrig.memFull(ch) := '1';
            end if;
         end if;
         
      end loop;
      
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
      -- Track read status
      if axiReadSlave.rvalid = '1' and axiReadSlave.rlast = '1' then
         if axiReadSlave.rresp /= 0 then
            vtrig.errCount(trig.channelSel) := trig.errCount(trig.channelSel) + 1;
         else
            vtrig.ackCount(trig.channelSel) := trig.ackCount(trig.channelSel) + 1;
         end if;
      end if;
      
      ----------------------------------------------------------------------
      -- Buffer read state machine
      ----------------------------------------------------------------------
      
      case trig.buffState is
      
         when IDLE_S =>
            if trig.reset = 0 then
               if trig.rdPtrValid(trig.channelSel)(1) = '1' then
                  vtrig.trigSize    := hdrDout(trig.channelSel);   -- store trigSize
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
                  vtrig.txMaster.tData(15 downto 0) := x"00" & toSlv(trig.channelSel, 8);       -- Slow ADC channel number
               elsif trig.hdrCnt = 1 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, vtrig.txMaster, '1');
                  vtrig.txMaster.tData(15 downto 0) := x"1000";                                 -- reserved
               elsif trig.hdrCnt = 2 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- trigSize
                  vtrig.hdrRd(trig.channelSel)      := '1';
               elsif trig.hdrCnt = 3 then
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- trigSize
               elsif trig.hdrCnt = 4 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- trigOffset
                  vtrig.hdrRd(trig.channelSel)      := '1';
               elsif trig.hdrCnt = 5 then
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- trigOffset
               elsif trig.hdrCnt = 6 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- gTime
                  vtrig.hdrRd(trig.channelSel) := '1';
               elsif trig.hdrCnt = 7 then
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- gTime
               elsif trig.hdrCnt = 8 then
                  vtrig.hdrDout                     := hdrDout(trig.channelSel)(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := hdrDout(trig.channelSel)(15 downto 0);   -- gTime
                  vtrig.hdrRd(trig.channelSel) := '1';
               else
                  vtrig.txMaster.tData(15 downto 0) := trig.hdrDout;                            -- gTime
                  vtrig.hdrCnt      := 0;
                  -- Set the memory address aligned to 32 bits
                  vtrig.rMaster.araddr := resize(trig.rdPtr(trig.channelSel)(30 downto 2) & "00", vtrig.rMaster.araddr'length);
                  -- Validate address
                  vtrig.buffState   := ADDR_S;
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
               if (trig.rdPtr(trig.channelSel)(1 downto 0) /= 0) then
                  if (trig.first = '1' and trig.rdHigh = '0') then
                     -- stream not valid
                     vtrig.txMaster.tValid := '0';
                     -- do not count
                     vtrig.trigSize := trig.trigSize;
                  elsif (vtrig.last = '1' and trig.rdHigh = '1' and trig.rMaster.arlen = ARLEN_C) then
                     -- for unaligned triggers correct address to one cell before
                     -- make sure that it rolls at the end of the buffer space
                     vtrig.rMaster.araddr := trig.rMaster.araddr(63 downto ADDR_BITS_G) & (trig.rMaster.araddr(ADDR_BITS_G-1 downto 0) - 4);
                     -- stream not valid
                     vtrig.txMaster.tValid := '0';
                     -- do not count
                     vtrig.trigSize := trig.trigSize;
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
                  -- reset the read pointer
                  vtrig.rdPtrRst(trig.channelSel) := '1';
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
      memFull        <= trig.memFull;
      hdrRd          <= trig.hdrRd;
      
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
      VALID_THOLD_G       => 0,     -- =0 = only when frame ready
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
