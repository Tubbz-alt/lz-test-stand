-------------------------------------------------------------------------------
-- File       : SadcBufferWriter.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-07
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
use work.AxiPkg.all;

entity SadcBufferWriter is
   generic (
      TPD_G             : time                     := 1 ns;
      CHANNEL_G         : slv(2 downto 0)          := "000";
      ADDR_BITS_G       : integer range 12 to 28   := 14;
      AXI_ERROR_RESP_G  : slv(1 downto 0)          := AXI_RESP_DECERR_C
   );
   port (
      -- ADC interface
      adcClk            : in  sl;
      adcRst            : in  sl;
      adcData           : in  slv(15 downto 0);
      gTime             : in  slv(63 downto 0);
      extTrigger        : in  sl := '0';
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AXI Interface (adcClk)
      axiWriteMaster    : out AxiWriteMasterType;
      axiWriteSlave     : in  AxiWriteSlaveType;
      -- Trigger information to data reader (adcClk)
      hdrDout           : out slv(31 downto 0);
      hdrValid          : out sl;
      hdrRd             : in  sl;
      -- Address pointer to data reader (adcClk)
      addrDout          : out slv(31 downto 0);
      addrValid         : out sl;
      addrRd            : in  sl
   );
end SadcBufferWriter;

architecture rtl of SadcBufferWriter is

   constant AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 31,
      DATA_BYTES_C => 16,
      ID_BITS_C    => 1,
      LEN_BITS_C   => 8
   );
   
   constant AXI_BURST_C : slv(1 downto 0)     := "01";
   constant AXI_CACHE_C : slv(3 downto 0)     := "1111";
   constant AWLEN_C : slv(7 downto 0) := getAxiLen(AXI_CONFIG_C, 4096);
   
   constant HDR_SIZE_C        : integer := 4;
   constant HDR_ADDR_WIDTH_C  : integer := 9;

   constant EXT_IND_C      : integer := 0;
   constant INT_IND_C      : integer := 1;
   constant EMPTY_IND_C    : integer := 2;
   constant VETO_IND_C     : integer := 3;
   constant BAD_IND_C      : integer := 4;

   type BuffStateType is (
      IDLE_S,
      ADDR_S,
      MOVE_S
   );
   
   type TrigStateType is (
      IDLE_S,
      TRIG_ARM_S,
      INT_POST_S,
      WR_TRIG_S
   );
   
   type HdrStateType is (
      IDLE_S,
      WAIT_TRIG_INMEM_S,
      WR_HDR_S
   );
   
   type TrigType is record
      reset          : slv(15 downto 0);
      extTrigger     : slv(1 downto 0);
      gTime          : slv(63 downto 0);
      wrAddress      : slv(ADDR_BITS_G downto 0);  -- address and carry flag
      preAddress     : slv(ADDR_BITS_G downto 0);  -- address and carry flag
      enable         : sl;
      adcBufRdy      : sl;
      intSaveVeto    : sl;
      intPreThresh   : slv(15 downto 0);
      intPostThresh  : slv(15 downto 0);
      intVetoThresh  : slv(15 downto 0);
      intPostDelay   : slv(15 downto 0);
      postCnt        : slv(15 downto 0);
      intPreDelay    : slv(15 downto 0);
      actPreDelay    : slv(15 downto 0);
      samplesBuff    : slv(15 downto 0);
      trigLength     : slv(21 downto 0);  -- 22 bits * 4ns ~= 16ms max window
      extTrigSize    : slv(21 downto 0);  -- 22 bits * 4ns ~= 16ms max window
      trigPending    : sl;
      trigType       : slv(4 downto 0);
      trigAddr       : slv(31 downto 0);
      trigOffset     : slv(31 downto 0);
      trigState      : TrigStateType;
      buffState      : BuffStateType;
      hdrState       : HdrStateType;
      hdrData        : Slv32Array(HDR_SIZE_C-1 downto 0);
      hdrWrite       : sl;
      wMaster        : AxiWriteMasterType;
      ackCount       : slv(31 downto 0);
      errCount       : slv(31 downto 0);
      hdrFifoCnt     : integer;
      hdrFifoDin     : slv(31 downto 0);
      hdrFifoWr      : sl;
      addrFifoDin    : slv(31 downto 0);
      addrFifoWr     : sl;
      burstsInFifo   : slv(7 downto 0);
      bvalidCnt      : slv(7 downto 0);
      lostSamples    : slv(31 downto 0);
      lostTriggers   : slv(31 downto 0);
      dropIntTrigs   : slv(31 downto 0);
      trigIntDrop    : sl;
      rstCounters    : sl;
      memFull        : sl;
   end record TrigType;

   constant TRIG_INIT_C : TrigType := (
      reset          => x"0001",
      extTrigger     => (others => '0'),
      gTime          => (others => '0'),
      wrAddress      => (others => '0'),
      preAddress     => (others => '0'),
      enable         => '0',
      adcBufRdy      => '0',
      intSaveVeto    => '0',
      intPreThresh   => (others => '0'),
      intPostThresh  => (others => '0'),
      intVetoThresh  => (others => '0'),
      intPostDelay   => (others => '0'),
      postCnt        => (others => '0'),
      intPreDelay    => (others => '0'),
      actPreDelay    => (others => '0'),
      samplesBuff    => (others => '0'),
      trigLength     => (others => '0'),
      extTrigSize    => (others => '0'),
      trigPending    => '0',
      trigType       => (others => '0'),
      trigAddr       => (others => '0'),
      trigOffset     => (others => '0'),
      trigState      => IDLE_S,
      buffState      => IDLE_S,
      hdrState       => IDLE_S,
      hdrData        => (others=>(others=>'0')),
      hdrWrite       => '0',
      wMaster        => axiWriteMasterInit(AXI_CONFIG_C, '1', AXI_BURST_C, AXI_CACHE_C),
      ackCount       => (others => '0'),
      errCount       => (others => '0'),
      hdrFifoCnt     => 0,
      hdrFifoDin     => (others => '0'),
      hdrFifoWr      => '0',
      addrFifoDin    => (others => '0'),
      addrFifoWr     => '0',
      burstsInFifo   => (others => '0'),
      bvalidCnt      => (others => '0'),
      lostSamples    => (others => '0'),
      lostTriggers   => (others => '0'),
      dropIntTrigs   => (others => '0'),
      trigIntDrop    => '0',
      rstCounters    => '0',
      memFull        => '0'
   );
   
   type RegType is record
      enable         : sl;
      intSaveVeto    : sl;
      intPreThresh   : slv(15 downto 0);
      intPostThresh  : slv(15 downto 0);
      intVetoThresh  : slv(15 downto 0);
      intPreDelay    : slv(15 downto 0);
      intPostDelay   : slv(15 downto 0);
      extTrigSize    : slv(21 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      ackCount       : slv(31 downto 0);
      errCount       : slv(31 downto 0);
      lostSamples    : slv(31 downto 0);
      lostTriggers   : slv(31 downto 0);
      dropIntTrigs   : slv(31 downto 0);
      rstCounters    : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      enable         => '0',
      intSaveVeto    => '0',
      intPreThresh   => (others => '0'),
      intPostThresh  => (others => '0'),
      intVetoThresh  => (others => '0'),
      intPreDelay    => (others => '0'),
      intPostDelay   => (others => '0'),
      extTrigSize    => (others => '0'),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      ackCount       => (others => '0'),
      errCount       => (others => '0'),
      lostSamples    => (others => '0'),
      lostTriggers   => (others => '0'),
      dropIntTrigs   => (others => '0'),
      rstCounters    => '0'
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal hdrFifoFull   : sl;
   signal addrFifoFull  : sl;
   signal rdPtrValid    : sl;
   signal rdPtrDout     : slv(31 downto 0);
   
   signal wrAddrSig    : slv(ADDR_BITS_G-1 downto 0);    -- for simulation only
   signal wrPtrSig     : slv(ADDR_BITS_G-1 downto 0);    -- for simulation only
   signal rdPtrSig     : slv(ADDR_BITS_G-1 downto 0);    -- for simulation only
   signal wrAddrCSig   : sl;                             -- for simulation only
   signal wrPtrCSig    : sl;                             -- for simulation only
   signal rdPtrCSig    : sl;                             -- for simulation only
   signal wData        : slv(127 downto 0);              -- for simulation only
   signal wValid       : sl;                             -- for simulation only
   
   
begin
   
   
   wData  <= trig.wMaster.wdata(127 downto 0);
   wValid <= trig.wMaster.wvalid;
   
   assert ADDR_BITS_G > 16
      report "Defined adress space ADDR_BITS_G can accomodate only " & integer'image((2**ADDR_BITS_G)/4096) & " AXI burst(s) (4kB)"
      severity warning;
   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, axiWriteSlave, axilReadMaster, axilWriteMaster, reg, trig,
      adcData, hdrFifoFull, addrFifoFull, gTime, extTrigger, adcData, rdPtrValid, rdPtrDout) is
      variable vreg      : RegType;
      variable vtrig     : TrigType;
      variable regCon    : AxiLiteEndPointType;
      variable intTrig   : sl;
      variable extTrig   : sl;
      variable wrPtr     : slv(ADDR_BITS_G downto 0);
      variable rdPtr     : slv(ADDR_BITS_G downto 0);
   begin
      -- Latch the current value
      vreg := reg;
      vtrig := trig;
      
      -- keep reset for several clock cycles
      vtrig.reset := trig.reset(14 downto 0) & '0';
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vtrig.enable := reg.enable;
      -- update trigger related settings only in IDLE and disabled state
      if trig.trigState = IDLE_S then
         vtrig.intPreThresh   := reg.intPreThresh;
         vtrig.intPostThresh  := reg.intPostThresh;
         vtrig.intVetoThresh  := reg.intVetoThresh;
         vtrig.intPreDelay    := reg.intPreDelay;
         vtrig.intPostDelay   := reg.intPostDelay;
         vtrig.extTrigSize    := reg.extTrigSize;
         vtrig.intSaveVeto    := reg.intSaveVeto;
      end if;
      
      vreg.ackCount        := trig.ackCount;
      vreg.errCount        := trig.errCount;
      vreg.lostSamples     := trig.lostSamples;
      vreg.lostTriggers    := trig.lostTriggers;
      vreg.dropIntTrigs    := trig.dropIntTrigs;
      vtrig.rstCounters    := reg.rstCounters;
      
      vtrig.extTrigger(0)  := extTrigger;
      vtrig.extTrigger(1)  := trig.extTrigger(0);
      ------------------------------------------------
      -- register access
      ------------------------------------------------
      
      -- reset register strobes
      vreg.rstCounters := '0';
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      -- Map the registers
      axiSlaveRegister (regCon, x"000", 0, vreg.enable);
      axiSlaveRegister (regCon, x"004", 0, vreg.rstCounters);
      axiSlaveRegisterR(regCon, x"008", 0, reg.lostSamples);
      axiSlaveRegisterR(regCon, x"00C", 0, reg.lostTriggers);
      axiSlaveRegisterR(regCon, x"010", 0, reg.dropIntTrigs);
      axiSlaveRegisterR(regCon, x"014", 0, reg.ackCount);
      axiSlaveRegisterR(regCon, x"018", 0, reg.errCount);
      
      axiSlaveRegister (regCon, x"100", 0, vreg.intPreThresh);
      axiSlaveRegister (regCon, x"104", 0, vreg.intPostThresh);
      axiSlaveRegister (regCon, x"108", 0, vreg.intVetoThresh);
      axiSlaveRegister (regCon, x"10C", 0, vreg.intPreDelay);
      axiSlaveRegister (regCon, x"110", 0, vreg.intPostDelay);
      axiSlaveRegister (regCon, x"114", 0, vreg.intSaveVeto);
      axiSlaveRegister (regCon, x"200", 0, vreg.extTrigSize);
      -- override readback
      axiSlaveRegisterR(regCon, x"100", 0, vtrig.intPreThresh);
      axiSlaveRegisterR(regCon, x"104", 0, vtrig.intPostThresh);
      axiSlaveRegisterR(regCon, x"108", 0, vtrig.intVetoThresh);
      axiSlaveRegisterR(regCon, x"10C", 0, vtrig.intPreDelay);
      axiSlaveRegisterR(regCon, x"110", 0, vtrig.intPostDelay);
      axiSlaveRegisterR(regCon, x"200", 0, vtrig.extTrigSize);
      
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      
      ------------------------------------------------
      -- Combinational trigger variables
      ------------------------------------------------
      
      -- external trigger rising edge and size set to greater than 0
      if trig.extTrigger(0) = '1' and trig.extTrigger(1) = '0' and trig.extTrigSize > 0 then
         extTrig := '1';
      else
         extTrig := '0';
      end if;
      
      -- internal trigger pre threshold crossed
      -- ignore pre threshold set to 0
      if adcData >= trig.intPreThresh and trig.intPreThresh > 0 then
         intTrig := '1';
      else
         intTrig := '0';
      end if;
      
      ------------------------------------------------
      -- Memory usage tracking and writer stop logic
      ------------------------------------------------
      
      -- read pointer from the FIFO
      -- FIFO is being emptied by the reader
      rdPtr := rdPtrDout(31) & rdPtrDout(ADDR_BITS_G-1 downto 0);
      
      -- add margin offset to the write pointer
      -- 0.25 buffer size
      wrPtr := trig.wrAddress + 2**(ADDR_BITS_G-3);
      
      if rdPtrValid = '0' then
         vtrig.memFull := '0';
      else
         if rdPtr(ADDR_BITS_G) /= wrPtr(ADDR_BITS_G) and wrPtr(ADDR_BITS_G-1 downto 0) >= rdPtr(ADDR_BITS_G-1 downto 0) then
            vtrig.memFull := '1';
         else
            vtrig.memFull := '0';
         end if;
      end if;
      
      wrAddrSig   <= trig.wrAddress(ADDR_BITS_G-1 downto 0);   -- for simulation only
      wrAddrCSig  <= trig.wrAddress(ADDR_BITS_G);              -- for simulation only
      wrPtrSig    <= wrPtr(ADDR_BITS_G-1 downto 0);            -- for simulation only
      wrPtrCSig   <= wrPtr(ADDR_BITS_G);                       -- for simulation only
      rdPtrSig    <= rdPtr(ADDR_BITS_G-1 downto 0);            -- for simulation only
      rdPtrCSig   <= rdPtr(ADDR_BITS_G);                       -- for simulation only
      
      ------------------------------------------------
      -- Lost data counters
      ------------------------------------------------
      
      -- monitor AXI FIFOs 
      -- must be ready for the ADC data
      -- count lost ADC samples
      if trig.rstCounters = '1' then
         vtrig.lostSamples := (others=>'0');
      elsif trig.trigPending = '1' and trig.adcBufRdy = '0' then
         vtrig.lostSamples := trig.lostSamples + 1;
      end if;
      -- count lost triggers
      if trig.rstCounters = '1' then
         vtrig.lostTriggers := (others=>'0');
      elsif trig.trigState = WR_TRIG_S and (extTrig = '1' or intTrig = '1') then
         vtrig.lostTriggers := trig.lostTriggers + 1;
      end if;
      -- count dropped internal triggers
      if trig.rstCounters = '1' then
         vtrig.dropIntTrigs := (others=>'0');
      elsif trig.trigIntDrop = '1' then
         vtrig.dropIntTrigs := trig.dropIntTrigs + 1;
      end if;
      
      ------------------------------------------------
      -- AXI write buffer transactions
      ------------------------------------------------
      
      -- Reset strobing Signals
      if (axiWriteSlave.awready = '1') then
         vtrig.wMaster.awvalid := '0';
      end if;
      if (axiWriteSlave.wready = '1') then
         vtrig.wMaster.wvalid := '0';
         vtrig.wMaster.wlast  := '0';
      end if;

      -- Wait for memory bus response
      if (axiWriteSlave.bvalid = '1') then
         -- Increment the counter
         vtrig.ackCount := trig.ackCount + 1;
         -- Check for error response
         if (axiWriteSlave.bresp /= "00") then
            vtrig.errCount := trig.errCount + 1;
         end if;
      end if;
      
      ----------------------------------------------------------------------
      -- Buffer write state machine
      -- continiously write samples to the DDR memory in 4kB bursts
      -- when near full stop writing and srop trigger requests
      ----------------------------------------------------------------------
      
      case trig.buffState is
      
         when IDLE_S =>
            if trig.reset = 0 then
               vtrig.buffState := ADDR_S;
            end if;
         
         when ADDR_S =>
            vtrig.adcBufRdy := '0';
            
            -- Stop writing to memory when memFull but after trigger writing is finished
            if (trig.memFull = '0' or trig.trigPending = '1') then
               
               -- Check if ready to make memory request
               if (vtrig.wMaster.awvalid = '0') then
                  vtrig.adcBufRdy := '1';
                  -- Set the memory address
                  vtrig.wMaster.awaddr := resize((CHANNEL_G & trig.wrAddress(ADDR_BITS_G-1 downto 0)), vtrig.wMaster.awaddr'length);
                  -- Set the burst length
                  vtrig.wMaster.awlen := AWLEN_C;
                  -- Set the flag
                  vtrig.wMaster.awvalid := '1';
                  -- Next state
                  vtrig.buffState := MOVE_S;
                  -- count available samples
                  if trig.samplesBuff /= 2**trig.samplesBuff'length-1 then
                     vtrig.samplesBuff := trig.samplesBuff + 1;
                  end if;
               end if;
               
            else
               -- reset available samples counter when buffer is stopped
               vtrig.samplesBuff := (others=>'0');
            end if;
         
         when MOVE_S =>
            vtrig.adcBufRdy := '0';
            -- Check if ready to move data
            if (vtrig.wMaster.wvalid = '0') then
               vtrig.adcBufRdy := '1';
               -- Address increment by 2 bytes (16 bit samples)
               -- (ADDR_BITS_G-1 downto 0) will roll
               -- ADDR_BITS_G is the carry bit
               vtrig.wrAddress   := trig.wrAddress + 2;
               -- Register data bytes
               -- Move the data every 8 samples (128 bit AXI bus)
               if trig.wrAddress(3 downto 0) = "0000" then
                  vtrig.wMaster.wdata(15 downto 0) := adcData;
               elsif trig.wrAddress(3 downto 0) = "0010" then
                  vtrig.wMaster.wdata(31 downto 16) := adcData;
               elsif trig.wrAddress(3 downto 0) = "0100" then
                  vtrig.wMaster.wdata(47 downto 32) := adcData;
               elsif trig.wrAddress(3 downto 0) = "0110" then
                  vtrig.wMaster.wdata(63 downto 48) := adcData;
               elsif trig.wrAddress(3 downto 0) = "1000" then
                  vtrig.wMaster.wdata(79 downto 64) := adcData;
               elsif trig.wrAddress(3 downto 0) = "1010" then
                  vtrig.wMaster.wdata(95 downto 80) := adcData;
               elsif trig.wrAddress(3 downto 0) = "1100" then
                  vtrig.wMaster.wdata(111 downto 96) := adcData;
               else --"1110"
                  vtrig.wMaster.wdata(127 downto 112) := adcData; 
                  vtrig.wMaster.wvalid := '1';
               end if;
               
               vtrig.wMaster.wstrb(15 downto 0) := x"FFFF";
               
               -- Check for last AXI transfer (4kB burst)
               if trig.wrAddress(11 downto 0) = x"FFE" then
                  -- Set the flag
                  vtrig.wMaster.wlast := '1';
                  vtrig.buffState := ADDR_S;
               end if;
               
               -- count available samples
               if trig.samplesBuff /= 2**trig.samplesBuff'length-1 then
                  vtrig.samplesBuff := trig.samplesBuff + 1;
               end if;
            
            end if;
         
         when others =>
            vtrig.buffState := IDLE_S;
         
      end case;
      
      -- set the actual pre delay number depending on available samples
      if trig.samplesBuff >= trig.intPreDelay then
         vtrig.actPreDelay := trig.intPreDelay;
      else
         vtrig.actPreDelay := trig.samplesBuff;
      end if;
      
      -- track address of the buffer's beginning
      -- (ADDR_BITS_G-1 downto 0) will roll
      -- ADDR_BITS_G is the carry bit
      vtrig.preAddress := vtrig.wrAddress - resize((trig.actPreDelay & '0'), ADDR_BITS_G-1);
      
      ----------------------------------------------------------------------
      -- Trigger state machine
      -- find trigger condition
      -- register the trigger information
      ----------------------------------------------------------------------
      
      -- handshake between two state machines
      vtrig.hdrWrite := '0';
      
      -- clear address FIFO write strobe
      vtrig.addrFifoWr := '0';
      
      case trig.trigState is
         
         when IDLE_S =>
            -- clear trigger flags
            vtrig.trigType := (others=>'0');
            vtrig.postCnt  := (others=>'0');
            vtrig.trigPending := '0';
            vtrig.trigIntDrop := '0';
            -- only disable trigger, never the buffer
            if (trig.reset = 0 and trig.enable = '1' and trig.buffState /= IDLE_S) then
               
               -- track the time and sample address for all trigger sources
               vtrig.gTime       := gTime;
               vtrig.addrFifoDin := trig.preAddress(ADDR_BITS_G) & resize((CHANNEL_G & trig.preAddress(ADDR_BITS_G-1 downto 0)), 31);
               -- both sources share the preDelay setting
               vtrig.trigOffset := resize(trig.actPreDelay, 32);
               vtrig.trigLength := resize(trig.actPreDelay, 22);
               
               -- external trigger rising edge and size set to greater than 0
               if extTrig = '1' then
                  vtrig.trigType(EXT_IND_C)  := '1';
                  -- write memory address to the FIFO
                  vtrig.addrFifoWr  := '1';
               -- internal trigger pre threshold crossed (ignore pre threshold set to 0)
               elsif intTrig = '1' then
                  vtrig.trigType(INT_IND_C)  := '1';
               end if;
               
               -- change state if any trigger type occured
               if extTrig = '1' or intTrig = '1' then
                  -- create empty trigger if not enough memory space
                  if trig.memFull = '1' then
                     vtrig.trigType(EMPTY_IND_C) := '1';
                     vtrig.trigOffset := (others=>'0');
                     vtrig.trigLength := (others=>'0');
                     vtrig.addrFifoWr := '0';
                     vtrig.trigState  := WR_TRIG_S;
                  else
                     vtrig.trigPending := '1';
                     vtrig.trigState := TRIG_ARM_S;
                  end if;
               end if;
               
            end if;
            
         
         
         when TRIG_ARM_S =>
            
            -- count samples written to the FIFO
            -- look for missing ADC samples
            if trig.adcBufRdy = '1' then
               vtrig.trigLength := trig.trigLength + 1;
            else
               vtrig.trigType(BAD_IND_C) := '1';
            end if;
            
            -- distinguish internal or external trigger
            -- wait for all data to be in the AXI FIFO
            if trig.trigType(INT_IND_C) = '1' then
               
               -- post threshold detected
               if adcData <= trig.intPostThresh then
                  -- write memory address to the FIFO
                  vtrig.addrFifoWr  := '1';
                  -- wait for post data
                  vtrig.trigState   := INT_POST_S;
               -- veto threshold detected
               elsif adcData >= trig.intVetoThresh then
                  vtrig.trigType(VETO_IND_C) := '1';
                  vtrig.trigLength := (others=>'0');
                  vtrig.trigOffset := (others=>'0');
                  if trig.intSaveVeto = '1' then
                     vtrig.trigState := WR_TRIG_S;
                  else
                     vtrig.trigPending := '0';
                     vtrig.trigState := IDLE_S;
                  end if;
               -- no veto and no post threshold until maximum buffer is reached
               -- drop the trigger and count
               elsif (trig.trigLength + trig.intPostDelay) = 2**trig.trigLength'length-1 then
                  vtrig.trigLength  := (others=>'0');
                  vtrig.trigOffset  := (others=>'0');
                  vtrig.trigIntDrop := '1';
                  vtrig.trigPending := '0';
                  vtrig.trigState   := IDLE_S;
               end if;
            
            else
               -- wait for external trigger to be in the AXI FIFO
               if trig.trigLength >= trig.extTrigSize then
                  vtrig.trigState   := WR_TRIG_S;
               end if;
               
            end if;
         
         -- wait for internal trigger post data
         when INT_POST_S =>
            -- count post samples written to the FIFO
            if trig.adcBufRdy = '1' then
               if trig.postCnt < trig.intPostDelay and trig.trigLength < 2**trig.trigLength'length-1 then
                  vtrig.trigLength := trig.trigLength + 1;
                  vtrig.postCnt := trig.postCnt + 1;
               else
                  vtrig.postCnt := (others=>'0');
                  -- start writing header information FIFO
                  vtrig.trigState   := WR_TRIG_S;
               end if;
            else
               vtrig.trigType(BAD_IND_C) := '1';
            end if;
         
         -- wait until previous header information is 
         -- stored by the header FSM
         -- lostTriggers will count if new triggers occur while
         -- waiting in this state
         when WR_TRIG_S =>
            if trig.hdrState = IDLE_S then
               -- register header information
               vtrig.hdrData(0) := trig.trigType & "00000" & trig.trigLength;
               vtrig.hdrData(1) := trig.trigOffset;
               vtrig.hdrData(2) := trig.gTime(63 downto 32);
               vtrig.hdrData(3) := trig.gTime(31 downto 0);
               -- wake up the header FSM
               vtrig.hdrWrite := '1';
               -- accept new triggers
               vtrig.trigState := IDLE_S;
               vtrig.trigPending := '0';
            end if;
         
         when others =>
            vtrig.trigState := IDLE_S;
         
      end case;
      
      ----------------------------------------------------------------------
      -- Header state machine
      -- read trigger size from address FIFO
      -- wait until the whole trigger is in the DDR memory
      -- store header information and let know the reader when the trigger is ready
      ----------------------------------------------------------------------
      
      -- keep track of how many bursts is currently in AXI FIFO
      if trig.wMaster.awvalid = '1' and axiWriteSlave.awready = '1' then 
         vtrig.burstsInFifo := trig.burstsInFifo + 1;
      end if;
      -- decrease the counter as data is written into the DDR
      if axiWriteSlave.bvalid = '1' and trig.burstsInFifo /= 0 then
         vtrig.burstsInFifo := trig.burstsInFifo - 1;
      end if;
      
      
      case trig.hdrState is
         
         -- wait for trigger state machine
         when IDLE_S =>
            vtrig.hdrFifoCnt := 0;
            vtrig.hdrFifoWr := '0';
            if (trig.hdrWrite = '1') then
               
               --if trig.trigType(EMPTY_IND_C) = '1' or trig.trigType(VETO_IND_C) = '1' then   -- should be from hdrData copy !
               if trig.hdrData(0)(EMPTY_IND_C+27) = '1' or trig.hdrData(0)(VETO_IND_C+27) = '1' then
                  vtrig.hdrState    := WR_HDR_S;
               else
                  vtrig.bvalidCnt   := trig.burstsInFifo;
                  vtrig.hdrState    := WAIT_TRIG_INMEM_S;
               end if;
               
            end if;
         
         -- make sure that all trigger bursts are in the memory
         when WAIT_TRIG_INMEM_S =>
            if axiWriteSlave.bvalid = '1' then
               if trig.bvalidCnt = 0 then
                  vtrig.hdrState := WR_HDR_S;
               else
                  vtrig.bvalidCnt := trig.bvalidCnt - 1;
               end if;
            end if;
         
         -- write header information to the FIFO
         when WR_HDR_S =>
            if hdrFifoFull = '0' then
               vtrig.hdrFifoCnt  := trig.hdrFifoCnt + 1;
               vtrig.hdrFifoWr   := '1';
               vtrig.hdrFifoDin  := trig.hdrData(trig.hdrFifoCnt);
               
               if trig.hdrFifoCnt >= (HDR_SIZE_C-1) then
                  vtrig.hdrState   := IDLE_S;
               end if;
            else
               vtrig.hdrFifoWr := '0';
            end if;
         
         when others =>
            vtrig.hdrState := IDLE_S;
         
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
      axiWriteMaster <= trig.wMaster;
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      
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
   -- Header information FIFO
   ----------------------------------------------------------------------
   
   U_HdrFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => 32,
      ADDR_WIDTH_G      => HDR_ADDR_WIDTH_C,
      FWFT_EN_G         => true,
      GEN_SYNC_FIFO_G   => true
   )
   port map ( 
      rst               => trig.reset(0),
      wr_clk            => adcClk,
      wr_en             => trig.hdrFifoWr,
      din               => trig.hdrFifoDin,
      full              => hdrFifoFull,
      rd_clk            => adcClk,
      rd_en             => hdrRd,
      dout              => hdrDout,
      valid             => hdrValid
   );
   
   ----------------------------------------------------------------------
   -- Address information FIFO
   ----------------------------------------------------------------------
   
   U_AdrFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => 32,
      ADDR_WIDTH_G      => HDR_ADDR_WIDTH_C,
      FWFT_EN_G         => true,
      GEN_SYNC_FIFO_G   => true
   )
   port map ( 
      rst               => trig.reset(0),
      wr_clk            => adcClk,
      wr_en             => trig.addrFifoWr,
      din               => trig.addrFifoDin,
      full              => addrFifoFull,
      rd_clk            => adcClk,
      rd_en             => addrRd,
      dout              => rdPtrDout,
      valid             => rdPtrValid
   );
   
   addrDout    <= rdPtrDout;
   addrValid   <= rdPtrValid;

end rtl;
