-------------------------------------------------------------------------------
-- File       : FadcBufferChannel.vhd
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
use work.SsiPkg.all;

entity FadcBufferChannel is
   generic (
      TPD_G             : time                  := 1 ns;
      AXI_ERROR_RESP_G  : slv(1 downto 0)       := AXI_RESP_DECERR_C;
      CHANNEL_G         : slv(7 downto 0)       := x"00";
      TRIG_ADDR_G       : integer range 8 to 32 := 8;
      BUFF_ADDR_G       : integer range 1 to 6  := 3;
      PGP_LANE_G        : slv(3 downto 0)       := "0000";
      PGP_VC_G          : slv(3 downto 0)       := "0001"
   );
   port (
      -- ADC Clock Domain
      adcClk            : in  sl;
      adcRst            : in  sl;
      adcData           : in  slv(63 downto 0);
      adcValid          : in  sl;
      gTime             : in  slv(63 downto 0);
      extTrigger        : in  sl := '0';
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AxiStream output (axisClk domain)
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisMaster        : out AxiStreamMasterType;
      axisSlave         : in  AxiStreamSlaveType
   );
end FadcBufferChannel;

architecture rtl of FadcBufferChannel is
   
   constant HDR_SIZE_C        : integer := 4;
   constant HDR_ADDR_WIDTH_C  : integer := 9;
   constant MAX_TRIG_C        : integer := (2**HDR_ADDR_WIDTH_C)/(HDR_SIZE_C*4) - 2;
   
   constant ADDR_LEN_C        : integer := TRIG_ADDR_G + BUFF_ADDR_G;
   constant MAX_BUF_C         : integer := (2**BUFF_ADDR_G)-1;
   constant DELAY_LEN_C       : integer := 7;
   
   constant EXT_IND_C      : integer := 0;
   constant INT_IND_C      : integer := 1;
   constant EMPTY_IND_C    : integer := 2;
   constant VETO_IND_C     : integer := 3;
   constant BAD_IND_C      : integer := 4;
   
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(2);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   type TrigStateType is (
      IDLE_S,
      TRIG_ARM_S,
      INT_POST_S,
      WR_TRIG_S
   );
   
   type DataStateType is (
      IDLE_S,
      HDR_S,
      DATA_S
   );
   
   type TrigType is record
      enable         : sl;
      reset          : slv(15 downto 0);
      extTrigger     : slv(1 downto 0);
      intPreThresh   : slv(16 downto 0);
      intPostThresh  : slv(16 downto 0);
      intVetoThresh  : slv(16 downto 0);
      intSaveVeto    : sl;
      intPostDelay   : slv(DELAY_LEN_C-1 downto 0);
      intPreDelay    : slv(DELAY_LEN_C-1 downto 0);
      actPreDelay    : slv(DELAY_LEN_C-1 downto 0);
      extTrigSize    : slv(TRIG_ADDR_G+1 downto 0);
      rstCounters    : sl;
      lostSamples    : slv(31 downto 0);
      lostTriggers   : slv(31 downto 0);
      lostTrigFlag   : sl;
      dropIntTrigs   : slv(31 downto 0);
      trigIntDrop    : sl;
      gTime          : slv(63 downto 0);
      txMaster       : AxiStreamMasterType;
      dataState      : DataStateType;
      trigState      : TrigStateType;
      buffSwitch     : sl;
      memWrEn        : sl;
      trigLength     : slv(TRIG_ADDR_G+1 downto 0);
      trigType       : slv(4 downto 0);
      trigOffset     : slv(31 downto 0);
      trigFifoWr     : sl;
      trigFifoDin    : slv(31 downto 0);
      trigRd         : sl;
      trigFifoCnt    : integer range 0 to HDR_SIZE_C-1;
      trigCnt        : integer range 0 to MAX_TRIG_C;
      trigAFull      : sl;
      trigWrLast     : sl;
      trigRdLast     : sl;
      trigDout       : slv(15 downto 0);
      addrFifoDin    : slv(ADDR_LEN_C+1 downto 0);
      addrFifoWr     : sl;
      addrRd         : sl;
      addrDout       : slv(ADDR_LEN_C+1 downto 0);
      sampleOffset   : slv(1 downto 0);
      postCnt        : slv(DELAY_LEN_C downto 0);
      trigPending    : sl;
      buffAddr       : slv(TRIG_ADDR_G+1 downto 0);  
      preAddress     : slv(TRIG_ADDR_G+1 downto 0);  
      samplesBuff    : slv(TRIG_ADDR_G+1 downto 0); 
      buffSel        : slv(BUFF_ADDR_G-1 downto 0); 
      buffCnt        : slv(BUFF_ADDR_G-1 downto 0); 
      trigSizeRd     : slv(TRIG_ADDR_G+1 downto 0);
      sampleOffsetRd : slv(1 downto 0);
      buffAddrRd     : slv(TRIG_ADDR_G-1 downto 0); 
      buffSelRd      : slv(BUFF_ADDR_G-1 downto 0); 
      hdrCnt         : integer range 0 to 11;
      reTrigger      : sl;
   end record TrigType;
   
   constant TRIG_INIT_C : TrigType := (
      enable         => '0',
      reset          => x"0001",
      extTrigger     => (others=>'0'),
      intPreThresh   => (others=>'0'),
      intPostThresh  => (others=>'0'),
      intVetoThresh  => (others=>'0'),
      intSaveVeto    => '0',
      intPostDelay   => (others=>'0'),
      intPreDelay    => (others=>'0'),
      actPreDelay    => (others=>'0'),
      extTrigSize    => (others=>'0'),
      rstCounters    => '0',
      lostSamples    => (others=>'0'),
      lostTriggers   => (others=>'0'),
      lostTrigFlag   => '0',
      dropIntTrigs   => (others=>'0'),
      trigIntDrop    => '0',
      gTime          => (others=>'0'),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      dataState      => IDLE_S,
      trigState      => IDLE_S,
      buffSwitch     => '0',
      memWrEn        => '0',
      trigLength     => (others=>'0'),
      trigType       => (others=>'0'),
      trigOffset     => (others=>'0'),
      trigFifoWr     => '0',
      trigFifoDin    => (others=>'0'),
      trigRd         => '0',
      trigFifoCnt    => 0,
      trigCnt        => 0,
      trigAFull      => '0',
      trigWrLast     => '0',
      trigRdLast     => '0',
      trigDout       => (others=>'0'),
      addrFifoDin    => (others=>'0'),
      addrFifoWr     => '0',
      addrRd         => '0',
      addrDout       => (others=>'0'),
      sampleOffset   => (others=>'0'),
      postCnt        => (others=>'0'),
      trigPending    => '0',
      buffAddr       => (others=>'0'), 
      preAddress     => (others=>'0'), 
      samplesBuff    => (others=>'0'),
      buffSel        => (others=>'0'),
      buffCnt        => (others=>'0'),
      trigSizeRd     => (others=>'0'),
      sampleOffsetRd => (others=>'0'),
      buffAddrRd     => (others=>'0'),
      buffSelRd      => (others=>'0'),
      hdrCnt         => 0,
      reTrigger      => '0'
   );
   
   
   type RegType is record
      enable         : sl;
      intSaveVeto    : sl;
      intPreThresh   : slv(15 downto 0);
      intPostThresh  : slv(15 downto 0);
      intVetoThresh  : slv(15 downto 0);
      intPreDelay    : slv(DELAY_LEN_C-1 downto 0);
      intPostDelay   : slv(DELAY_LEN_C-1 downto 0);
      extTrigSize    : slv(TRIG_ADDR_G+1 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
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
      lostSamples    => (others => '0'),
      lostTriggers   => (others => '0'),
      dropIntTrigs   => (others => '0'),
      rstCounters    => '0'
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal txSlave : AxiStreamSlaveType;
   
   signal memRdData  : slv(63 downto 0);
   
   signal preThr     : slv(3 downto 0);
   signal postThr    : slv(3 downto 0);
   signal vetoThr    : slv(3 downto 0);
   signal preThrZero : sl;
   
   signal trigFifoFull  : sl;
   signal trigValid     : sl;
   signal trigDout      : slv(31 downto 0);
   signal addrFifoFull  : sl;
   signal addrValid     : sl;
   signal addrDout      : slv(ADDR_LEN_C+1 downto 0);
   
   signal memRdAddr     : slv(ADDR_LEN_C-1 downto 0);
   signal memWrAddr     : slv(ADDR_LEN_C-1 downto 0);
   signal memWrEn       : sl;
   
   attribute keep : string;
   attribute keep of trig : signal is "true";
   
begin
   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, adcValid, axilReadMaster, axilWriteMaster, txSlave, reg, trig,
      gTime, extTrigger, preThr, postThr, vetoThr, preThrZero, memRdData, trigFifoFull, trigValid, trigDout,
      addrFifoFull, addrValid, addrDout) is
      variable vreg           : RegType;
      variable vtrig          : TrigType;
      variable intTrig        : sl;
      variable intTrigFast    : sl;
      variable postTrig       : sl;
      variable extTrig        : sl;
      variable sampleOffset   : slv(1 downto 0);
      variable postSamples    : slv(1 downto 0);
      variable trigSamples    : slv(2 downto 0);
      variable trigLengthNext : slv(TRIG_ADDR_G+2 downto 0);
      variable regCon         : AxiLiteEndPointType;
   begin
      -- Latch the current value
      vreg := reg;
      vtrig := trig;
      
      vtrig.addrDout := addrDout;
      
      -- keep reset for several clock cycles
      vtrig.reset := trig.reset(14 downto 0) & '0';
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vtrig.enable := reg.enable;
      -- update trigger related settings only in IDLE and disabled state
      if trig.trigState = IDLE_S then
         vtrig.intPreThresh   := '0' & reg.intPreThresh;
         vtrig.intPostThresh  := '0' & reg.intPostThresh;
         vtrig.intVetoThresh  := '0' & reg.intVetoThresh;
         vtrig.intPreDelay    := reg.intPreDelay;
         vtrig.intPostDelay   := reg.intPostDelay;
         vtrig.extTrigSize    := reg.extTrigSize;
         vtrig.intSaveVeto    := reg.intSaveVeto;
      end if;
      
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
      axiSlaveRegisterR(regCon, x"114", 0, vtrig.intSaveVeto);
      axiSlaveRegisterR(regCon, x"200", 0, vtrig.extTrigSize);
      
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      
      ------------------------------------------------
      -- Combinational trigger variables
      ------------------------------------------------      
      
      extTrig        := '0';
      intTrig        := '0';
      intTrigFast    := '0';
      postTrig       := '0';
      sampleOffset   := "00";
      postSamples    := "00";
      trigSamples    := "000";
      
      -- ignore zero threshold
      if preThrZero = '0' then
      
         -- internal trigger pre threshold crossed
         -- take into account veto threshold
         if preThr(0) = '1' and vetoThr(0) = '0' then
            intTrig := '1';
            sampleOffset := "00";
         elsif preThr(1) = '1' and vetoThr(1) = '0' then
            intTrig := '1';
            sampleOffset := "01";
         elsif preThr(2) = '1' and vetoThr(2) = '0' then
            intTrig := '1';
            sampleOffset := "10";
         elsif preThr(3) = '1' and vetoThr(3) = '0' then
            intTrig := '1';
            sampleOffset := "11";
         end if;
         
         -- clear the internal pre threshold if there was post and veto in the same clock cycle
         if preThr(0) = '1' and postThr(1) = '1' and vetoThr(1 downto 0) /= 0 then
            intTrig := '0';
         elsif preThr(0) = '1' and postThr(2) = '1' and vetoThr(2 downto 0) /= 0 then
            intTrig := '0';
         elsif preThr(0) = '1' and postThr(3) = '1' and vetoThr(3 downto 0) /= 0 then
            intTrig := '0';
         elsif preThr(1) = '1' and postThr(2) = '1' and vetoThr(2 downto 1) /= 0 then
            intTrig := '0';
         elsif preThr(1) = '1' and postThr(3) = '1' and vetoThr(3 downto 1) /= 0 then
            intTrig := '0';
         elsif preThr(2) = '1' and postThr(3) = '1' and vetoThr(3 downto 2) /= 0 then
            intTrig := '0';
         end if;
         
      end if;   
         
      -- post trigger only if no veto in preceeding samples
      if postThr(0) = '1' and vetoThr(0 downto 0) = 0 then
         postTrig    := '1';
         postSamples := "11";
         trigSamples := "001";
      elsif postThr(1) = '1' and vetoThr(1 downto 0) = 0 then
         postTrig    := '1';
         postSamples := "10";
         trigSamples := "010";
      elsif postThr(2) = '1' and vetoThr(2 downto 0) = 0 then
         postTrig    := '1';
         postSamples := "01";
         trigSamples := "011";
      elsif postThr(3) = '1' and vetoThr(3 downto 0) = 0 then
         postTrig    := '1';
         postSamples := "00";
         trigSamples := "100";
      end if;
      
      -- there can be post threshold crossing in the same clock cycle
      -- also take into account veto threshold
      -- intTrigFast has higher priority than intTrig
      if preThrZero = '0' then
         
         if preThr(0) = '1' and postThr(1) = '1' and vetoThr(1 downto 0) = 0 then
            intTrigFast    := '1';
            sampleOffset   := "00";
            postSamples    := "10";
         elsif preThr(0) = '1' and postThr(2) = '1' and vetoThr(2 downto 0) = 0 then
            intTrigFast    := '1';
            sampleOffset   := "00";
            postSamples    := "01";
         elsif preThr(0) = '1' and postThr(3) = '1' and vetoThr(3 downto 0) = 0 then
            intTrigFast    := '1';
            sampleOffset   := "00";
            postSamples    := "00";
         elsif preThr(1) = '1' and postThr(2) = '1' and vetoThr(2 downto 1) = 0 then
            intTrigFast    := '1';
            sampleOffset   := "01";
            postSamples    := "01";
         elsif preThr(1) = '1' and postThr(3) = '1' and vetoThr(3 downto 1) = 0 then
            intTrigFast    := '1';
            sampleOffset   := "01";
            postSamples    := "00";
         elsif preThr(2) = '1' and postThr(3) = '1' and vetoThr(3 downto 2) = 0 then
            intTrigFast    := '1';
            sampleOffset   := "10";
            postSamples    := "00";
         end if;
         
      end if;
      
      -- extTrig has the highest priority
      -- sample offset for extTrig is always 0
      if trig.extTrigger(0) = '1' and trig.extTrigger(1) = '0' and trig.extTrigSize > 0 then
         extTrig := '1';
         sampleOffset := "00";
         postSamples  := "11";
      end if;
      
      ----------------------------------------------------------------------
      -- Write address and buffer counter
      ----------------------------------------------------------------------
      if trig.buffCnt < MAX_BUF_C then
         if trig.buffSwitch = '1' then
            vtrig.buffAddr    := (others=>'0');
            vtrig.samplesBuff := (others=>'0');
            -- switch to next buffer
            vtrig.buffSel     := trig.buffSel + 1;
         else
            -- track current address (roll)
            vtrig.buffAddr    := trig.buffAddr + 4;
            -- count available samples (saturate)
            if trig.samplesBuff(TRIG_ADDR_G+1 downto 0) /= toSlv(2**(TRIG_ADDR_G+2)-4, TRIG_ADDR_G+2) then
               vtrig.samplesBuff := trig.samplesBuff + 4;
            end if;
         end if;
         
         trigLengthNext := resize(trig.trigLength, TRIG_ADDR_G+3) + 4;
         if trigLengthNext(TRIG_ADDR_G+2) = '0' or trig.trigPending = '0' then
            vtrig.memWrEn := '1';
         else
            vtrig.memWrEn := '0';
         end if;
         
      else
         vtrig.memWrEn := '0';
      end if;
      
      -- count available buffers
      if trig.buffSwitch = '1' and trig.addrRd = '1' then
         vtrig.buffCnt := trig.buffCnt;
      elsif trig.buffSwitch = '1' and trig.buffCnt < MAX_BUF_C then
         vtrig.buffCnt := trig.buffCnt + 1;
      elsif trig.addrRd = '1' and trig.buffCnt > 0 then
         vtrig.buffCnt := trig.buffCnt - 1;
      end if;
      
      
      -- set the actual pre delay number depending on available samples
      if trig.samplesBuff >= trig.intPreDelay then
         vtrig.actPreDelay := trig.intPreDelay;
      else
         vtrig.actPreDelay := trig.samplesBuff(DELAY_LEN_C-1 downto 0);
      end if;
      
      -- track address of the buffer's beginning
      -- include sample offset (2 bit address extension)
      vtrig.preAddress := (trig.buffAddr(TRIG_ADDR_G+1 downto 2) & sampleOffset) - resize(vtrig.actPreDelay, TRIG_ADDR_G+2);
      
      ----------------------------------------------------------------------
      -- Trigger state machine
      ----------------------------------------------------------------------
      
      -- count trigger in the FIFOs (trigger FIFO and header FIFO combined)
      if trig.trigWrLast = '1' and trig.trigRdLast = '1' then
         vtrig.trigCnt := trig.trigCnt;
      elsif trig.trigWrLast = '1' and trig.trigCnt < MAX_TRIG_C then
         vtrig.trigCnt := trig.trigCnt + 1;
      elsif trig.trigRdLast = '1' and trig.trigCnt > 0 then
         vtrig.trigCnt := trig.trigCnt - 1;
      end if;
      if trig.trigCnt >= MAX_TRIG_C then
         vtrig.trigAFull := '1';
      else
         vtrig.trigAFull := '0';
      end if;
      
      -- clear strobes
      vtrig.trigWrLast  := '0';
      vtrig.trigFifoWr  := '0';
      vtrig.trigIntDrop := '0';
      vtrig.buffSwitch  := '0';
      vtrig.addrFifoWr  := '0';
      
      case trig.trigState is
         
         when IDLE_S =>
            -- clear trigger flags
            vtrig.trigType := (others=>'0');
            vtrig.postCnt  := (others=>'0');
            vtrig.trigPending := '0';
            vtrig.reTrigger := '0';
            -- trigger disable
            if (trig.reset = 0 and trig.enable = '1') then
               
               -- track the time and sample address for all trigger sources
               vtrig.gTime          := gTime;
               vtrig.addrFifoDin    := vtrig.buffSel & vtrig.preAddress;
               -- both sources share the preDelay setting
               vtrig.trigOffset     := resize(vtrig.actPreDelay, 32);
               vtrig.sampleOffset   := sampleOffset;
               
               -- external trigger rising edge and size set to greater than 0
               if extTrig = '1' then
                  vtrig.trigType(EXT_IND_C)  := '1';
                  vtrig.gTime                := trig.gTime;
                  vtrig.trigLength           := resize(vtrig.actPreDelay, TRIG_ADDR_G+2) + postSamples;
                  vtrig.addrFifoWr           := '1';
                  vtrig.trigPending          := '1';
                  vtrig.trigState            := TRIG_ARM_S;
               -- internal trigger pre threshold and post threshold crossed in the same cycle
               elsif intTrigFast = '1' then
                  vtrig.trigType(INT_IND_C)  := '1';
                  vtrig.gTime                := trig.gTime;
                  vtrig.trigLength           := resize(vtrig.actPreDelay, TRIG_ADDR_G+2) + postSamples;
                  vtrig.addrFifoWr           := '1';
                  vtrig.trigPending          := '1';
                  -- wait for post data
                  vtrig.postCnt              := resize(postSamples, DELAY_LEN_C+1);
                  vtrig.trigState            := INT_POST_S;
               -- internal trigger pre threshold crossed
               elsif intTrig = '1' then
                  vtrig.trigType(INT_IND_C)  := '1';
                  vtrig.gTime                := trig.gTime;
                  vtrig.trigLength           := resize(vtrig.actPreDelay, TRIG_ADDR_G+2);
                  vtrig.trigPending          := '1';
                  vtrig.trigState            := TRIG_ARM_S;
               end if;
               
               -- create empty trigger if not enough buffers
               if trig.buffCnt >= MAX_BUF_C and (extTrig = '1' or intTrig = '1' or intTrigFast = '1') then
                  vtrig.trigType(EMPTY_IND_C) := '1';
                  vtrig.trigOffset            := (others=>'0');
                  vtrig.trigLength            := (others=>'0');
                  vtrig.sampleOffset          := "00";
                  vtrig.addrFifoWr            := '0';
                  vtrig.trigPending           := '0';
                  vtrig.trigState             := WR_TRIG_S;
               end if;
               
            end if;
         
         when TRIG_ARM_S =>
            
            -- count samples
            -- look for invalid ADC samples
            
            trigLengthNext := resize(trig.trigLength, TRIG_ADDR_G+3) + 4;
            
            if trigLengthNext(TRIG_ADDR_G+2) /= '1' then
               if adcValid = '1' then
                  vtrig.trigLength := trigLengthNext(TRIG_ADDR_G+1 downto 0);
               else
                  vtrig.trigType(BAD_IND_C) := '1';
               end if;
            end if;
            
            -- distinguish internal or external trigger
            -- wait for all data to be in the buffer
            if trig.trigType(INT_IND_C) = '1' then
               
               -- post threshold detected
               if postTrig = '1' then
                  -- write memory address to the FIFO
                  -- already written if reTrigger flag is set
                  if trig.reTrigger = '0' then
                     vtrig.addrFifoWr  := '1';
                  end if;
                  -- update trigger length depending on the post offset
                  -- trigSamples is less or equal to 4
                  vtrig.trigLength  := trig.trigLength + trigSamples;
                  vtrig.postCnt     := resize(postSamples, DELAY_LEN_C+1);
                  -- wait for post data
                  vtrig.trigState   := INT_POST_S;
               -- veto threshold detected
               elsif vetoThr /= 0 then
                  if trig.reTrigger = '0' then
                     vtrig.trigType(VETO_IND_C) := '1';
                     vtrig.trigLength     := (others=>'0');
                     vtrig.trigOffset     := (others=>'0');
                     vtrig.sampleOffset   := "00";
                     if trig.intSaveVeto = '1' then
                        vtrig.trigPending := '0';
                        vtrig.trigState   := WR_TRIG_S;
                     else
                        vtrig.trigPending := '0';
                        vtrig.trigState := IDLE_S;
                     end if;
                  else
                     vtrig.trigPending := '0';
                     vtrig.buffSwitch  := '1';
                     vtrig.trigState   := WR_TRIG_S;
                  end if;
               -- no veto and no post threshold until maximum buffer is reached
               -- drop the trigger and count
               -- keet the trigger if reTrigger flag is set
               elsif trig.trigLength >= 2**trig.trigLength'length-4 then
                  if trig.reTrigger = '0' then
                     vtrig.trigLength  := (others=>'0');
                     vtrig.trigOffset  := (others=>'0');
                     vtrig.trigIntDrop := '1';
                     vtrig.trigPending := '0';
                     vtrig.trigState   := IDLE_S;
                  else
                     vtrig.trigPending := '0';
                     vtrig.buffSwitch  := '1';
                     vtrig.trigState   := WR_TRIG_S;
                  end if;
               end if;
            
            else
               -- wait for external trigger to be in the buffer
               if trig.trigLength >= trig.extTrigSize or trig.trigLength >= 2**trig.trigLength'length-4 then
                  vtrig.trigLength   := trig.extTrigSize-1;
                  vtrig.trigPending  := '0';
                  vtrig.buffSwitch   := '1';
                  vtrig.trigState    := WR_TRIG_S;
               end if;
               
            end if;
         
         -- wait for internal trigger post data
         when INT_POST_S =>
               
            -- count post samples
            -- look for invalid ADC samples
            if adcValid = '1' then
               vtrig.postCnt := trig.postCnt + 4;
            else
               vtrig.trigType(BAD_IND_C) := '1';
            end if;
            
            -- look for re trigger condition in post
            if intTrigFast = '1' then
               
               trigLengthNext := resize(trig.trigLength, TRIG_ADDR_G+3) + vtrig.postCnt;
               
               if trigLengthNext(TRIG_ADDR_G+2) /= '1' then
                  vtrig.trigLength := trigLengthNext(TRIG_ADDR_G+1 downto 0);
               else
                  vtrig.trigLength := (others=>'1');
               end if;
               
               vtrig.postCnt     := resize(postSamples, DELAY_LEN_C+1);
               
            -- internal trigger pre threshold crossed
            elsif intTrig = '1' then
               
               trigLengthNext := resize(trig.trigLength, TRIG_ADDR_G+3) + vtrig.postCnt;
               
               if trigLengthNext(TRIG_ADDR_G+2) /= '1' then
                  vtrig.trigLength := trigLengthNext(TRIG_ADDR_G+1 downto 0);
                  vtrig.reTrigger   := '1';
                  vtrig.trigState   := TRIG_ARM_S;
               else
                  vtrig.trigLength := (others=>'1');
               end if;
               
            end if;
            
            -- postCnt ending has higher priority and re trigger will be lost (+1 cycle dead time)
            if trig.postCnt >= trig.intPostDelay or trig.trigLength >= 2**trig.trigLength'length-4 then
               
               trigLengthNext := resize(trig.trigLength, TRIG_ADDR_G+3) + trig.intPostDelay;
               
               if trigLengthNext(TRIG_ADDR_G+2) /= '1' then
                  vtrig.trigLength := trigLengthNext(TRIG_ADDR_G+1 downto 0);
               else
                  vtrig.trigLength    := (others=>'1');
               end if;
               
               -- start writing header information FIFO
               vtrig.trigPending := '0';
               vtrig.buffSwitch  := '1';
               vtrig.trigState   := WR_TRIG_S;
            end if;
         
         -- write trigger information into FIFO
         -- lostTriggers will count if new triggers occur while
         -- waiting in this state
         when WR_TRIG_S =>
            -- add one more sample if the length is odd
            -- this will avoid zero padding in 32 bit stream
            trigLengthNext := resize(trig.trigLength, TRIG_ADDR_G+3) + 1;
            if trig.trigLength(0) = '1' then
               if trigLengthNext(TRIG_ADDR_G+2) /= '1' then
                  vtrig.trigLength := trig.trigLength + 1;
               else
                  vtrig.trigLength := trig.trigLength - 1;
               end if;
            end if;
            -- check if there is space for one more trigger
            if trig.trigAFull = '0' then
               vtrig.trigFifoCnt  := trig.trigFifoCnt + 1;
               vtrig.trigFifoWr   := '1';
               if trig.trigFifoCnt = 0 then
                  vtrig.trigFifoDin(31 downto 27)            := trig.trigType;
                  vtrig.trigFifoDin(26 downto 25)            := (others=>'0');
                  vtrig.trigFifoDin(24 downto 23)            := trig.sampleOffset;
                  vtrig.trigFifoDin(22)                      := trig.lostTrigFlag;
                  vtrig.trigFifoDin(21 downto TRIG_ADDR_G+2) := (others=>'0');
                  vtrig.trigFifoDin(TRIG_ADDR_G+1 downto 0)  := vtrig.trigLength;
               elsif trig.trigFifoCnt = 1 then
                  vtrig.trigFifoDin := trig.trigOffset;
               elsif trig.trigFifoCnt = 2 then
                  vtrig.trigFifoDin := trig.gTime(31 downto 0);
               else
                  vtrig.trigFifoDin := trig.gTime(63 downto 32);
                  vtrig.trigFifoCnt := 0;
                  vtrig.trigState   := IDLE_S;
                  vtrig.trigWrLast  := '1';
               end if;
            end if;
         
         when others =>
            vtrig.trigState := IDLE_S;
         
      end case;
      
      ------------------------------------------------
      -- Lost data counters
      ------------------------------------------------
      
      -- count lost ADC samples
      if trig.rstCounters = '1' then
         vtrig.lostSamples := (others=>'0');
      elsif trig.trigPending = '1' and adcValid = '0' and trig.lostSamples /= x"ffffffff" then
         vtrig.lostSamples := trig.lostSamples + 1;
      end if;
      -- count lost triggers
      if trig.rstCounters = '1' then
         vtrig.lostTriggers := (others=>'0');
      elsif trig.trigState = WR_TRIG_S and (extTrig = '1' or intTrig = '1' or intTrigFast = '1') and trig.lostTriggers /= x"ffffffff" then
         vtrig.lostTriggers := trig.lostTriggers + 1;
      end if;
      -- lost triggers flag (auto cleared)
      if trig.trigState = WR_TRIG_S and (extTrig = '1' or intTrig = '1' or intTrigFast = '1') then
         vtrig.lostTrigFlag := '1';
      elsif trig.trigState /= WR_TRIG_S then
         vtrig.lostTrigFlag := '0';
      end if;
      -- count dropped internal triggers
      if trig.rstCounters = '1' then
         vtrig.dropIntTrigs := (others=>'0');
      elsif trig.trigIntDrop = '1' and trig.dropIntTrigs /= x"ffffffff" then
         vtrig.dropIntTrigs := trig.dropIntTrigs + 1;
      end if;
      
      ----------------------------------------------------------------------
      -- Data stream state machine
      ----------------------------------------------------------------------
      
      -- Reset strobing Signals
      if (txSlave.tReady = '1') then
         vtrig.txMaster.tValid := '0';
         vtrig.txMaster.tLast  := '0';
         vtrig.txMaster.tUser  := (others => '0');
         vtrig.txMaster.tKeep  := (others => '1');
         vtrig.txMaster.tStrb  := (others => '1');
      end if;
      
      vtrig.trigRd      := '0';
      vtrig.trigRdLast  := '0';
      vtrig.addrRd      := '0';
      
      case trig.dataState is
         
         when IDLE_S =>
            if trig.reset = 0 then
               if trigValid = '1' then
                  vtrig.trigSizeRd     := trigDout(TRIG_ADDR_G+1 downto 0);      -- store trigSize
                  vtrig.dataState      := HDR_S;
               end if;
               vtrig.hdrCnt := 0;
            end if;
         
         when HDR_S =>
            if vtrig.txMaster.tValid = '0' and (trigValid = '1' or trig.hdrCnt = 11) then
               vtrig.txMaster.tValid := '1';
               if trig.hdrCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, vtrig.txMaster, '1');
                  vtrig.txMaster.tData(15 downto 0) := x"00" & PGP_LANE_G & PGP_VC_G;           -- PGP lane and VC
               elsif trig.hdrCnt = 1 then
                  vtrig.txMaster.tData(15 downto 0) := x"0000";                                 -- reserved
               elsif trig.hdrCnt = 2 then
                  vtrig.txMaster.tData(15 downto 0) := x"00" & CHANNEL_G;                       -- Fast ADC channel number
               elsif trig.hdrCnt = 3 then
                  vtrig.txMaster.tData(15 downto 0) := x"0000";                                 -- reserved
               elsif trig.hdrCnt = 4 then
                  vtrig.trigDout                    := trigDout(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := trigDout(15 downto 0);                   -- trigSize
                  vtrig.trigRd                      := '1';
               elsif trig.hdrCnt = 5 then
                  vtrig.txMaster.tData(15 downto 0) := trig.trigDout;                           -- trigSize
               elsif trig.hdrCnt = 6 then
                  vtrig.trigDout                    := trigDout(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := trigDout(15 downto 0);                   -- trigOffset
                  vtrig.trigRd                      := '1';
               elsif trig.hdrCnt = 7 then
                  vtrig.txMaster.tData(15 downto 0) := trig.trigDout;                           -- trigOffset
               elsif trig.hdrCnt = 8 then
                  vtrig.trigDout                    := trigDout(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := trigDout(15 downto 0);                   -- gTime
                  vtrig.trigRd                      := '1';
               elsif trig.hdrCnt = 9 then
                  vtrig.txMaster.tData(15 downto 0) := trig.trigDout;                           -- gTime
               elsif trig.hdrCnt = 10 then
                  vtrig.trigDout                    := trigDout(31 downto 16);
                  vtrig.txMaster.tData(15 downto 0) := trigDout(15 downto 0);                   -- gTime
                  vtrig.trigRd                      := '1';
                  vtrig.trigRdLast                  := '1';
               else
                  vtrig.txMaster.tData(15 downto 0) := trig.trigDout;                           -- gTime
                  vtrig.hdrCnt      := 0;
                  -- check if the trigger has data
                  if trig.trigSizeRd > 0 and addrValid = '1' then
                     -- Move data
                     vtrig.dataState   := DATA_S;
                  else
                     vtrig.txMaster.tLast := '1';
                     vtrig.dataState   := IDLE_S;
                  end if;
               end if;
               vtrig.hdrCnt := trig.hdrCnt + 1;
            end if;
            -- Set the memory address
            vtrig.buffSelRd      := trig.addrDout(ADDR_LEN_C+1 downto TRIG_ADDR_G+2);
            vtrig.buffAddrRd     := trig.addrDout(TRIG_ADDR_G+1 downto 2);
            vtrig.sampleOffsetRd := trig.addrDout(1 downto 0);
         
         when DATA_S =>
            
            -- Check if ready to move data
            if vtrig.txMaster.tValid = '0' then
               
               vtrig.sampleOffsetRd := trig.sampleOffsetRd + 1;
               -- stream valid flag and data
               vtrig.txMaster.tValid := '1';
               if trig.sampleOffsetRd = 0 then
                  vtrig.txMaster.tData(15 downto 0) := memRdData(15 downto 0);
               elsif trig.sampleOffsetRd = 1 then
                  vtrig.txMaster.tData(15 downto 0) := memRdData(31 downto 16);
               elsif trig.sampleOffsetRd = 2 then
                  vtrig.txMaster.tData(15 downto 0) := memRdData(47 downto 32);
               else
                  vtrig.txMaster.tData(15 downto 0) := memRdData(63 downto 48);
                  -- move to next address once every 4 samples
                  vtrig.buffAddrRd                  := trig.buffAddrRd + 1;
               end if;
               
               -- unless all samples in trigger are read
               -- then move to idle state
               vtrig.trigSizeRd := trig.trigSizeRd - 1;
               if vtrig.trigSizeRd = 0 then
                  vtrig.txMaster.tLast := '1';
                  vtrig.addrRd         := '1';
                  vtrig.dataState      := IDLE_S;
               end if;
            
            end if;
         
         when others =>
            vtrig.dataState := IDLE_S;
         
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
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      
      memRdAddr      <= vtrig.buffSelRd & vtrig.buffAddrRd;
      memWrAddr      <= vtrig.buffSel & vtrig.buffAddr(TRIG_ADDR_G+1 downto 2);
      memWrEn        <= vtrig.memWrEn;
      
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
   -- Buffer DPRAM
   ----------------------------------------------------------------------
   
   U_DualPortRam: entity work.DualPortRam
   generic map (
      TPD_G          => TPD_G,
      DATA_WIDTH_G   => 64,
      ADDR_WIDTH_G   => ADDR_LEN_C
   )
   port map (
      -- Port A     
      clka    => adcClk,
      wea     => memWrEn,
      rsta    => trig.reset(0),
      addra   => memWrAddr,
      dina    => adcData,
      -- Port B
      clkb    => adcClk,
      rstb    => trig.reset(0),
      addrb   => memRdAddr,
      doutb   => memRdData
   );
   
   
   ----------------------------------------------------------------------
   -- Trigger information FIFO
   ----------------------------------------------------------------------
   
   U_TrigFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => 32,
      ADDR_WIDTH_G      => HDR_ADDR_WIDTH_C,
      FWFT_EN_G         => true,
      GEN_SYNC_FIFO_G   => true,
      FULL_THRES_G      => 2**HDR_ADDR_WIDTH_C-HDR_SIZE_C-8
   )
   port map ( 
      rst               => trig.reset(0),
      wr_clk            => adcClk,
      wr_en             => trig.trigFifoWr,
      din               => trig.trigFifoDin,
      full              => trigFifoFull,
      rd_clk            => adcClk,
      rd_en             => trig.trigRd,
      dout              => trigDout,
      valid             => trigValid
   );
   
   
   ----------------------------------------------------------------------
   -- Address information FIFO
   ----------------------------------------------------------------------
   
   U_AdrFifo : entity work.Fifo 
   generic map (
      DATA_WIDTH_G      => ADDR_LEN_C+2,
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
      rd_en             => trig.addrRd,
      dout              => addrDout,
      valid             => addrValid
   );
   
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
   
   ----------------------------------------------------------------------
   -- DSP comparators
   ----------------------------------------------------------------------
   
   GEN_VEC : for i in 3 downto 0 generate
      signal adcDataSig : Slv17Array(3 downto 0);
   begin
      
      adcDataSig(i) <= '0' & adcData(i*16+15 downto i*16);
      
      U_PreCmp : entity work.DspComparator
      generic map (
         WIDTH_G  => 17
      )
      port map (
         clk     => adcClk,
         rst     => adcRst,
         ain     => adcDataSig(i),
         bin     => trig.intPreThresh,
         gtEq    => preThr(i)
      );
      
      U_VetoCmp : entity work.DspComparator
      generic map (
         WIDTH_G  => 17
      )
      port map (
         clk     => adcClk,
         rst     => adcRst,
         ain     => adcDataSig(i),
         bin     => trig.intVetoThresh,
         gtEq    => vetoThr(i)
      );
      
      U_PostCmp : entity work.DspComparator
      generic map (
         WIDTH_G  => 17
      )
      port map (
         clk     => adcClk,
         rst     => adcRst,
         ain     => adcDataSig(i),
         bin     => trig.intPostThresh,
         lsEq    => postThr(i)
      );

   end generate GEN_VEC;
   
   U_PreZeroCmp : entity work.DspComparator
   generic map (
      WIDTH_G  => 17
   )
   port map (
      clk     => adcClk,
      rst     => adcRst,
      ain     => trig.intPreThresh,
      bin     => "00000000000000000",
      eq      => preThrZero
   );
   

end rtl;
