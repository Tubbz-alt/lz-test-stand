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
      -- Buffer handshake to/from data reader (adcClk)
      memWrAddr         : out slv(31 downto 0);
      memFull           : in  sl := '0'
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
   
   constant EXT_C          : slv(2 downto 0) := "000";
   constant INT_C          : slv(2 downto 0) := "001";
   constant TRUNC_C        : slv(2 downto 0) := "010";
   constant EMPTY_C        : slv(2 downto 0) := "011";
   constant VETO_C         : slv(2 downto 0) := "111";
   constant EXT_BAD_C      : slv(2 downto 0) := "100";
   constant INT_BAD_C      : slv(2 downto 0) := "101";
   constant TRUNC_BAD_C    : slv(2 downto 0) := "110";

   constant EXT_IND_C      : integer := 0;
   constant INT_IND_C      : integer := 1;
   constant TRUNC_IND_C    : integer := 2;
   constant EMPTY_IND_C    : integer := 3;
   constant VETO_IND_C     : integer := 4;
   constant BAD_IND_C      : integer := 5;
   
   -- encode trigger type on 3 bits
   function triggerType (trigVectIn : slv) return slv is
      variable resultVar : slv(2 downto 0) := "000";
   begin
      
      -- check for external, internal and internal truncated types
      if trigVectIn(EXT_IND_C) = '1' then
         resultVar := EXT_C;
      elsif trigVectIn(INT_IND_C) = '1' then
         resultVar := INT_C;
      elsif trigVectIn(TRUNC_IND_C) = '1' then
         resultVar := TRUNC_C;
      end if;
      
      -- the above types can have missing ADC samples
      -- mark as bad (EXT_BAD_C, INT_BAD_C, TRUNC_BAD_C)
      if trigVectIn(BAD_IND_C) = '1' then
         resultVar(2) := '1';
      end if;
      
      -- if veto or empty bit is set overwrite all above
      if trigVectIn(EMPTY_IND_C) = '1' then
         resultVar := EMPTY_C;
      elsif trigVectIn(VETO_IND_C) = '1' then
         resultVar := VETO_C;
      end if;
      return resultVar;
   end;
   
   type TrigType is record
      reset          : slv(15 downto 0);
      extTrigger     : slv(1 downto 0);
      gTime          : slv(63 downto 0);
      wrAddress      : slv(ADDR_BITS_G downto 0);  -- address and carry flag
      preAddress     : slv(ADDR_BITS_G downto 0);  -- address and carry flag
      enable         : sl;
      intPreThresh   : slv(15 downto 0);
      intPostThresh  : slv(15 downto 0);
      intVetoThresh  : slv(15 downto 0);
      intPostDelay   : slv(15 downto 0);
      intPreDelay    : slv(15 downto 0);
      actPreDelay    : slv(15 downto 0);
      samplesBuff    : slv(15 downto 0);
      trigLength     : slv(21 downto 0);  -- 22 bits * 4ns ~= 16ms max window
      extTrigSize    : slv(21 downto 0);  -- 22 bits * 4ns ~= 16ms max window
      trigAddr       : slv(31 downto 0);
      trigOffset     : slv(31 downto 0);
      trigSize       : slv(31 downto 0);
      trigState      : TrigStateType;
      buffState      : BuffStateType;
      hdrState       : HdrStateType;
      wMaster        : AxiWriteMasterType;
      ackCount       : slv(31 downto 0);
      errCount       : slv(31 downto 0);
      trigAddress    : slv(31 downto 0);
      hdrFifoCnt     : integer;
      hdrFifoDin     : slv(31 downto 0);
      hdrFifoWr      : sl;
      burstsInFifo   : slv(7 downto 0);
   end record TrigType;

   constant TRIG_INIT_C : TrigType := (
      reset          => x"0001",
      extTrigger     => (others => '0'),
      gTime          => (others => '0'),
      wrAddress      => (others => '0'),
      preAddress     => (others => '0'),
      enable         => '0',
      intPreThresh   => (others => '0'),
      intPostThresh  => (others => '0'),
      intVetoThresh  => (others => '0'),
      intPostDelay   => (others => '0'),
      intPreDelay    => (others => '0'),
      actPreDelay    => (others => '0'),
      samplesBuff    => (others => '0'),
      trigLength     => (others => '0'),
      extTrigSize    => (others => '0'),
      trigAddr       => (others => '0'),
      trigOffset     => (others => '0'),
      trigSize       => (others => '0'),
      trigState      => IDLE_S,
      buffState      => IDLE_S,
      hdrState       => IDLE_S,
      wMaster        => axiWriteMasterInit(AXI_CONFIG_C, '1', AXI_BURST_C, AXI_CACHE_C),
      ackCount       => (others => '0'),
      errCount       => (others => '0'),
      trigAddress    => (others => '0'),
      hdrFifoCnt     => 0,
      hdrFifoDin     => (others => '0'),
      hdrFifoWr      => '0',
      burstsInFifo   => (others => '0')
   );
   
   type RegType is record
      enable         : sl;
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
   end record RegType;

   constant REG_INIT_C : RegType := (
      enable         => '0',
      intPreThresh   => (others => '0'),
      intPostThresh  => (others => '0'),
      intVetoThresh  => (others => '0'),
      intPreDelay    => (others => '0'),
      intPostDelay   => (others => '0'),
      extTrigSize    => (others => '0'),
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      ackCount       => (others => '0'),
      errCount       => (others => '0')
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal hdrFifoFull   : sl;
   signal hdrFifoValid  : sl;
   
   signal axiDataWr  : slv(127 downto 0);    -- ONLY FOR SIMULATION
   
begin

   axiDataWr  <= trig.wMaster.wdata(127 downto 0);    -- ONLY FOR SIMULATION
   
   assert ADDR_BITS_G > 16
      report "Defined adress space ADDR_BITS_G can accomodate only " & integer'image((2**ADDR_BITS_G)/4096) & " AXI burst(s) (4kB)"
      severity warning;
   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, axiWriteSlave, axilReadMaster, axilWriteMaster, reg, trig,
      adcData, hdrFifoFull, hdrFifoValid, gTime, extTrigger, memFull, adcData) is
      variable vreg      : RegType;
      variable vtrig     : TrigType;
      variable regCon    : AxiLiteEndPointType;
      variable intTrig   : sl;
      variable extTrig   : sl;
      variable adcBufRdy : sl;
      
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
      if trig.trigState = IDLE_S and hdrFifoValid = '0' then
         vtrig.intPreThresh   := reg.intPreThresh;
         vtrig.intPostThresh  := reg.intPostThresh;
         vtrig.intVetoThresh  := reg.intVetoThresh;
         vtrig.intPreDelay    := reg.intPreDelay;
         vtrig.intPostDelay   := reg.intPostDelay;
         vtrig.extTrigSize    := reg.extTrigSize;
      end if;
      
      vreg.ackCount        := trig.ackCount;
      vreg.errCount        := trig.errCount;
      vreg.lostSamples     := trig.lostSamples;
      vreg.lostTriggers    := trig.lostTriggers;
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
      axiSlaveRegisterR(regCon, x"010", 0, reg.ackCount);
      axiSlaveRegisterR(regCon, x"014", 0, reg.errCount);
      
      axiSlaveRegister (regCon, x"100", 0, vreg.intPreThresh);
      axiSlaveRegister (regCon, x"104", 0, vreg.intPostThresh);
      axiSlaveRegister (regCon, x"108", 0, vreg.intVetoThresh);
      axiSlaveRegister (regCon, x"10C", 0, vreg.intPreDelay);
      axiSlaveRegister (regCon, x"110", 0, vreg.intPostDelay);
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
      -- Lost data counters
      ------------------------------------------------
      
      -- monitor AXI FIFOs 
      -- must be ready for the ADC data
      adcBufRdy := axiWriteSlave.awready and axiWriteSlave.wready;
      -- count lost ADC samples
      if trig.buffState /= IDLE_S and adcBufRdy = '0' then
         vtrig.lostSamples := trig.lostSamples + 1;
      elsif trig.rstCounters = '1' then
         vtrig.lostSamples := (others=>'0');
      end if
      -- count lost triggers
      if trig.trigState = WR_TRIG_S and (extTrig = '1' or intTrig = '1') then
         vtrig.lostTriggers := trig.lostTriggers + 1;
      elsif trig.rstCounters = '1' then
         vtrig.lostTriggers := (others=>'0');
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
            if trig.reset = 0 and adcBufRdy = '1' then
               vtrig.buffState := ADDR_S;
            end if;
         
         when ADDR_S =>
            -- Check if ready to make memory request
            -- Stop writing to memory when memFull but after trigger writing is finished
            if (vtrig.wMaster.awvalid = '0') and (memFull = '0' or trig.trigState /= IDLE_S) then
               -- Set the memory address
               --vtrig.wMaster.awaddr := resize(ADDR_OFFSET_G, vtrig.wMaster.awaddr'length)  + trig.wrAddress(ADDR_BITS_G-1 downto 0);
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
            else
               -- reset available samples counter when buffer is stopped
               vtrig.samplesBuff := (others=>'0');
            end if;
         
         when MOVE_S =>
            -- Check if ready to move data
            if (vtrig.wMaster.wvalid = '0') then
            
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
               end if
            
            end if;
         
         when others =>
            vtrig.buffState := IDLE_S;
         
      end case;
      
      -- set the actual pre delay number depending on available samples
      if trig.samplesBuff >= trig.intPreDelay then
         trig.actPreDelay := trig.intPreDelay;
      else
         trig.actPreDelay := trig.samplesBuff;
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
      vtrig.writeHdr := '0';
      
      case trig.trigState is
         
         when IDLE_S =>
            -- clear trigger flags
            vtrig.trigType := (others=>'0');
            -- only disable trigger, never the buffer
            if (trig.reset = 0 and trig.enable = '1') then
               
               -- track the time and sample address for all trigger sources
               vtrig.gTime       := gTime;
               --vtrig.trigAddress := trig.preAddress(ADDR_BITS_G) & (ADDR_OFFSET_G(30 downto 0) + trig.preAddress(ADDR_BITS_G-1 downto 0));
               vtrig.trigAddress := trig.preAddress(ADDR_BITS_G) & "000" & resize(trig.wrAddress(ADDR_BITS_G-1 downto 0), 28);
               -- both sources share the preDelay setting
               vtrig.trigOffset  := resize(trig.actPreDelay, 32);
               
               -- external trigger rising edge and size set to greater than 0
               if extTrig = '1' then
                  vtrig.trigSize             := resize(trig.extTrigSize, 32);
                  vtrig.trigType(EXT_IND_C)  := '1';
               -- internal trigger pre threshold crossed
               -- ignore pre threshold set to 0
               elsif intTrig = '1' then
                  vtrig.trigType(INT_IND_C)  := '1';
               end if;
               
               -- change state if any trigger type occured
               if vtrig.trigType(EXT_IND_C) = '1' or vtrig.trigType(INT_IND_C) = '1' then
                  -- create empty trigger if not enough memory space
                  if memFull = '1' then
                     vtrig.trigType(EMPTY_IND_C) := '1';
                     vtrig.trigSize  := (others=>'0');
                     vtrig.trigState := WR_TRIG_S;
                  else
                     vtrig.trigState := TRIG_ARM_S;
                  end if;
               end if;
               
            end if;
            vtrig.trigLength := trig.actPreDelay;
         
         
         when TRIG_ARM_S =>
            
            -- count samples written to the FIFO
            -- look for missing ADC samples
            if adcBufRdy = '1' then
               vtrig.trigLength := trig.trigLength + 1;
            else
               vtrig.trigType(BAD_IND_C) := '1';
            end if;
            
            -- distinguish internal or external trigger
            -- wait for all data to be in the AXI FIFO
            if trig.trigType(INT_IND_C) = '1' then
               
               -- wait for post threshold or veto threshold or max trigger size
               if adcData <= trig.intPostThresh then
                  vtrig.trigLength  := (others=>'0');
                  vtrig.trigSize    := resize(trig.trigLength + trig.intPostDelay, 32);
                  vtrig.trigState   := INT_POST_S;
               elsif adcData >= trig.intVetoThresh then
                  vtrig.trigType(VETO_IND_C) := '1';
                  vtrig.trigSize             := (others=>'0');
                  if trig.intSaveVeto = '1' then
                     vtrig.trigState := WR_TRIG_S;
                  else
                     vtrig.trigState := IDLE_S;
                  end if;
               elsif (trig.trigLength + trig.intPostDelay) = 2**trig.trigLength'length-1 then
                  vtrig.trigType(TRUNC_IND_C) := '1';
                  vtrig.trigSize    := resize(trig.trigLength + trig.intPostDelay, 32);
                  vtrig.trigState   := WR_TRIG_S;
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
            if adcBufRdy = '1' then
               vtrig.trigLength := trig.trigLength + 1;
            else
               vtrig.trigType(BAD_IND_C) := '1';
            end if;
            if trig.trigLength >= trig.intPostDelay then
               vtrig.trigState   := WR_TRIG_S;
            end if;
         
         -- wait until previous header information is 
         -- stored by the header FSM
         -- lostTriggers will count if new triggers occur while
         -- waiting in this state
         when WR_TRIG_S =>
            if trig.hdrState = IDLE_S then
               -- register header information
               vtrig.hdrData(0)                 := trig.trigAddress;             -- preAddress
               vtrig.hdrData(0)(30 downto 28)   := triggerType(trig.trigType);   -- insert encoded trigger type bits
               vtrig.hdrData(1)                 := trig.trigSize;
               vtrig.hdrData(2)                 := trig.trigOffset;
               vtrig.hdrData(3)                 := trig.gTime(63 downto 32);
               vtrig.hdrData(4)                 := trig.gTime(31 downto 0);
               -- wake up the header FSM
               vtrig.writeHdr := '1';
               -- accept new triggers
               vtrig.trigState := IDLE_S;
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
            if (vtrig.writeHdr = '1') then
               
               if trig.trigType(EMPTY_IND_C) = '1' or trig.trigType(VETO_IND_C) = '1' then
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
               
               if trig.hdrFifoCnt >= HDR_SIZE_C then
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
      --memWrAddr      <= trig.wrAddress(ADDR_BITS_G) & (ADDR_OFFSET_G(30 downto 0) + trig.wrAddress(ADDR_BITS_G-1 downto 0));
      memWrAddr      <= trig.wrAddress(ADDR_BITS_G) & resize((CHANNEL_G & trig.wrAddress(ADDR_BITS_G-1 downto 0)), 31);
      
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
      valid             => hdrFifoValid
   );
   
   hdrValid <= hdrFifoValid;

end rtl;
