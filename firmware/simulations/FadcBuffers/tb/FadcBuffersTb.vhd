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

   
   constant CLK_PERIOD_C  : time    := 5 ns;
   constant TPD_C         : time    := CLK_PERIOD_C/4;
   constant DLY_C         : natural := 16;
   constant SIM_SPEEDUP_C : boolean := true;
   
   constant ADC_DATA_TOP_C : slv(15 downto 0) := toSlv(65000,16);
   constant ADC_DATA_BOT_C : slv(15 downto 0) := toSlv(100,16);
   
   
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
      CHANNEL_G         => x"03",
      PGP_LANE_G        => "0010",
      PGP_VC_G          => "0001"
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
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000004", x"200", false); -- size
      

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

end testbed;
