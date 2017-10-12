-------------------------------------------------------------------------------
-- File       : DdrBufferTb.vhd
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
use work.AxiPkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DdrBufferTb is end DdrBufferTb;

architecture testbed of DdrBufferTb is

   constant VERBOSE_PRINT : boolean := true;
   
   -- address size of a single channel
   constant ADDR_BITS_C : integer := 18;
   
   -- define ADC swing
   constant ADC_DATA_TOP_C : slv(15 downto 0) := toSlv(1000,16);
   constant ADC_DATA_BOT_C : slv(15 downto 0) := toSlv(100,16);
   
   -- expected clock cycles latency in between the trigger and its capture
   constant TRIG_LATENCY_C : integer := 1;
   
   constant CLK_PERIOD_C  : time    := 5 ns;
   constant TPD_C         : time    := CLK_PERIOD_C/4;
   constant DLY_C         : natural := 16;
   constant SIM_SPEEDUP_C : boolean := true;
   
   constant PGP_VC_C      : slv(3 downto 0) := "0001";

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 31,
      DATA_BYTES_C => 64,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');

   component Ddr4ModelWrapper
      generic (
         DDR_WIDTH_G : integer);
      port (
         c0_ddr4_dq       : inout slv(DDR_WIDTH_C-1 downto 0);
         c0_ddr4_dqs_c    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
         c0_ddr4_dqs_t    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
         c0_ddr4_adr      : in    slv(16 downto 0);
         c0_ddr4_ba       : in    slv(1 downto 0);
         c0_ddr4_bg       : in    slv(0 to 0);
         c0_ddr4_reset_n  : in    sl;
         c0_ddr4_act_n    : in    sl;
         c0_ddr4_ck_t     : in    slv(0 to 0);
         c0_ddr4_ck_c     : in    slv(0 to 0);
         c0_ddr4_cke      : in    slv(0 to 0);
         c0_ddr4_cs_n     : in    slv(0 to 0);
         c0_ddr4_dm_dbi_n : inout slv((DDR_WIDTH_C/8)-1 downto 0);
         c0_ddr4_odt      : in    slv(0 to 0));
   end component;

   signal clk       : sl                    := '0';
   signal rst       : sl                    := '0';
   signal rstL      : sl                    := '1';
   signal passed    : sl                    := '0';
   signal failed    : sl                    := '0';
   signal passedDly : slv(DLY_C-1 downto 0) := (others => '0');
   signal failedDly : slv(DLY_C-1 downto 0) := (others => '0');

   signal ddrClkP : sl := '0';
   signal ddrClkN : sl := '0';

   signal c0_ddr4_dq       : slv(DDR_WIDTH_C-1 downto 0)     := (others => '0');
   signal c0_ddr4_dqs_c    : slv((DDR_WIDTH_C/8)-1 downto 0) := (others => '0');
   signal c0_ddr4_dqs_t    : slv((DDR_WIDTH_C/8)-1 downto 0) := (others => '0');
   signal c0_ddr4_adr      : slv(16 downto 0)                := (others => '0');
   signal c0_ddr4_ba       : slv(1 downto 0)                 := (others => '0');
   signal c0_ddr4_bg       : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_reset_n  : sl                              := '0';
   signal c0_ddr4_act_n    : sl                              := '0';
   signal c0_ddr4_ck_t     : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_ck_c     : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_cke      : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_cs_n     : slv(0 to 0)                     := (others => '0');
   signal c0_ddr4_dm_dbi_n : slv((DDR_WIDTH_C/8)-1 downto 0) := (others => '0');
   signal c0_ddr4_odt      : slv(0 to 0)                     := (others => '0');

   signal axiClk         : sl := '0';
   signal axiRst         : sl := '0';
   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;
   signal axiWriteMaster : AxiWriteMasterType;
   signal axiWriteSlave  : AxiWriteSlaveType;
   signal ddrCalDone     : sl := '0';
   
   signal axiAdcWriteMasters   : AxiWriteMasterArray(7 downto 0);
   signal axiAdcWriteSlaves    : AxiWriteSlaveArray(7 downto 0);
   signal axiDoutReadMaster    : AxiReadMasterType;
   signal axiDoutReadSlave     : AxiReadSlaveType;
   signal axiBistReadMaster    : AxiReadMasterType;
   signal axiBistReadSlave     : AxiReadSlaveType;
   signal axiBistWriteMaster   : AxiWriteMasterType;
   signal axiBistWriteSlave    : AxiWriteSlaveType;
   
   signal axilWriteMasters : AxiLiteWriteMasterArray(7 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(7 downto 0);
   
   signal adcData    : slv(15 downto 0);
   
   signal writerRst     : sl;
   signal extTrigger    : slv(7 downto 0);
   
   signal gTime         : slv(63 downto 0);
   
   signal hdrDout       : Slv32Array(7 downto 0);
   signal hdrValid      : slv(7 downto 0);
   signal hdrRd         : slv(7 downto 0);
   signal memWrAddr     : Slv32Array(7 downto 0);
   signal memFull       : slv(7 downto 0);
   signal axisClk       : sl := '0';
   signal axisRst       : sl := '1';
   signal axisMaster    : AxiStreamMasterType;
   signal axisSlave     : AxiStreamSlaveType;
   signal adcClk        : sl := '0';
   signal adcRst        : sl := '1';
   
   signal triggersGood  : Slv32Array(7 downto 0);
   signal trigTimeVer   : Slv64Array(7 downto 0);
   signal trigSampleVer : Slv16Array(7 downto 0);
   signal trigRdVer     : slv(7 downto 0);

begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => rstL);

   OBUFDS_Inst : OBUFDS
      port map (
         I  => clk,
         O  => ddrClkP,
         Ob => ddrClkN
   );
   
   -- start the buffer after memTester is dome
   writerRst <= not passedDly(DLY_C-1);
   axisClk <= not axisClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axisRst <= '0' after 100 ns;
   adcClk <= not adcClk after 2 ns;       -- 250 MHz ADC clock
   adcRst <= '0' after 100 ns;
   
   ------------------------------------------------
   -- Buffer Writers UUT
   ------------------------------------------------
   WRITER_GEN : for i in 0 to 7 generate 
      U_SadcBufferWriter : entity work.SadcBufferWriter
      generic map (
         ADDR_BITS_G       => ADDR_BITS_C,
         ADDR_OFFSET_G     => toSlv(i*2**ADDR_BITS_C, 32)
      )
      port map (
         -- ADC interface
         adcClk            => adcClk,
         adcRst            => writerRst,
         adcData           => adcData,
         gTime             => gTime,
         extTrigger        => extTrigger(i),
         -- AXI-Lite Interface for local registers 
         axilClk           => axiClk,
         axilRst           => axiRst,
         axilReadMaster    => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave     => open,
         axilWriteMaster   => axilWriteMasters(i),
         axilWriteSlave    => axilWriteSlaves(i),
         -- AXI Interface (adcClk)
         axiWriteMaster    => axiAdcWriteMasters(i),
         axiWriteSlave     => axiAdcWriteSlaves(i),
         -- Trigger information to data reader (adcClk)
         hdrDout           => hdrDout(i),
         hdrValid          => hdrValid(i),
         hdrRd             => hdrRd(i),
         -- Buffer handshake to/from data reader (adcClk)
         memWrAddr         => memWrAddr(i),
         memFull           => memFull(i)
      );
   end generate;
   
   ------------------------------------------------
   -- Buffer Reader UUT
   ------------------------------------------------
   U_SadcBufferReader: entity work.SadcBufferReader
   generic map (
      ADDR_BITS_G       => ADDR_BITS_C,
      PGP_VC_G          => PGP_VC_C
   )
   port map (
      -- ADC Clock Domain
      adcClk            => adcClk,
      adcRst            => writerRst,
      -- AXI-Lite Interface for local registers 
      axilClk           => axiClk,
      axilRst           => axiRst,
      axilReadMaster    => AXI_LITE_READ_MASTER_INIT_C,
      axilReadSlave     => open,
      axilWriteMaster   => AXI_LITE_WRITE_MASTER_INIT_C,
      axilWriteSlave    => open,
      -- AXI Interface (adcClk)
      axiReadMaster     => axiDoutReadMaster,
      axiReadSlave      => axiDoutReadSlave,
      -- Trigger information from data writers (adcClk)
      hdrDout           => hdrDout,
      hdrValid          => hdrValid,
      hdrRd             => hdrRd,
      -- Buffer handshake to/from data writers (adcClk)
      memWrAddr         => memWrAddr,
      memFull           => memFull,
      -- AxiStream output
      axisClk           => axisClk,
      axisRst           => axisRst,
      axisMaster        => axisMaster,
      axisSlave         => axisSlave
   );
   
   -- generate ADC data and time
   -- ADC data is a full swing saw signal
   process(adcClk)
   variable adcDirection : sl := '0';
   begin
      if rising_edge(adcClk) then
         if adcRst = '1' then
            adcData        <= ADC_DATA_BOT_C after TPD_C;
            adcDirection   := '0';
            gTime          <= (others => '0') after TPD_C;
         else
            if adcDirection = '0' then
               if adcData < ADC_DATA_TOP_C then
                  adcData <= adcData + 1 after TPD_C;
               else
                  adcData <= adcData - 1 after TPD_C;
                  adcDirection := '1';
               end if;
            else
               if adcData > ADC_DATA_BOT_C then
                  adcData <= adcData - 1 after TPD_C;
               else
                  adcData <= adcData + 1 after TPD_C;
                  adcDirection := '0';
               end if;
            end if;
            gTime <= gTime + 1 after TPD_C;
         end if;
      end if;
   end process;
   
   -----------------------------------------------------------------------
   -- Setup trigger registers
   -----------------------------------------------------------------------
   SETUP_GEN: for i in 0 to 7 generate 
      process
         variable seed1 : positive := (i+1)*78;
         variable seed2 : positive := (i+1)*34;
         variable rand: real;
         variable randSize : integer;
      begin
         
         wait for 1 us;
         -- initial setup
         axiLiteBusSimWrite(axiClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000000", x"01", false);  -- enable trigger
         axiLiteBusSimWrite(axiClk, axilWriteMasters(i), axilWriteSlaves(i), x"0000010C", x"05", false);  -- pre delay
         axiLiteBusSimWrite(axiClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000200", x"202", false); -- size
         
         -- change size after every trigger
         -- randomly 1 to 1050 samples
         loop
            
            wait until rising_edge(extTrigger(i));
            wait for 500 ns;
            
            uniform(seed1, seed2, rand);   -- generate random number 0.0 to 1.0
            randSize := integer(rand*1049.0+1.0);
            axiLiteBusSimWrite(axiClk, axilWriteMasters(i), axilWriteSlaves(i), x"00000200", toSlv(randSize, 16), false);
            
            
         end loop;

         wait;
         
      end process;
   end generate;
   
   -----------------------------------------------------------------------
   -- Generate external trigger
   -----------------------------------------------------------------------
   process
      variable trigJitter : integer := 0;
      variable seed1, seed2: positive;
      variable rand: real; 
   begin
      extTrigger <= (others=>'0');
      
      wait until writerRst = '0';
      
      loop
         
         wait for 10 us;    -- 100kHz will overflow with 1050 samples per trigger
         --wait for 25 us;      -- 40kHz should not overflow with 514 samples per trigger
         
         uniform(seed1, seed2, rand);   -- generate random number 0.0 to 1.0
         trigJitter := integer(rand*24);
         wait until falling_edge(adcClk);
         for i in 0 to trigJitter loop
            wait until falling_edge(adcClk);
         end loop;
         extTrigger <= (others=>'1');
         wait until falling_edge(adcClk);
         
         extTrigger <= (others=>'0');
         
      end loop;
      
   end process;
   
   -----------------------------------------------------------------------
   -- Store the trigger time and sample for verification
   -----------------------------------------------------------------------
   TR_MEM_GEN: for i in 0 to 7 generate 
      process
         constant QUEUE_SIZE_C   : integer := 1024;
         constant QUEUE_BITS_C   : integer := log2(QUEUE_SIZE_C);
         variable triggerTime    : Slv64Array(QUEUE_SIZE_C-1 downto 0) := (others=>(others=>'0'));
         variable triggerSample  : Slv16Array(QUEUE_SIZE_C-1 downto 0) := (others=>(others=>'0'));
         variable triggerCnt     : integer range 0 to QUEUE_SIZE_C-1 := 0;
         variable triggerRdPtr   : slv(QUEUE_BITS_C-1 downto 0) := (others=>'0');
         variable triggerWrPtr   : slv(QUEUE_BITS_C-1 downto 0) := (others=>'0');
      begin
         
         trigTimeVer(i)    <= (others=>'0');
         trigSampleVer(i)  <= (others=>'0');
         
         loop
            
            wait until rising_edge(extTrigger(i)) or trigRdVer(i) = '1';
            
            wait until rising_edge(adcClk);
            
            -- writing
            if extTrigger(i) = '1' then
               if triggerCnt < QUEUE_SIZE_C-1 then
                  triggerTime(conv_integer(triggerWrPtr))   := gTime;
                  triggerSample(conv_integer(triggerWrPtr)) := adcData;
                  triggerWrPtr                              := triggerWrPtr + 1;
                  triggerCnt                                := triggerCnt + 1;
               else
                  report "Too many triggers. Verification FIFO overflow." severity failure;
               end if;
            end if;
            
            -- reading
            if trigRdVer(i) = '1' then
               if triggerCnt > 0 then
                  triggerRdPtr   := triggerRdPtr + 1;
                  triggerCnt     := triggerCnt - 1;
               else
                  report "Verification FIFO underflow." severity failure;
               end if;
            end if;
            
            trigTimeVer(i)    <= triggerTime(conv_integer(triggerRdPtr));
            trigSampleVer(i)  <= triggerSample(conv_integer(triggerRdPtr));
            
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
   begin
   
      axisSlave.tReady  <= '1';
      trigRdVer         <= (others=>'0');
      triggersGood      <= (others=>(others=>'0'));
      
      loop
         
         --wait until axisMaster.tValid = '1';
         wait until rising_edge(axisClk);
         
         if axisMaster.tValid = '1' then
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
               if VERBOSE_PRINT then report "Reading channel " & integer'image(trigCh); end if;
               assert trigCh >=0 and trigCh <= 7 report "Bad channel number" severity failure;
            elsif wordCnt = 2 then  -- header
               trigSize := conv_integer(axisMaster.tData(31 downto 0));
               if VERBOSE_PRINT then report "Trigger size " & integer'image(trigSize); end if;
            elsif wordCnt = 3 then  -- header
               trigOffset := conv_integer(axisMaster.tData(31 downto 0));
               if VERBOSE_PRINT then report "Trigger offset " & integer'image(trigOffset); end if;
            elsif wordCnt = 4 then  -- header
               trigTimeVect(63 downto 32) := axisMaster.tData(31 downto 0);
            elsif wordCnt = 5 then  -- header
               trigTimeVect(31 downto 0) := axisMaster.tData(31 downto 0);
               trigTime := conv_integer(trigTimeVect(31 downto 0));
               assert trigTimeVer(trigCh) + TRIG_LATENCY_C = trigTime 
                  report "Bad timestamp. Expected " & integer'image(conv_integer(trigTimeVer(trigCh)(31 downto 0))) & " received " & integer'image(trigTime)
                  severity failure;
               if VERBOSE_PRINT then report "Trigger time " & integer'image(trigTime); end if;
            -- all other words contain 2 samples
            else
               
               ---- verify trigger offset
               --if adcOffsetChk and offsetCnt >= trigOffset then
               --   
               --   adcOffsetChk := false;
               --   
               --   if trigOffset mod 2 = 0 then
               --      adcOffsetVal := conv_integer(axisMaster.tData(15 downto 0));
               --   else
               --      adcOffsetVal := conv_integer(axisMaster.tData(31 downto 16));
               --   end if;
               --   assert trigSampleVer(trigCh) + TRIG_LATENCY_C = adcOffsetVal 
               --      report "Bad ADC sample at trigger position. Expected " & integer'image(conv_integer(trigSampleVer(trigCh))) & " received " & integer'image(adcOffsetVal)
               --      severity failure;
               --else
               --   -- move data offset couner
               --   offsetCnt := offsetCnt + 2;
               --end if;
               
               -- discover data direction in first word
               if wordCnt = 6 then
                  if axisMaster.tData(15 downto 0) = ADC_DATA_BOT_C then
                     adcGoingUp := true;
                  elsif axisMaster.tData(15 downto 0) = ADC_DATA_TOP_C then
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
                  report "Bad tKeep!" severity failure;
               end if;
               
               -- verify all samples
               if wordCnt /= 6 and (axisMaster.tLast /= '1' or axisMaster.tKeep(3 downto 0) = "1111") then
                  if adcGoingUp = true then
                     if axisMaster.tData(15 downto 0) = ADC_DATA_TOP_C or axisMaster.tData(31 downto 16) = ADC_DATA_TOP_C then
                        adcGoingUp := false;
                        adcPrevious := axisMaster.tData(31 downto 16);
                        if VERBOSE_PRINT then report "Top ADC peak in trigger"; end if;
                     else
                        -- check samples here
                        assert adcPrevious < axisMaster.tData(15 downto 0) report "Bad ADC values in trigger" severity failure;
                        assert axisMaster.tData(15 downto 0) < axisMaster.tData(31 downto 16) report "Bad ADC values in trigger" severity failure;
                     end if;
                  else
                     if axisMaster.tData(15 downto 0) = ADC_DATA_BOT_C or axisMaster.tData(31 downto 16) = ADC_DATA_BOT_C then
                        adcGoingUp := true;
                        adcPrevious := axisMaster.tData(31 downto 16);
                        if VERBOSE_PRINT then report "Bottom ADC peak in trigger"; end if;
                     else
                        -- check samples here
                        assert adcPrevious > axisMaster.tData(15 downto 0) report "Bad ADC values in trigger" severity failure;
                        assert axisMaster.tData(15 downto 0) > axisMaster.tData(31 downto 16) report "Bad ADC values in trigger" severity failure;
                     end if;
                  end if;
               end if;
               
            end if;
            
            -- validate and report trigger size at last word
            if axisMaster.tLast = '1' then
               trigRdVer(trigCh)  <= '1';
               if VERBOSE_PRINT then report "Trigger samples " & integer'image(sampleCnt); end if;
               assert sampleCnt = trigSize 
                  report "Channel " & integer'image(trigCh) & " has wrong number of samples. Expected " & integer'image(trigSize) & " received " & integer'image(sampleCnt)
                  severity failure;
               triggersGood(trigCh) <= triggersGood(trigCh) + 1;
            else
               trigRdVer  <= (others=>'0');
            end if;
         
         else
            trigRdVer  <= (others=>'0');
         end if;
         
      end loop;
      
   end process;
   
   
   ------------------------------------------------
   -- AXI interconnect
   ------------------------------------------------
   
   U_AxiIcWrapper : entity work.AxiIcWrapper
      port map (
         -- AXI Slaves for ADC channels
         -- 128 Bit Data Bus
         -- 1 burst packet FIFOs
         axiAdcClk            => adcClk,
         axiAdcWriteMasters   => axiAdcWriteMasters,
         axiAdcWriteSlaves    => axiAdcWriteSlaves,
         
         -- AXI Slave for data readout
         -- 32 Bit Data Bus
         axiDoutClk           => adcClk,
         axiDoutReadMaster    => axiDoutReadMaster,
         axiDoutReadSlave     => axiDoutReadSlave,
         
         -- AXI Slave for memory tester (aximClk domain)
         -- 512 Bit Data Bus
         axiBistReadMaster    => axiBistReadMaster,
         axiBistReadSlave     => axiBistReadSlave ,
         axiBistWriteMaster   => axiBistWriteMaster,
         axiBistWriteSlave    => axiBistWriteSlave,
         
         -- AXI Master
         -- 512 Bit Data Bus
         aximClk              => axiClk,
         aximRst              => axiRst,
         aximReadMaster       => axiReadMaster,
         aximReadSlave        => axiReadSlave,
         aximWriteMaster      => axiWriteMaster,
         aximWriteSlave       => axiWriteSlave
      );

   
   ------------------------------------------------
   -- DDR memory controller
   ------------------------------------------------
   U_DDR : entity work.MigCoreWrapper
      generic map (
         TPD_G => TPD_C)
      port map (
         -- AXI Slave
         axiClk           => axiClk,
         axiRst           => axiRst,
         axiReadMaster    => axiReadMaster,
         axiReadSlave     => axiReadSlave,
         axiWriteMaster   => axiWriteMaster,
         axiWriteSlave    => axiWriteSlave,
         -- DDR PHY Ref clk
         c0_sys_clk_p     => ddrClkP,
         c0_sys_clk_n     => ddrClkN,
         -- DRR Memory interface ports
         sys_rst          => rst,
         c0_ddr4_aresetn  => rstL,
         c0_ddr4_adr      => c0_ddr4_adr,
         c0_ddr4_ba       => c0_ddr4_ba,
         c0_ddr4_cke      => c0_ddr4_cke,
         c0_ddr4_cs_n     => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n,
         c0_ddr4_dq       => c0_ddr4_dq,
         c0_ddr4_dqs_c    => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t    => c0_ddr4_dqs_t,
         c0_ddr4_odt      => c0_ddr4_odt,
         c0_ddr4_bg       => c0_ddr4_bg,
         c0_ddr4_reset_n  => c0_ddr4_reset_n,
         c0_ddr4_act_n    => c0_ddr4_act_n,
         c0_ddr4_ck_c     => c0_ddr4_ck_c,
         c0_ddr4_ck_t     => c0_ddr4_ck_t,
         calibComplete    => ddrCalDone);

   U_ddr4 : Ddr4ModelWrapper
      generic map (
         DDR_WIDTH_G => DDR_WIDTH_C)
      port map (
         c0_ddr4_adr      => c0_ddr4_adr,
         c0_ddr4_ba       => c0_ddr4_ba,
         c0_ddr4_cke      => c0_ddr4_cke,
         c0_ddr4_cs_n     => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n,
         c0_ddr4_dq       => c0_ddr4_dq,
         c0_ddr4_dqs_c    => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t    => c0_ddr4_dqs_t,
         c0_ddr4_odt      => c0_ddr4_odt,
         c0_ddr4_bg       => c0_ddr4_bg,
         c0_ddr4_reset_n  => c0_ddr4_reset_n,
         c0_ddr4_act_n    => c0_ddr4_act_n,
         c0_ddr4_ck_c     => c0_ddr4_ck_c,
         c0_ddr4_ck_t     => c0_ddr4_ck_t);
   
   
   ------------------------------------------------
   -- DDR memory tester
   ------------------------------------------------
   
   U_AxiMemTester : entity work.AxiMemTester
      generic map (
         TPD_G        => TPD_C,
         START_ADDR_G => START_ADDR_C,
         STOP_ADDR_G  => ite(SIM_SPEEDUP_C, toSlv(1*4096, AXI_CONFIG_C.ADDR_WIDTH_C), STOP_ADDR_C),
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         -- AXI-Lite Interface
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open,
         memReady        => passed,
         memError        => failed,
         -- DDR Memory Interface
         axiClk          => axiClk,
         axiRst          => axiRst,
         start           => ddrCalDone,
         axiWriteMaster  => axiBistWriteMaster,
         axiWriteSlave   => axiBistWriteSlave,
         axiReadMaster   => axiBistReadMaster,
         axiReadSlave    => axiBistReadSlave);
   
   process(clk)
      variable i : natural;
   begin
      if rising_edge(clk) then
         -- Check for reset
         if rst = '1' then
            passedDly <= (others => '0') after TPD_C;
            failedDly <= (others => '0') after TPD_C;
         else
            passedDly(0) <= passed after TPD_C;
            failedDly(0) <= failed after TPD_C;
            for i in DLY_C-2 downto 0 loop
               passedDly(i+1) <= passedDly(i) after TPD_C;
               failedDly(i+1) <= failedDly(i) after TPD_C;
            end loop;
         end if;
      end if;
   end process;

   process(failedDly, passedDly)
   begin
      if failedDly(DLY_C-1) = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
