-------------------------------------------------------------------------------
-- File       : SadcBufferWriter.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-07
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
use work.AxiPkg.all;

entity SadcBufferWriter is
   generic (
      TPD_G             : time                     := 1 ns;
      ADDR_BITS_G       : integer range 12 to 31   := 14;
      ADDR_OFFSET_G     : slv(31 downto 0)         := x"00000000";
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
   
   -- this constant is to keep ADC FIFO partially full
   -- it is to allow propagating trigger information to the Trig FIFO output before reading out 
   -- the ADC sample @ trigger time
   constant FIFO_LATENCY_C    : integer := 8;
   
   constant HDR_SIZE_C        : integer := 4;
   constant HDR_ADDR_WIDTH_C  : integer := 9;

   type BuffStateType is (
      IDLE_S,
      ADDR_S,
      MOVE_S
   );
   
   type TrigStateType is (
      IDLE_S,
      INT_TRIG_WAIT_S,
      WR_TRIG_S
   );
   
   type AddrStateType is (
      IDLE_S,
      WR_ADDR_S
   );
   
   type HdrStateType is (
      IDLE_S,
      WAIT_TRIG_INFIFO_S,
      WAIT_TRIG_INMEM_S,
      WAIT_HDR_S,
      WR_HDR_S
   );
   
   type TrigType is record
      reset          : slv(15 downto 0);
      extTrigger     : slv(1 downto 0);
      gTime          : slv(63 downto 0);
      wrAddress      : slv(ADDR_BITS_G downto 0);  -- address and carry flag
      preAddress     : slv(ADDR_BITS_G downto 0);  -- address and carry flag
      smplWrCnt      : slv(31 downto 0);
      smplRdCnt      : slv(31 downto 0);
      trigLenCnt     : slv(31 downto 0);
      trigLenRst     : sl;
      enable         : sl;
      intPreThresh   : slv(15 downto 0);
      intPostThresh  : slv(15 downto 0);
      intVetoThresh  : slv(15 downto 0);
      intPreDelay    : slv(15 downto 0);
      intPostDelay   : slv(15 downto 0);
      intLength      : slv(21 downto 0);  -- 22 bits * 4ns ~= 16ms max window
      extTrigSize    : slv(21 downto 0);  -- 22 bits * 4ns ~= 16ms max window
      trigAddr       : slv(31 downto 0);
      trigOffset     : slv(31 downto 0);
      trigSize       : slv(31 downto 0);
      trigState      : TrigStateType;
      addrState      : AddrStateType;
      buffState      : BuffStateType;
      hdrState       : HdrStateType;
      wMaster        : AxiWriteMasterType;
      ackCount       : slv(31 downto 0);
      errCount       : slv(31 downto 0);
      overflow       : slv(31 downto 0);
      adcFifoRd      : sl;
      adcFifoWr      : sl;
      trigFifoCnt    : integer;
      trigFifoDin    : slv(31 downto 0);
      trigFifoRd     : sl;
      trigFifoWr     : sl;
      hdrFifoCnt     : integer;
      hdrFifoDin     : slv(31 downto 0);
      hdrFifoWr      : sl;
      addrFifoDin    : slv(31 downto 0);
      addrFifoWr     : sl;
      addrFifoRd     : sl;
      addrFifoCnt    : integer;
   end record TrigType;

   constant TRIG_INIT_C : TrigType := (
      reset          => x"0001",
      extTrigger     => (others => '0'),
      gTime          => (others => '0'),
      wrAddress      => (others => '0'),
      preAddress     => (others => '0'),
      smplWrCnt      => (others => '0'),
      smplRdCnt      => (others => '0'),
      trigLenCnt     => (others => '0'),
      trigLenRst     => '0',
      enable         => '0',
      intPreThresh   => (others => '0'),
      intPostThresh  => (others => '0'),
      intVetoThresh  => (others => '0'),
      intPreDelay    => (others => '0'),
      intPostDelay   => (others => '0'),
      intLength      => (others => '0'),
      extTrigSize    => (others => '0'),
      trigAddr       => (others => '0'),
      trigOffset     => (others => '0'),
      trigSize       => (others => '0'),
      trigState      => IDLE_S,
      addrState      => IDLE_S,
      buffState      => IDLE_S,
      hdrState       => IDLE_S,
      wMaster        => axiWriteMasterInit(AXI_CONFIG_C, '1', AXI_BURST_C, AXI_CACHE_C),
      ackCount       => (others => '0'),
      errCount       => (others => '0'),
      overflow       => (others => '0'),
      adcFifoRd      => '0',
      adcFifoWr      => '0',
      trigFifoCnt    => 0,
      trigFifoDin    => (others => '0'),
      trigFifoRd     => '0',
      trigFifoWr     => '0',
      hdrFifoCnt     => 0,
      hdrFifoDin     => (others => '0'),
      hdrFifoWr      => '0',
      addrFifoDin    => (others => '0'),
      addrFifoWr     => '0',
      addrFifoRd     => '0',
      addrFifoCnt    => 0
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
      overflow       : slv(31 downto 0);
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
      errCount       => (others => '0'),
      overflow       => (others => '0')
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal adcFifoDout   : slv(15 downto 0);
   signal adcFifoRdCnt  : slv(9 downto 0);
   signal trigFifoDout  : slv(31 downto 0);
   signal adcFifoValid  : sl;
   signal adcFifoFull   : sl;
   signal hdrFifoFull   : sl;
   signal trigFifoFull  : sl;
   signal trigFifoValid : sl;
   signal addrFifoFull  : sl;
   signal addrFifoDout  : slv(31 downto 0);
   signal addrFifoValid : sl;
   
   signal axiDataWr  : slv(127 downto 0);    -- ONLY FOR SIMULATION
   
begin

   axiDataWr  <= trig.wMaster.wdata(127 downto 0);    -- ONLY FOR SIMULATION
   
   -- configuration asserts   
   assert ADDR_OFFSET_G(31) = '0'
      report "ADDR_OFFSET_G(31) must be '0'"
      severity failure;
   
   assert ADDR_OFFSET_G(ADDR_BITS_G-1 downto 0) = 0
      report "ADDR_OFFSET_G must be aligned to the adddress space defined by ADDR_BITS_G"
      severity failure;
   
   assert ADDR_BITS_G > 16
      report "Defined adress space ADDR_BITS_G can accomodate only " & integer'image((2**ADDR_BITS_G)/4096) & " AXI burst(s) (4kB)"
      severity warning;
   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, axiWriteSlave, axilReadMaster, axilWriteMaster, reg, trig,
      adcFifoDout, adcFifoValid, adcFifoRdCnt, trigFifoDout, adcFifoFull, hdrFifoFull, trigFifoFull, trigFifoValid,
      gTime, extTrigger, memFull, adcData, addrFifoFull, addrFifoDout, addrFifoValid) is
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
      vtrig.enable := reg.enable;
      -- update trigger related settings only in IDLE and disabled state
      if trig.trigState = IDLE_S and trigFifoValid = '0' then
         vtrig.intPreThresh   := reg.intPreThresh;
         vtrig.intPostThresh  := reg.intPostThresh;
         vtrig.intVetoThresh  := reg.intVetoThresh;
         vtrig.intPreDelay    := reg.intPreDelay;
         vtrig.intPostDelay   := reg.intPostDelay;
         vtrig.extTrigSize    := reg.extTrigSize;
      end if;
      
      vreg.overflow        := trig.overflow;
      vreg.ackCount        := trig.ackCount;
      vreg.errCount        := trig.errCount;
      
      vtrig.extTrigger(0)  := extTrigger;
      vtrig.extTrigger(1)  := trig.extTrigger(0);
      ------------------------------------------------
      -- register access
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      -- Map the registers
      axiSlaveRegister (regCon, x"000", 0, vreg.enable);
      axiSlaveRegisterR(regCon, x"004", 0, reg.overflow);
      axiSlaveRegisterR(regCon, x"008", 0, reg.ackCount);
      axiSlaveRegisterR(regCon, x"00C", 0, reg.errCount);
      
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
      -- check for buffer overflows
      ------------------------------------------------
      if adcFifoFull = '1' and trig.reset = 0 then
         vtrig.overflow(0) := '1';
      end if;
      
      if hdrFifoFull = '1' and trig.reset = 0 then
         vtrig.overflow(1) := '1';
      end if;
      
      if trigFifoFull = '1' and trig.reset = 0 then
         vtrig.overflow(2) := '1';
      end if;
      
      if addrFifoFull = '1' and trig.reset = 0 then
         vtrig.overflow(3) := '1';
      end if;
      
      if memFull = '1' then
         vtrig.overflow(4) := '1';
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
      ----------------------------------------------------------------------
      
      case trig.buffState is
      
         when IDLE_S =>
            if trig.reset = 0 then
               vtrig.buffState := ADDR_S;
            end if;
         
         when ADDR_S =>
            -- don't read ADC data
            vtrig.adcFifoRd := '0';
            -- Check if ready to make memory request
            if (vtrig.wMaster.awvalid = '0' and memFull = '0') then
               -- Set the memory address
               vtrig.wMaster.awaddr := resize(ADDR_OFFSET_G, vtrig.wMaster.awaddr'length)  + trig.wrAddress(ADDR_BITS_G-1 downto 0);
               -- Set the burst length
               vtrig.wMaster.awlen := AWLEN_C;
               -- Set the flag
               vtrig.wMaster.awvalid := '1';
               -- Next state
               vtrig.buffState := MOVE_S;
            end if;
         
         when MOVE_S =>
            -- Check if ready to move data
            if (vtrig.wMaster.wvalid = '0' and adcFifoValid = '1' and adcFifoRdCnt >= FIFO_LATENCY_C and memFull = '0') then
            
               -- Read ADC FIFO
               vtrig.adcFifoRd := '1';
               -- Address increment by 2 bytes (16 bit samples)
               -- (ADDR_BITS_G-1 downto 0) will roll
               -- ADDR_BITS_G is the carry bit
               vtrig.wrAddress   := trig.wrAddress + 2;
               -- Register data bytes
               -- Move the data every 8 samples (128 bit AXI bus)
               if trig.wrAddress(3 downto 0) = "0000" then
                  vtrig.wMaster.wdata(15 downto 0) := adcFifoDout;
               elsif trig.wrAddress(3 downto 0) = "0010" then
                  vtrig.wMaster.wdata(31 downto 16) := adcFifoDout;
               elsif trig.wrAddress(3 downto 0) = "0100" then
                  vtrig.wMaster.wdata(47 downto 32) := adcFifoDout;
               elsif trig.wrAddress(3 downto 0) = "0110" then
                  vtrig.wMaster.wdata(63 downto 48) := adcFifoDout;
               elsif trig.wrAddress(3 downto 0) = "1000" then
                  vtrig.wMaster.wdata(79 downto 64) := adcFifoDout;
               elsif trig.wrAddress(3 downto 0) = "1010" then
                  vtrig.wMaster.wdata(95 downto 80) := adcFifoDout;
               elsif trig.wrAddress(3 downto 0) = "1100" then
                  vtrig.wMaster.wdata(111 downto 96) := adcFifoDout;
               else --"1110"
                  vtrig.wMaster.wdata(127 downto 112) := adcFifoDout; 
                  vtrig.wMaster.wvalid := '1';
               end if;
               
               vtrig.wMaster.wstrb(15 downto 0) := x"FFFF";
               
               -- Check for last AXI transfer (4kB burst)
               if trig.wrAddress(11 downto 0) = x"FFE" then
                  -- Set the flag
                  vtrig.wMaster.wlast := '1';
                  vtrig.buffState := ADDR_S;
               end if;
            
            else
               vtrig.adcFifoRd := '0';
            end if;
         
         when others =>
            vtrig.buffState := IDLE_S;
         
      end case;
      
      -- track address of the buffer's beginning
      -- (ADDR_BITS_G-1 downto 0) will roll
      -- ADDR_BITS_G is the carry bit
      vtrig.preAddress := vtrig.wrAddress - resize((trig.intPreDelay & '0'), ADDR_BITS_G-1);
      
      ----------------------------------------------------------------------
      -- Trigger state machine
      -- find trigger condition
      -- store the sample number with global time in the trigger FIFO
      ----------------------------------------------------------------------
      
      -- enable ADC FIFO writing after the reset period
      if trig.reset = 0 then
         vtrig.adcFifoWr := '1';
      end if;
      -- count ADC samples written into the FIFO
      if trig.adcFifoWr = '1' then
         vtrig.smplWrCnt := trig.smplWrCnt + 1;
      end if;
      -- count ADC samples readback from the FIFO
      if trig.adcFifoRd = '1' then
         vtrig.smplRdCnt := trig.smplRdCnt + 1;
      end if;
      -- count ADC samples readback from the FIFO
      if trig.trigLenRst = '1' then
         vtrig.trigLenCnt := (others => '0');
      elsif trig.adcFifoRd = '1' then
         vtrig.trigLenCnt := trig.trigLenCnt + 1;
      end if;
      
      case trig.trigState is
         
         when IDLE_S =>
            -- only disable trigger, never the buffer
            if (trig.reset = 0 and trig.enable = '1') then
               
               -- external trigger rising edge
               if trig.extTrigger(0) = '1' and trig.extTrigger(1) = '0' and trig.extTrigSize > 0 then
                  vtrig.trigSize       := resize(trig.extTrigSize, 32);
                  vtrig.trigState   := WR_TRIG_S;
               -- internal trigger armed
               elsif adcData >= trig.intPreThresh and trig.intPreThresh > 0 then
                  vtrig.trigState      := INT_TRIG_WAIT_S;
               end if;
               
               -- track the time and sample number for all trigger sources
               vtrig.gTime          := gTime;
               vtrig.trigFifoDin    := trig.smplWrCnt;
               -- both sources share the preDelay setting
               -- check is there is enough samples for the preDelay
               if trig.intPreDelay <= trig.smplWrCnt then
                  vtrig.trigOffset := resize(trig.intPreDelay, 32);
               else
                  vtrig.trigOffset := trig.smplWrCnt(31 downto 0);
               end if;
               
            end if;
            vtrig.trigFifoCnt := 0;
            vtrig.trigFifoWr := '0';
            vtrig.intLength := (others=>'0');
         
         -- wait for post threshold or veto threshold
         when INT_TRIG_WAIT_S =>
            vtrig.intLength := trig.intLength + 1;
            if adcData <= trig.intPostThresh then
               vtrig.trigSize    := resize(trig.intLength, 32) + trig.intPostDelay;
               vtrig.trigState   := WR_TRIG_S;
            elsif adcData >= trig.intVetoThresh or trig.intLength = 2**trig.intLength'length-1 then
               vtrig.trigState   := IDLE_S;
            end if;
         
         when WR_TRIG_S =>
            if trigFifoFull = '0' then
               vtrig.trigFifoCnt := trig.trigFifoCnt + 1;
               vtrig.trigFifoWr := '1';
               if trig.trigFifoCnt = 0 then
                  vtrig.trigFifoDin := trig.trigFifoDin; -- smplWrCnt
               elsif trig.trigFifoCnt = 1 then
                  vtrig.trigFifoDin := trig.trigSize;
               elsif trig.trigFifoCnt = 2 then
                  vtrig.trigFifoDin := trig.trigOffset;
               elsif trig.trigFifoCnt = 3 then
                  vtrig.trigFifoDin := trig.gTime(63 downto 32);
               else
                  vtrig.trigFifoDin := trig.gTime(31 downto 0);
               end if;
               if trig.trigFifoCnt >= HDR_SIZE_C then
                  vtrig.trigState   := IDLE_S;
               end if;
            else
               vtrig.trigFifoWr := '0';
            end if;
         
         when others =>
            vtrig.trigState := IDLE_S;
         
      end case;
      
      ----------------------------------------------------------------------
      -- Address state machine
      -- wait for the sample being written to the DDR memory
      -- replace sample number with the DDR address corrected by the preDelay setting
      ----------------------------------------------------------------------
      
      case trig.addrState is
         
         when IDLE_S =>
            vtrig.addrFifoCnt := 0;
            vtrig.addrFifoWr := '0';
            vtrig.trigFifoRd := '0';
            if (trigFifoValid = '1' and trigFifoDout = trig.smplRdCnt) then
               
               -- store the sample address and carry flag (MSB)
               vtrig.addrFifoDin := trig.preAddress(ADDR_BITS_G) & (ADDR_OFFSET_G(30 downto 0) + trig.preAddress(ADDR_BITS_G-1 downto 0));
               -- read event size from the trig FIFO
               vtrig.trigFifoRd := '1';
               -- move to the next state
               vtrig.addrState   := WR_ADDR_S;
               
            end if;
         
         when WR_ADDR_S =>
            if addrFifoFull = '0' then
               vtrig.addrFifoCnt := trig.addrFifoCnt + 1;
               vtrig.addrFifoWr := '1';
               vtrig.trigFifoRd := '1';
               if trig.addrFifoCnt = 0 then
                  vtrig.addrFifoDin := trig.addrFifoDin;
               else
                  vtrig.addrFifoDin := trigFifoDout;
               end if;
               if trig.addrFifoCnt >= HDR_SIZE_C then
                  vtrig.trigFifoRd := '0';
                  vtrig.addrState   := IDLE_S;
               end if;
            else
               vtrig.addrFifoWr := '0';
               vtrig.trigFifoRd := '0';
            end if;
         
         when others =>
            vtrig.addrState := IDLE_S;
         
      end case;
      
      ----------------------------------------------------------------------
      -- Header state machine
      -- read trigger size from address FIFO
      -- wait until the whole trigger is in the DDR memory
      -- store header information and let know the reader when the trigger is ready
      ----------------------------------------------------------------------
      
      case trig.hdrState is
         
         when IDLE_S =>
            vtrig.hdrFifoCnt := 0;
            vtrig.hdrFifoWr := '0';
            vtrig.addrFifoRd := '0';
            vtrig.trigLenRst := '1';
            if (addrFifoValid = '1') then
               
               -- store the sample address and carry flag (MSB)
               vtrig.hdrFifoDin := addrFifoDout;
               -- read event size from the trig FIFO
               vtrig.addrFifoRd := '1';
               -- start event length counter
               vtrig.trigLenRst := '0';
               -- move to the next state
               vtrig.hdrState   := WAIT_TRIG_INFIFO_S;
               
            end if;
         
         when WAIT_TRIG_INFIFO_S =>
            vtrig.addrFifoRd := '0';
            if addrFifoDout <= trig.trigLenCnt then
               vtrig.trigLenRst := '1';
               vtrig.hdrState   := WAIT_TRIG_INMEM_S;
            end if;
         
         when WAIT_TRIG_INMEM_S =>
            if axiWriteSlave.bvalid = '1' then
               if hdrFifoFull = '0' then
                  -- copy all other information from the trig FIFO
                  vtrig.hdrState   := WR_HDR_S;
               else
                  -- wait for header FIFO
                  vtrig.hdrState   := WAIT_HDR_S;
               end if;
            end if;
         
         when WAIT_HDR_S =>
            if hdrFifoFull = '0' then
               -- copy all other information from the trig FIFO
               vtrig.hdrState   := WR_HDR_S;
            end if;
         
         when WR_HDR_S =>
            vtrig.hdrFifoCnt := trig.hdrFifoCnt + 1;
            vtrig.hdrFifoWr := '1';
            vtrig.addrFifoRd := '1';
            if trig.hdrFifoCnt = 0 then
               vtrig.hdrFifoDin := trig.hdrFifoDin;
            else
               vtrig.hdrFifoDin := addrFifoDout;
            end if;
            if trig.hdrFifoCnt >= HDR_SIZE_C then
               vtrig.addrFifoRd := '0';
               vtrig.hdrState   := IDLE_S;
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
      memWrAddr      <= trig.wrAddress(ADDR_BITS_G) & (ADDR_OFFSET_G(30 downto 0) + trig.wrAddress(ADDR_BITS_G-1 downto 0));
      
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
   -- ADC data FIFO
   ----------------------------------------------------------------------
   
   U_AdcFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => 16,
      ADDR_WIDTH_G      => 10,
      FWFT_EN_G         => true,
      GEN_SYNC_FIFO_G   => true
   )
   port map ( 
      rst               => trig.reset(0),
      wr_clk            => adcClk,
      wr_en             => trig.adcFifoWr,
      din               => adcData,
      full              => adcFifoFull,
      rd_clk            => adcClk,
      rd_en             => trig.adcFifoRd,
      rd_data_count     => adcFifoRdCnt,
      dout              => adcFifoDout,
      valid             => adcFifoValid
   );
   
   ----------------------------------------------------------------------
   -- Trigger information FIFO
   ----------------------------------------------------------------------
   
   U_TrigFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => 32,
      ADDR_WIDTH_G      => HDR_ADDR_WIDTH_C,
      FWFT_EN_G         => true,
      GEN_SYNC_FIFO_G   => true
   )
   port map ( 
      rst               => trig.reset(0),
      wr_clk            => adcClk,
      wr_en             => trig.trigFifoWr,
      din               => trig.trigFifoDin,
      full              => trigFifoFull,
      rd_clk            => adcClk,
      rd_en             => trig.trigFifoRd,
      dout              => trigFifoDout,
      valid             => trigFifoValid
   );
   
   ----------------------------------------------------------------------
   -- Address information FIFO
   ----------------------------------------------------------------------
   
   U_AddrFifo : entity work.Fifo 
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
      rd_en             => trig.addrFifoRd,
      dout              => addrFifoDout,
      valid             => addrFifoValid
   );
   
   ----------------------------------------------------------------------
   -- Header information FIFO
   ----------------------------------------------------------------------
   
   U_HdrFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => 32,
      ADDR_WIDTH_G      => HDR_ADDR_WIDTH_C,
      FWFT_EN_G         => true,
      GEN_SYNC_FIFO_G   => true,
      FULL_THRES_G      => 2**HDR_ADDR_WIDTH_C-HDR_SIZE_C-1
   )
   port map ( 
      rst               => trig.reset(0),
      wr_clk            => adcClk,
      wr_en             => trig.hdrFifoWr,
      din               => trig.hdrFifoDin,
      prog_full         => hdrFifoFull,
      rd_clk            => adcClk,
      rd_en             => hdrRd,
      dout              => hdrDout,
      valid             => hdrValid
   );

end rtl;
