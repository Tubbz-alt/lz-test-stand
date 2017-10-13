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
   
   
   signal adcData       : slv(63 downto 0);
   
   signal extTrigger    : sl;
   
   signal gTime         : slv(63 downto 0);
   
   signal axilClk       : sl := '0';
   signal axilRst       : sl := '1';
   signal axisClk       : sl := '0';
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
   axilClk <= not axisClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axilRst <= '0' after 100 ns;
   axisClk <= not axisClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axisRst <= '0' after 100 ns;
   adcClk <= not adcClk after 2 ns;       -- 250 MHz ADC clock
   adcRst <= '0' after 100 ns;
   
   axisSlave.tReady  <= '1';
   
   ------------------------------------------------
   -- Fast ADC Buffer UUT
   ------------------------------------------------
   UUT: entity work.FastAdcBufferChannel
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
   -- ADC data is a full swing saw signal
   process(adcClk)
   variable adcSample0 : slv(15 downto 0) := x"0000";
   variable adcSample1 : slv(15 downto 0) := x"0001";
   variable adcSample2 : slv(15 downto 0) := x"0002";
   variable adcSample3 : slv(15 downto 0) := x"0003";
   begin
      if rising_edge(adcClk) then
         if adcRst = '1' then
            adcData        <= (others => '0')   after TPD_C;
            adcSample0     := x"0000";
            adcSample1     := x"0001";
            adcSample2     := x"0002";
            adcSample3     := x"0003";
            gTime          <= (others => '0')   after TPD_C;
         else
            adcData        <= adcSample3 & adcSample2 & adcSample1 & adcSample0 after TPD_C;
            adcSample0     := adcSample0 + 4;
            adcSample1     := adcSample1 + 4;
            adcSample2     := adcSample2 + 4;
            adcSample3     := adcSample3 + 4;
            gTime          <= gTime + 1 after TPD_C;
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
