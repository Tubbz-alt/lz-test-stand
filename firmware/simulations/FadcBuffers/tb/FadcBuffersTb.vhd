-------------------------------------------------------------------------------
-- File       : FadcBuffersTb.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-05
-- Last update: 2017-07-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the LZ DDR writer and reader modules
-- SadcBufferWriter.vhd
-- SadcBufferReader.vhd
-------------------------------------------------------------------------------
-- This file is part of 'LZ Test stand'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LZ Test stand', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity FadcBuffersTb is end FadcBuffersTb;

architecture testbed of FadcBuffersTb is
   
   constant FORCE_EXT_TRIG_C : boolean := true;
   constant TEST_LOOP_C : boolean := false;
   
   
   constant VERBOSE_PRINT : boolean := true;
   constant CLK_PERIOD_C  : time    := 5 ns;
   constant TPD_C         : time    := CLK_PERIOD_C/4;
   constant DLY_C         : natural := 16;
   constant SIM_SPEEDUP_C : boolean := true;
   
   constant ADC_DATA_TOP_C : slv(15 downto 0) := toSlv(32000,16);
   constant ADC_DATA_BOT_C : slv(15 downto 0) := toSlv(100,16);
   
   constant PSEUDO_NOISE_BASE_C : IntegerArray(7 downto 0) := (
      5 => conv_integer(ADC_DATA_BOT_C)-1,
      2 => conv_integer(ADC_DATA_BOT_C)-2,
      4 => conv_integer(ADC_DATA_BOT_C)-3,
      6 => conv_integer(ADC_DATA_BOT_C)-4,
      3 => conv_integer(ADC_DATA_BOT_C)-5,
      1 => conv_integer(ADC_DATA_BOT_C)-6,
      0 => conv_integer(ADC_DATA_BOT_C)-7,
      7 => conv_integer(ADC_DATA_BOT_C)-8
   );
   
   constant PRE_THRESHOLD_C  : integer := conv_integer(ADC_DATA_TOP_C) + 1000;
   constant POST_THRESHOLD_C : integer := conv_integer(ADC_DATA_TOP_C) + 900;
   constant VETO_THRESHOLD_C : integer := conv_integer(ADC_DATA_TOP_C) + 2000;
   
   constant LONG_LOW_PEAK_C   : IntegerArray(11 downto 0) := (
      0  => PRE_THRESHOLD_C,
      1  => PRE_THRESHOLD_C+1,
      2  => PRE_THRESHOLD_C+2,
      3  => PRE_THRESHOLD_C+3,
      4  => PRE_THRESHOLD_C+4,
      5  => PRE_THRESHOLD_C+5,
      6  => POST_THRESHOLD_C-1,
      7  => POST_THRESHOLD_C-2,
      8  => POST_THRESHOLD_C-3,
      9  => POST_THRESHOLD_C-4,
      10 => POST_THRESHOLD_C-5,
      11 => POST_THRESHOLD_C-6
   );
   
   constant LONG_HIGH_PEAK_C   : IntegerArray(11 downto 0) := (
      0  => PRE_THRESHOLD_C,
      1  => PRE_THRESHOLD_C+1,
      2  => PRE_THRESHOLD_C+2,
      3  => PRE_THRESHOLD_C+3,
      4  => PRE_THRESHOLD_C+4,
      5  => PRE_THRESHOLD_C+5,
      6  => VETO_THRESHOLD_C+1,
      7  => VETO_THRESHOLD_C,
      8  => VETO_THRESHOLD_C,
      9  => VETO_THRESHOLD_C,
      10 => VETO_THRESHOLD_C,
      11 => VETO_THRESHOLD_C
   );
   
   constant MED_LOW_PEAK_C   : IntegerArray(3 downto 0) := (
      0  => PRE_THRESHOLD_C+4,
      1  => PRE_THRESHOLD_C+5,
      2  => POST_THRESHOLD_C-1,
      3  => POST_THRESHOLD_C-2
   );
   
   constant MED_HIGH_PEAK_C   : IntegerArray(3 downto 0) := (
      0  => PRE_THRESHOLD_C+4,
      1  => PRE_THRESHOLD_C+5,
      2  => VETO_THRESHOLD_C+1,
      3  => VETO_THRESHOLD_C
   );
   
   constant SHORT_LOW_PEAK_C   : IntegerArray(1 downto 0) := (
      0  => PRE_THRESHOLD_C+5,
      1  => POST_THRESHOLD_C-1
   );
   
   constant SHORT_HIGH_PEAK_C   : IntegerArray(1 downto 0) := (
      0  => PRE_THRESHOLD_C+5,
      1  => VETO_THRESHOLD_C+1
   );
   
   constant NON_VETO_SHORT_HIGH_PEAK_C   : IntegerArray(2 downto 0) := (
      0  => VETO_THRESHOLD_C+1,
      1  => PRE_THRESHOLD_C+5,
      2  => POST_THRESHOLD_C-1
   );
   
   constant VETO_SHORT_HIGH_PEAK_C   : IntegerArray(1 downto 0) := (
      0  => VETO_THRESHOLD_C+1,
      1  => POST_THRESHOLD_C-1
   );
   
   constant RETRIGGER_PEAKS_C   : IntegerArray(6 downto 0) := (
      0  => PRE_THRESHOLD_C+5,
      1  => POST_THRESHOLD_C-1,
      2  => conv_integer(ADC_DATA_BOT_C)-1,
      3  => conv_integer(ADC_DATA_BOT_C)-5,
      4  => conv_integer(ADC_DATA_BOT_C)-3,
      5  => PRE_THRESHOLD_C+4,
      6  => POST_THRESHOLD_C-2
   );
   
   type TestType is (
      IDLE_S,
      EXT_TRIG_S,
      RAND_TIME_S,
      PSEUDO_NOISE_BASE_S,
      LONG_LOW_PEAK_S,
      LONG_HIGH_PEAK_S,
      MED_LOW_PEAK_S,
      MED_HIGH_PEAK_S,
      SHORT_LOW_PEAK_S,
      SHORT_HIGH_PEAK_S,
      NON_VETO_SHORT_HIGH_PEAK_S,
      VETO_SHORT_HIGH_PEAK_S,
      RETRIGGER_PEAKS_S,
      END_SIM_S
   );
   
   signal testState : TestType := IDLE_S;
   
   constant PGP_VC_C      : slv(3 downto 0) := "0001";
   -- expected clock cycles latency in between the trigger and its capture
   constant TRIG_LATENCY_C : integer := 0;
   constant MAX_OFFSET_ERR_C  : integer := 1;
   
   signal adcData0      : slv(15 downto 0);
   signal adcData1      : slv(15 downto 0);
   signal adcData2      : slv(15 downto 0);
   signal adcData3      : slv(15 downto 0);
   signal adcDataG      : slv(63 downto 0);
   signal adcData       : slv(63 downto 0);
   
   signal extTrigger    : sl;
   
   signal gTime         : slv(63 downto 0);
   
   signal ghzClk        : sl := '0';
   signal axilClk       : sl := '0';
   signal axilRst       : sl := '1';
   signal axisClk       : sl := '0';
   signal ghzRst        : sl := '1';
   signal axisRst       : sl := '1';
   signal adcClk        : sl := '0';
   signal adcRst        : sl := '1';
   
   signal axilWriteMasters : AxiLiteWriteMasterArray(7 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(7 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(7 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(7 downto 0);

   signal axisMasters : AxiStreamMasterArray(7 downto 0);
   signal axisSlaves  : AxiStreamSlaveArray(7 downto 0);
   signal axisMaster    : AxiStreamMasterType;
   signal axisSlave     : AxiStreamSlaveType;
   
   signal triggersGood  : slv(31 downto 0);
   
   signal enable         : slv(0 downto 0);
   signal intSaveVeto    : slv(0 downto 0);
   signal intPreThresh   : slv(15 downto 0);
   signal intPostThresh  : slv(15 downto 0);
   signal intVetoThresh  : slv(15 downto 0);
   signal intPreDelay    : slv(6 downto 0);
   signal intPostDelay   : slv(6 downto 0);
   signal extTrigSize    : slv(9 downto 0);
   
   signal set_regs : sl;
   
   constant QUEUE_SIZE_C   : integer := 1024*1024;
   constant QUEUE_BITS_C   : integer := log2(QUEUE_SIZE_C);
   shared variable triggerCnt     : IntegerArray(7 downto 0) := (others=>0);
   --shared variable triggerRdPtr   : slv(QUEUE_BITS_C-1 downto 0) := (others=>'0');
   type trigPtrArray is array (natural range <>) of slv(QUEUE_BITS_C-1 downto 0);
   shared variable triggerRdPtr   : trigPtrArray(7 downto 0) := (others=>(others=>'0'));
   
   --type TrigTimeType is array (QUEUE_SIZE_C-1 downto 0) of slv(63 downto 0);
   --shared variable triggerTime : TrigTimeType := (others=>(others=>'0'));
   --type TrigSampleType is array (QUEUE_SIZE_C-1 downto 0) of slv(15 downto 0);
   --shared variable triggerSample  : TrigSampleType := (others=>(others=>'0'));
   
   type TrigTimeType is array (7 downto 0, QUEUE_SIZE_C-1 downto 0) of slv(63 downto 0);
   shared variable triggerTime : TrigTimeType := (others=>(others=>(others=>'0')));
   type TrigSampleType is array (7 downto 0, QUEUE_SIZE_C-1 downto 0) of slv(15 downto 0);
   shared variable triggerSample  : TrigSampleType := (others=>(others=>(others=>'0')));

begin
   
   -- start the buffer after memTester is dome
   ghzClk <= not ghzClk after 0.5 ns;   -- 1000.00 MHz (Fast ADC) clock
   axilClk <= not axisClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axilRst <= '0' after 100 ns;
   axisClk <= not axisClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axisRst <= '0' after 100 ns;
   adcClk <= not adcClk after 2 ns;       -- 250 MHz ADC clock
   adcRst <= '0' after 100 ns;
   ghzRst <= '0' after 100 ns;
   
   --axisSlave.tReady  <= '1';
   
   ------------------------------------------------
   -- Fast ADC Buffer UUT
   ------------------------------------------------
   GEN_VEC : for i in 7 downto 0 generate
      UUT: entity work.FadcBufferChannel
      generic map (
         CHANNEL_G         => toSlv(i,8),
         PGP_LANE_G        => "0010",
         PGP_VC_G          => PGP_VC_C,
         TRIG_ADDR_G       => 8
      )
      port map (
         -- ADC Clock Domain
         adcClk            => adcClk,
         adcRst            => adcRst,
         adcData           => adcData,
         adcValid          => '1',
         gTime             => gTime,
         extTrigger        => extTrigger,
         -- AXI-Lite Interface for local registers 
         axilClk           => axilClk,
         axilRst           => axilRst,
         axilReadMaster    => axilReadMasters(i),
         axilReadSlave     => axilReadSlaves(i),
         axilWriteMaster   => axilWriteMasters(i),
         axilWriteSlave    => axilWriteSlaves(i),
         -- AxiStream output
         axisClk           => axisClk,
         axisRst           => axisRst,
         axisMaster        => axisMasters(i),
         axisSlave         => axisSlaves(i)
      );
   end generate GEN_VEC;
   
   ---------------------
   -- Fast ADC stream mux
   ---------------------
   U_AxiStreamMux : entity work.AxiStreamMux
   generic map(
      NUM_SLAVES_G  => 8,
      PIPE_STAGES_G => 1
   )
   port map(
      axisClk      => axisClk,
      axisRst      => axisRst,
      sAxisMasters => axisMasters,
      sAxisSlaves  => axisSlaves,
      mAxisMaster  => axisMaster,
      mAxisSlave   => axisSlave
   );
   
   process(ghzClk)
   variable adcDirection : sl := '0';
   variable adcCnt : slv(1 downto 0) := "00";
   variable smplCnt : slv(15 downto 0) := (others=>'0');
   variable seed1 :positive ;
   variable seed2 :positive ;
   variable randSamplesRel : real;
   variable randSamples : integer;
   variable i : natural := 0;
   variable j : natural := 0;
   variable initDelay : natural := 5000;
   constant MAX_SAMPLES_C : natural := 1000;
   begin
      if rising_edge(ghzClk) then
         set_regs <= '0';
         if ghzRst = '1' then
            adcData0        <= ADC_DATA_BOT_C;
            adcData1        <= ADC_DATA_BOT_C;
            adcData2        <= ADC_DATA_BOT_C;
            adcData3        <= ADC_DATA_BOT_C;
            testState       <= IDLE_S;
            adcCnt          := "00";
            smplCnt         := (others=>'0');
            adcDirection    := '0';
            adcDataG        <= (others=>'0');
            extTrigSize     <= toSlv(0, 10);
            enable          <= "0";
            intSaveVeto     <= "0";
            intPreThresh    <= toSlv(0, 16);
            intPostThresh   <= toSlv(0, 16);
            intVetoThresh   <= toSlv(0, 16);
            intPreDelay     <= toSlv(0, 7);
            intPostDelay    <= toSlv(0, 7);
         else
         
            case testState is
               
               when IDLE_S =>
                  initDelay := 5000;
                  testState <= RAND_TIME_S;
                  -- initial settings
                  enable         <= "1";
                  if FORCE_EXT_TRIG_C = true then
                     --extTrigSize    <= toSlv(1015, 10);
                     extTrigSize    <= toSlv(102, 10);
                     intPreDelay    <= toSlv(127, 7);
                     intPostDelay   <= toSlv(0, 7);
                  else
                     extTrigSize    <= toSlv(0, 10);
                     intSaveVeto    <= "0";
                     intPreThresh   <= toSlv(PRE_THRESHOLD_C, 16);
                     intPostThresh  <= toSlv(POST_THRESHOLD_C, 16);
                     intVetoThresh  <= toSlv(VETO_THRESHOLD_C, 16);
                     intPreDelay    <= toSlv(10, 7);
                     intPostDelay   <= toSlv(10, 7);
                  end if;
               
               when RAND_TIME_S =>
                  set_regs <= '1';
                  -- randomize time
                  if initDelay > 0 then
                     initDelay := initDelay - 1;
                  else
                     uniform (seed1,seed2,randSamplesRel);
                     randSamples := integer(randSamplesRel * real(MAX_SAMPLES_C -1));
                     smplCnt := (others=>'0');
                     if FORCE_EXT_TRIG_C = true then
                        testState <= EXT_TRIG_S;
                     else
                        testState <= PSEUDO_NOISE_BASE_S;
                     end if;
                  end if;
                  adcData0        <= ADC_DATA_BOT_C-1;
               
               when PSEUDO_NOISE_BASE_S =>
                  -- assign samples periodically
                  if i >= PSEUDO_NOISE_BASE_C'high then
                     i := 0;
                  end if;
                  adcData0 <= toSlv(PSEUDO_NOISE_BASE_C(i), 16);
                  i := i + 1;
                  
                  -- count random time and move to the next state
                  if smplCnt >= randSamples then
                     if j = 0 then
                        j := j + 1;
                        testState <= LONG_LOW_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 1 then
                        j := j + 1;
                        testState <= LONG_HIGH_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 2 then
                        j := j + 1;
                        testState <= MED_LOW_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 3 then
                        j := j + 1;
                        testState <= MED_HIGH_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 4 then
                        j := j + 1;
                        testState <= SHORT_LOW_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 5 then
                        j := j + 1;
                        testState <= SHORT_HIGH_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 6 then
                        j := j + 1;
                        testState <= NON_VETO_SHORT_HIGH_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 7 then
                        j := j + 1;
                        testState <= VETO_SHORT_HIGH_PEAK_S;
                        smplCnt := (others=>'0');
                     elsif j = 8 then
                        j := j + 1;
                        testState <= RETRIGGER_PEAKS_S;
                        smplCnt := (others=>'0');
                     elsif j = 9 then
                        j := 1;
                        if TEST_LOOP_C = true then
                           -- repeat all waveforms in a loop
                           testState <= LONG_LOW_PEAK_S;
                           smplCnt := (others=>'0');
                        else
                           -- end simulation after a delay
                           testState <= END_SIM_S;
                           smplCnt := toSlv(5000, 16);
                        end if;
                     end if;
                     i := 0;
                     
                  else
                     smplCnt := smplCnt + 1;
                  end if;
                  
                  
               when LONG_LOW_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(LONG_LOW_PEAK_C(i), 16);
                  if i >= LONG_LOW_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
               when LONG_HIGH_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(LONG_HIGH_PEAK_C(i), 16);
                  if i >= LONG_HIGH_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
                  
               when MED_LOW_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(MED_LOW_PEAK_C(i), 16);
                  if i >= MED_LOW_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
                  
               when MED_HIGH_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(MED_HIGH_PEAK_C(i), 16);
                  if i >= MED_HIGH_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
                  
               when SHORT_LOW_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(SHORT_LOW_PEAK_C(i), 16);
                  if i >= SHORT_LOW_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
                  
               when SHORT_HIGH_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(SHORT_HIGH_PEAK_C(i), 16);
                  if i >= SHORT_HIGH_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
                  
               when NON_VETO_SHORT_HIGH_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(NON_VETO_SHORT_HIGH_PEAK_C(i), 16);
                  if i >= NON_VETO_SHORT_HIGH_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
                  
                  
               when VETO_SHORT_HIGH_PEAK_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(VETO_SHORT_HIGH_PEAK_C(i), 16);
                  if i >= VETO_SHORT_HIGH_PEAK_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                     -- change settings for next
                     intPostDelay   <= toSlv(4, 7);
                  else
                     i := i + 1;
                  end if;
               
               when RETRIGGER_PEAKS_S =>
                  -- assign samples once and move to the next state
                  adcData0 <= toSlv(RETRIGGER_PEAKS_C(i), 16);
                  if i >= RETRIGGER_PEAKS_C'high then
                     i := 0;
                     testState <= RAND_TIME_S;
                  else
                     i := i + 1;
                  end if;
               
               when EXT_TRIG_S =>
                  
                  if adcDirection = '0' then
                     if adcData0 < ADC_DATA_TOP_C then
                        adcData0 <= adcData0 + 1;
                     else
                        adcData0 <= adcData0 - 1;
                        adcDirection := '1';
                     end if;
                  else
                     if adcData0 > ADC_DATA_BOT_C then
                        adcData0 <= adcData0 - 1;
                     else
                        adcData0 <= adcData0 + 1;
                        adcDirection := '0';
                     end if;
                  end if;
               
               when END_SIM_S =>
                  if smplCnt = 0 then
                     report "Simulation finished" severity failure;
                  else
                     smplCnt := smplCnt - 1;
                  end if;
                  
               when others =>
                  testState <= RAND_TIME_S;
         
            end case;
            
            adcData1 <= adcData0;
            adcData2 <= adcData1;
            adcData3 <= adcData2;
            if adcCnt = "11" then
               adcDataG <= adcData0 & adcData1 & adcData2 & adcData3;
            end if;
            adcCnt   := adcCnt + 1;
         end if;
      end if;
   end process;
   
   process(adcClk)
   begin
      if rising_edge(adcClk) then
         if adcRst = '1' then
            adcData        <= (others => '0')  ;
            gTime          <= (others => '0')  ;
         else
            adcData        <= adcDataG;
            gTime          <= gTime + 1;
         end if;
      end if;
   end process;
   
   -----------------------------------------------------------------------
   -- Setup trigger registers
   -----------------------------------------------------------------------
   SET_GEN: for i in 0 to 7 generate 
      process
      begin
         
         wait until rising_edge(set_regs);
         
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000000", enable, false);  -- enable trigger
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000200", extTrigSize, false); -- size
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000100", intPreThresh, false);  -- 
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000104", intPostThresh, false);  -- 
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000108", intVetoThresh, false);  -- 
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"0000010C", intPreDelay, false);  -- pre delay
         axiLiteBusSimWrite(axilClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000110", intPostDelay, false);  -- post delay
         
      end process;
   end generate;
   
   
   -----------------------------------------------------------------------
   -- Generate external trigger
   -----------------------------------------------------------------------
   process
   begin
      extTrigger <= '0';
      
      
      loop
         
         wait for 10 us;
         
         wait until falling_edge(adcClk);
         extTrigger <= '1';
         wait until falling_edge(adcClk);
         
         extTrigger <= '0';
         
      end loop;
      
   end process;
   
   -----------------------------------------------------------------------
   -- backpressure the output stream
   -----------------------------------------------------------------------
   process
   begin
      
      axisSlave.tReady  <= '1';
      
      loop
         
         wait for 1000 us;
         
         wait until falling_edge(axisClk);
         
         axisSlave.tReady <= not axisSlave.tReady;
         
      end loop;
      
   end process;
   
   -----------------------------------------------------------------------
   -- Store the trigger time and sample for verification
   -----------------------------------------------------------------------
   TR_MEM_GEN: for i in 0 to 7 generate 
      process
         variable triggerWrPtr   : slv(QUEUE_BITS_C-1 downto 0) := (others=>'0');
      begin
         
         loop
            
            wait until rising_edge(extTrigger);
            
            wait until rising_edge(adcClk);
            
            -- writing
            if extTrigger = '1' then
               if triggerCnt(i) < QUEUE_SIZE_C-1 then
                  triggerTime(i, conv_integer(triggerWrPtr))   := gTime;
                  triggerSample(i, conv_integer(triggerWrPtr)) := adcData(15 downto 0);   -- external trigger sample offset should be always 0
                  triggerWrPtr                              := triggerWrPtr + 1;
                  triggerCnt(i)                             := triggerCnt(i) + 1;
               else
                  report "Too many triggers. Verification FIFO overflow." severity failure;
               end if;
            end if;
            
         end loop;
         
      end process;
   end generate;
   
   
   -----------------------------------------------------------------------
   -- Monitor the output stream (trigger data)
   -----------------------------------------------------------------------
   process
      variable trigCh         : integer := 0;
      variable trigSize       : integer := 0;
      variable trigOffset     : integer := 0;
      variable trigTimeVect   : slv(63 downto 0) := (others=>'0');
      variable trigTime       : integer := 0;
      variable sampleCnt      : integer := 0;
      variable wordCnt        : integer := 0;
      variable offsetCnt      : integer := 0;
      variable adcGoingUp     : boolean;
      variable adcPrevious    : slv(15 downto 0);
      variable adcOffsetVal   : integer;
      variable adcOffsetChk   : boolean;
      variable lostTriggerCnt : natural := 0;
      variable goodTriggerCnt : natural := 0;
      variable offsetError    : integer := 0;
      variable sampleNo       : integer := 0;
   begin
   
      triggersGood      <= (others=>'0');
      
      
      
      loop
         
         ------------------------------------------------------------------
         -- External triggering verification
         ------------------------------------------------------------------
         if FORCE_EXT_TRIG_C = true then
         
            wait until rising_edge(axisClk);
            
            if axisMaster.tValid = '1' and axisSlave.tReady = '1' then
               -- reset counter if start of packet
               if axisMaster.tUser(1 downto 0) = "10" then
                  wordCnt     := 0;
                  offsetCnt   := 0;
                  sampleCnt   := 0;
                  adcOffsetChk := true;
               else
                  wordCnt     := wordCnt + 1;
               end if;
               
               -- check and report the packet content
               if wordCnt = 0 then
                  --has only PGP info
                  assert axisMaster.tData(3 downto 0) = PGP_VC_C report "Bad PGP VC number" severity failure;
               elsif wordCnt = 1 then     -- header
                  trigCh := conv_integer(axisMaster.tData(7 downto 0));
                  assert trigCh >=0 and trigCh <= 7 report "Bad channel number" severity failure;
               elsif wordCnt = 2 then  -- header
                  trigSize := conv_integer(axisMaster.tData(21 downto 0));
                  if trigSize = 0 then
                     adcOffsetChk := false;
                  end if;
                  if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": size " & integer'image(trigSize); end if;
               elsif wordCnt = 3 then  -- header
                  trigOffset := conv_integer(axisMaster.tData(31 downto 0));
                  if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset " & integer'image(trigOffset); end if;
                  if trigOffset > 0 then
                     trigOffset := trigOffset;
                  end if;
                  --report "trigOffset: " & integer'image(trigOffset);
               elsif wordCnt = 4 then  -- header
                  trigTimeVect(31 downto 0) := axisMaster.tData(31 downto 0);
               elsif wordCnt = 5 then  -- header
                  trigTimeVect(63 downto 32) := axisMaster.tData(31 downto 0);
                  trigTime := conv_integer(trigTimeVect(31 downto 0));
                  
                  -- count and remove lost triggers from the trigger verification queue
                  while triggerTime(trigCh, conv_integer(triggerRdPtr(trigCh))) + TRIG_LATENCY_C < trigTime loop
                     
                     -- report missed timestamps
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": missed timestamp " & integer'image(conv_integer(triggerTime(trigCh, conv_integer(triggerRdPtr(trigCh)))(31 downto 0))) severity warning;
                     
                     if triggerCnt(trigCh) > 0 then
                        triggerRdPtr(trigCh) := triggerRdPtr(trigCh) + 1;
                        triggerCnt(trigCh)   := triggerCnt(trigCh) - 1;
                        lostTriggerCnt := lostTriggerCnt + 1;
                     else
                        report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": timestamp verification queue underflow." severity failure;
                     end if;
                     
                  end loop;
                  
                  -- report received timestamp
                  report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": timestamp " & integer'image(trigTime);
                  -- verify timestamp
                  assert triggerTime(trigCh, conv_integer(triggerRdPtr(trigCh))) + TRIG_LATENCY_C = trigTime 
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad timestamp. Expected " & integer'image(conv_integer(triggerTime(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(trigTime)
                     severity failure;
                     
               -- all other words contain 2 samples
               else
                  
                  -- verify trigger offset
                  if trigOffset > 1 then
                     trigOffset := trigOffset - 2;
                  else
                     if adcOffsetChk = true then
                        adcOffsetChk := false;
                        --report "wordCnt: " & integer'image(wordCnt) & " trigOffset: " & integer'image(trigOffset);
                        
                        if trigOffset = 0 then
                           offsetError := abs(conv_integer(triggerSample(trigCh,  conv_integer(triggerRdPtr(trigCh)))) - conv_integer(axisMaster.tData(15 downto 0)));
                           assert offsetError <= MAX_OFFSET_ERR_C
                              report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad offset. Expected " & integer'image(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(conv_integer(axisMaster.tData(15 downto 0)))
                              severity warning;
                           if VERBOSE_PRINT then 
                              if offsetError = 0 then
                                 report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset ok. Expected " & integer'image(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(conv_integer(axisMaster.tData(15 downto 0)));
                              else
                                 report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset with error. Expected " & integer'image(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(conv_integer(axisMaster.tData(15 downto 0))) severity warning;
                              end if;
                           end if;
                        else -- trigOffset = 1
                           offsetError := abs(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh)))) - conv_integer(axisMaster.tData(31 downto 16)));
                           assert offsetError <= MAX_OFFSET_ERR_C
                              report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad offset. Expected " & integer'image(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(conv_integer(axisMaster.tData(31 downto 16)))
                              severity warning;
                           if VERBOSE_PRINT then 
                              if offsetError = 0 then
                                 report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset ok. Expected " & integer'image(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(conv_integer(axisMaster.tData(31 downto 16)));
                              else
                                 report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset with error. Expected " & integer'image(conv_integer(triggerSample(trigCh, conv_integer(triggerRdPtr(trigCh))))) & " received " & integer'image(conv_integer(axisMaster.tData(31 downto 16))) severity warning;
                              end if;
                           end if;
                        end if;
                     end if;
                  end if;
                  
                  -- discover data direction in first word
                  if wordCnt = 6 then
                     if axisMaster.tData(15 downto 0) = ADC_DATA_BOT_C or axisMaster.tData(31 downto 16) = ADC_DATA_BOT_C then
                        adcGoingUp := true;
                     elsif axisMaster.tData(15 downto 0) = ADC_DATA_TOP_C or axisMaster.tData(31 downto 16) = ADC_DATA_TOP_C then
                        adcGoingUp := false;
                     elsif axisMaster.tData(31 downto 16) > axisMaster.tData(15 downto 0) then
                        adcGoingUp := true;
                     else
                        adcGoingUp := false;
                     end if;
                     adcPrevious := axisMaster.tData(31 downto 16);
                  end if;
                  
                  -- count all samples
                  if axisMaster.tKeep(3 downto 0) = "1111" then
                     sampleCnt := sampleCnt + 2;
                  elsif axisMaster.tKeep(3 downto 0) = "0011" and axisMaster.tLast = '1' then
                     sampleCnt := sampleCnt + 1;
                  elsif axisMaster.tKeep(3 downto 0) = "1100" and axisMaster.tLast = '1' then
                     sampleCnt := sampleCnt + 1;
                  else
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad tKeep!" severity failure;
                  end if;
                  
                  -- verify all samples
                  if wordCnt /= 6 and (axisMaster.tLast /= '1' or axisMaster.tKeep(3 downto 0) = "1111") then
                     if adcGoingUp = true then
                        if axisMaster.tData(15 downto 0) = ADC_DATA_TOP_C or axisMaster.tData(31 downto 16) = ADC_DATA_TOP_C then
                           adcGoingUp := false;
                           adcPrevious := axisMaster.tData(31 downto 16);
                           if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": top ADC peak"; end if;
                        else
                           -- check samples here
                           assert adcPrevious = axisMaster.tData(15 downto 0)-1 report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad ADC values" severity failure;
                           assert axisMaster.tData(15 downto 0) < axisMaster.tData(31 downto 16) report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad ADC values" severity failure;
                           -- update previous
                           adcPrevious := axisMaster.tData(31 downto 16);
                        end if;
                     else
                        if axisMaster.tData(15 downto 0) = ADC_DATA_BOT_C or axisMaster.tData(31 downto 16) = ADC_DATA_BOT_C then
                           adcGoingUp := true;
                           adcPrevious := axisMaster.tData(31 downto 16);
                           if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bottom ADC peak"; end if;
                        else
                           -- check samples here
                           assert adcPrevious = axisMaster.tData(15 downto 0)+1 report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad ADC values" severity failure;
                           assert axisMaster.tData(15 downto 0) > axisMaster.tData(31 downto 16) report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad ADC values" severity failure;
                           -- update previous
                           adcPrevious := axisMaster.tData(31 downto 16);
                        end if;
                     end if;
                  end if;
                  
               end if;
               
               -- validate and report trigger size at last word
               if axisMaster.tLast = '1' then
                  
                  if triggerCnt(trigCh) > 0 then
                     triggerRdPtr(trigCh) := triggerRdPtr(trigCh) + 1;
                     triggerCnt(trigCh)   := triggerCnt(trigCh) - 1;
                  else
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": timestamp verification queue underflow." severity failure;
                  end if;
                  
                  if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": samples " & integer'image(sampleCnt); end if;
                  assert sampleCnt = trigSize 
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": wrong number of samples. Expected " & integer'image(trigSize) & " received " & integer'image(sampleCnt)
                     severity failure;
                  triggersGood <= triggersGood + 1;
                  goodTriggerCnt := goodTriggerCnt + 1;
               end if;
            end if;
         
         
         ------------------------------------------------------------------
         -- Internal triggering verification
         ------------------------------------------------------------------
         else
            
            wait until rising_edge(axisClk);
            
            if axisMaster.tValid = '1' and axisSlave.tReady = '1' then
               -- reset counter if start of packet
               if axisMaster.tUser(1 downto 0) = "10" then
                  wordCnt     := 0;
                  offsetCnt   := 0;
                  sampleCnt   := 0;
               else
                  wordCnt     := wordCnt + 1;
               end if;
               
               -- check and report the packet content
               if wordCnt = 0 then
                  --has only PGP info
                  assert axisMaster.tData(3 downto 0) = PGP_VC_C report "Bad PGP VC number" severity failure;
               elsif wordCnt = 1 then     -- header
                  trigCh := conv_integer(axisMaster.tData(7 downto 0));
                  assert trigCh >=0 and trigCh <= 7 report "Bad channel number" severity failure;
               elsif wordCnt = 2 then  -- header
                  trigSize := conv_integer(axisMaster.tData(21 downto 0));
                  if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": size " & integer'image(trigSize); end if;
               elsif wordCnt = 3 then  -- header
                  trigOffset := conv_integer(axisMaster.tData(31 downto 0));
                  if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset " & integer'image(trigOffset); end if;
                  if trigOffset > 0 then
                     trigOffset := trigOffset;
                  end if;
               elsif wordCnt = 4 then  -- header
                  trigTimeVect(31 downto 0) := axisMaster.tData(31 downto 0);
               elsif wordCnt = 5 then  -- header
                  trigTimeVect(63 downto 32) := axisMaster.tData(31 downto 0);
                  trigTime := conv_integer(trigTimeVect(31 downto 0));
                  -- report received timestamp
                  report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": timestamp " & integer'image(trigTime);
                  
                  sampleNo := 0;
                  
               -- all other words contain 2 samples
               else
                  
                  -- count all samples
                  if axisMaster.tKeep(3 downto 0) = "1111" then
                     sampleCnt := sampleCnt + 2;
                  elsif axisMaster.tKeep(3 downto 0) = "0011" and axisMaster.tLast = '1' then
                     sampleCnt := sampleCnt + 1;
                  elsif axisMaster.tKeep(3 downto 0) = "1100" and axisMaster.tLast = '1' then
                     sampleCnt := sampleCnt + 1;
                  else
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad tKeep!" severity failure;
                  end if;
                  
                  -- print all samples
                  report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": sample " & integer'image(sampleNo) & ": "  & integer'image(conv_integer(axisMaster.tData(15 downto 0))) severity note;
                  sampleNo := sampleNo + 1;
                  report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": sample " & integer'image(sampleNo) & ": "  & integer'image(conv_integer(axisMaster.tData(31 downto 16))) severity note;
                  sampleNo := sampleNo + 1;
                  
                  
               end if;
               
               -- validate and report trigger size at last word
               if axisMaster.tLast = '1' then
                  
                  if VERBOSE_PRINT then report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": samples " & integer'image(sampleCnt); end if;
                  assert sampleCnt = trigSize 
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": wrong number of samples. Expected " & integer'image(trigSize) & " received " & integer'image(sampleCnt)
                     severity failure;
                  triggersGood <= triggersGood + 1;
                  goodTriggerCnt := goodTriggerCnt + 1;
               end if;
            end if;
            
            
            
         end if;
         
         
      end loop;
      
      
   end process;

end testbed;
