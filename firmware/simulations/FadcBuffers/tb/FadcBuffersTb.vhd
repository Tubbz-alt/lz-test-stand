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

   constant VERBOSE_PRINT : boolean := true;
   constant CLK_PERIOD_C  : time    := 5 ns;
   constant TPD_C         : time    := CLK_PERIOD_C/4;
   constant DLY_C         : natural := 16;
   constant SIM_SPEEDUP_C : boolean := true;
   
   constant ADC_DATA_TOP_C : slv(15 downto 0) := toSlv(65000,16);
   constant ADC_DATA_BOT_C : slv(15 downto 0) := toSlv(100,16);
   
   constant PGP_VC_C      : slv(3 downto 0) := "0001";
   -- expected clock cycles latency in between the trigger and its capture
   constant TRIG_LATENCY_C : integer := 1;
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
   signal axisMaster    : AxiStreamMasterType;
   signal axisSlave     : AxiStreamSlaveType;
   signal adcClk        : sl := '0';
   signal adcRst        : sl := '1';
   
   signal axilReadMaster    : AxiLiteReadMasterType;
   signal axilReadSlave     : AxiLiteReadSlaveType;
   signal axilWriteMaster   : AxiLiteWriteMasterType;
   signal axilWriteSlave    : AxiLiteWriteSlaveType;
   
   signal triggersGood  : slv(31 downto 0);
   
   constant QUEUE_SIZE_C   : integer := 1024*1024;
   constant QUEUE_BITS_C   : integer := log2(QUEUE_SIZE_C);
   shared variable triggerCnt     : integer := 0;
   shared variable triggerRdPtr   : slv(QUEUE_BITS_C-1 downto 0) := (others=>'0');
   type TrigTimeType is array (QUEUE_SIZE_C-1 downto 0) of slv(63 downto 0);
   shared variable triggerTime : TrigTimeType := (others=>(others=>'0'));
   type TrigSampleType is array (QUEUE_SIZE_C-1 downto 0) of slv(15 downto 0);
   shared variable triggerSample  : TrigSampleType := (others=>(others=>'0'));

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
   
   axisSlave.tReady  <= '1';
   
   ------------------------------------------------
   -- Fast ADC Buffer UUT
   ------------------------------------------------
   UUT: entity work.FadcBufferChannel
   generic map (
      CHANNEL_G         => x"00",
      PGP_LANE_G        => "0010",
      PGP_VC_G          => PGP_VC_C
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
      axilReadMaster    => axilReadMaster,
      axilReadSlave     => axilReadSlave,
      axilWriteMaster   => axilWriteMaster,
      axilWriteSlave    => axilWriteSlave,
      -- AxiStream output
      axisClk           => axisClk,
      axisRst           => axisRst,
      axisMaster        => axisMaster,
      axisSlave         => axisSlave
   );
   
   -- generate ADC data and time
   process(ghzClk)
   variable adcDirection : sl := '0';
   variable adcCnt : slv(1 downto 0) := "00";
   begin
      if rising_edge(ghzClk) then
         if ghzRst = '1' then
            adcData0        <= ADC_DATA_BOT_C;
            adcData1        <= ADC_DATA_BOT_C;
            adcData2        <= ADC_DATA_BOT_C;
            adcData3        <= ADC_DATA_BOT_C;
            adcDirection   := '0';
            adcCnt         := "00";
            adcDataG       <= (others=>'0');
         else
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
   process
   begin
      
      wait for 1 us;
      -- initial setup
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000000", x"01", false);  -- enable trigger
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000200", x"100", false); -- size
      

      wait;
      
   end process;
   
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
   -- Store the trigger time and sample for verification
   -----------------------------------------------------------------------
   
   process
      variable triggerWrPtr   : slv(QUEUE_BITS_C-1 downto 0) := (others=>'0');
   begin
      
      loop
         
         wait until rising_edge(extTrigger);
         
         wait until rising_edge(adcClk);
         
         -- writing
         if extTrigger = '1' then
            if triggerCnt < QUEUE_SIZE_C-1 then
               triggerTime(conv_integer(triggerWrPtr))   := gTime;
               triggerSample(conv_integer(triggerWrPtr)) := adcData(15 downto 0);   -- external trigger sample offset should be always 0
               triggerWrPtr                              := triggerWrPtr + 1;
               triggerCnt                                := triggerCnt + 1;
            else
               report "Too many triggers. Verification FIFO overflow." severity failure;
            end if;
         end if;
         
      end loop;
      
   end process;
   
   
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
   begin
   
      triggersGood      <= (others=>'0');
      
      loop
         
         --wait until axisMaster.tValid = '1';
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
               while triggerTime(conv_integer(triggerRdPtr)) + TRIG_LATENCY_C < trigTime loop
                  
                  -- report missed timestamps
                  report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": missed timestamp " & integer'image(conv_integer(triggerTime(conv_integer(triggerRdPtr))(31 downto 0))) severity warning;
                  
                  if triggerCnt > 0 then
                     triggerRdPtr := triggerRdPtr + 1;
                     triggerCnt   := triggerCnt - 1;
                     lostTriggerCnt := lostTriggerCnt + 1;
                  else
                     report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": timestamp verification queue underflow." severity failure;
                  end if;
                  
               end loop;
               
               -- report received timestamp
               report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": timestamp " & integer'image(trigTime);
               -- verify timestamp
               assert triggerTime(conv_integer(triggerRdPtr)) + TRIG_LATENCY_C = trigTime 
                  report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad timestamp. Expected " & integer'image(conv_integer(triggerTime(conv_integer(triggerRdPtr)))) & " received " & integer'image(trigTime)
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
                        offsetError := abs(conv_integer(triggerSample(conv_integer(triggerRdPtr))) - conv_integer(axisMaster.tData(15 downto 0)));
                        assert offsetError <= MAX_OFFSET_ERR_C
                           report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad offset. Expected " & integer'image(conv_integer(triggerSample(conv_integer(triggerRdPtr)))) & " received " & integer'image(conv_integer(axisMaster.tData(15 downto 0)))
                           severity warning;
                        if VERBOSE_PRINT then 
                           if offsetError = 0 then
                              report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset ok. Expected " & integer'image(conv_integer(triggerSample(conv_integer(triggerRdPtr)))) & " received " & integer'image(conv_integer(axisMaster.tData(15 downto 0)));
                           else
                              report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset with error. Expected " & integer'image(conv_integer(triggerSample(conv_integer(triggerRdPtr)))) & " received " & integer'image(conv_integer(axisMaster.tData(15 downto 0))) severity warning;
                           end if;
                        end if;
                     else -- trigOffset = 1
                        offsetError := abs(conv_integer(triggerSample(conv_integer(triggerRdPtr))) - conv_integer(axisMaster.tData(31 downto 16)));
                        assert offsetError <= MAX_OFFSET_ERR_C
                           report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) & ": bad offset. Expected " & integer'image(conv_integer(triggerSample(conv_integer(triggerRdPtr)))) & " received " & integer'image(conv_integer(axisMaster.tData(31 downto 16)))
                           severity warning;
                        if VERBOSE_PRINT then 
                           if offsetError = 0 then
                              report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset ok. Expected " & integer'image(conv_integer(triggerSample(conv_integer(triggerRdPtr)))) & " received " & integer'image(conv_integer(axisMaster.tData(31 downto 16)));
                           else
                              report "CH" & integer'image(trigCh) & ":TRIG" & integer'image(goodTriggerCnt) &  ": offset with error. Expected " & integer'image(conv_integer(triggerSample(conv_integer(triggerRdPtr)))) & " received " & integer'image(conv_integer(axisMaster.tData(31 downto 16))) severity warning;
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
               
               if triggerCnt > 0 then
                  triggerRdPtr := triggerRdPtr + 1;
                  triggerCnt   := triggerCnt - 1;
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
         
      end loop;
      
   end process;

end testbed;
