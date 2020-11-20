-------------------------------------------------------------------------------
-- File       : AxiAds42lb69CoreTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-08-27
-- Last update: 2016-09-06
-------------------------------------------------------------------------------
-- Description: Testbench for design "AxiAds42lb69Core"
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiAds42lb69Pkg.all;

----------------------------------------------------------------------------------------------------

entity AxiAds42lb69CoreTb is

end entity AxiAds42lb69CoreTb;

----------------------------------------------------------------------------------------------------

architecture sim of AxiAds42lb69CoreTb is
   
   
   signal adcSync        : sl;
   signal adcData        : Slv16Array(1 downto 0);
   signal axiReadMaster  : AxiLiteReadMasterType;
   signal axiReadSlave   : AxiLiteReadSlaveType;
   signal axiWriteMaster : AxiLiteWriteMasterType;
   signal axiWriteSlave  : AxiLiteWriteSlaveType;
   signal axilClk        : sl := '0';
   signal axilRst        : sl := '1';
   signal clk250         : sl := '0';
   signal rst250         : sl := '1';
   signal refclk200MHz   : sl;
   
   signal sadcClkFbP        : sl := '0';
   signal sadcClkFbN        : sl;
   signal sadcDataP         : slv(15 downto 0) := (others=>'0');
   signal sadcDataN         : slv(15 downto 0);
   signal sadcClkP          : sl;
   signal sadcClkN          : sl;
   signal sadcSyncP         : sl;
   signal sadcSyncN         : sl;

begin

   -- component instantiation
   UUT : entity work.AxiAds42lb69Core
   generic map (
      XIL_DEVICE_G   => "ULTRASCALE",
      SIM_SPEEDUP_G  => true
   )
   port map (
      -- ADC Ports
      adcIn.clkFbP   => sadcClkFbP,
      adcIn.clkFbN   => sadcClkFbN,
      adcIn.dataP(0) => sadcDataP( 7 downto 0),
      adcIn.dataP(1) => sadcDataP(15 downto 8),
      adcIn.dataN(0) => sadcDataN( 7 downto 0),
      adcIn.dataN(1) => sadcDataN(15 downto 8),
      adcOut.clkP    => sadcClkP,
      adcOut.clkN    => sadcClkN,
      adcOut.syncP   => sadcSyncP,
      adcOut.syncN   => sadcSyncN,
      -- ADC signals (adcClk domain)
      adcSync        => adcSync,
      adcData        => adcData,
      -- AXI-Lite Register Interface (axiClk domain)
      axiReadMaster  => axiReadMaster ,
      axiReadSlave   => axiReadSlave  ,
      axiWriteMaster => axiWriteMaster,
      axiWriteSlave  => axiWriteSlave ,
      -- Clocks and Resets
      axiClk         => axilClk,
      axiRst         => axilRst,
      adcClk         => clk250,
      adcRst         => rst250,
      refclk200MHz   => clk250
   );

   -- clock generation
   axilClk <= not axilClk after 10 ns;
   clk250  <= not clk250 after 2 ns;
   sadcClkFbP <= not sadcClkFbP after 2 ns;
   sadcClkFbN <= not sadcClkFbP;
   sadcDataP <= not sadcDataP after 4 ns;
   sadcDataN <= not sadcDataP;
   refclk200MHz <= clk250;
   -- reset generation
   axilRst <= '0' after 80 ns;
   rst250 <= '0' after 80 ns; 
   
   

   -- waveform generation
   WaveGen_Proc : process
      variable axilRdata         : slv(31 downto 0);
   begin
      adcSync <= '0';
      --sadcDataP <= (others=>'0');
      --sadcDataN <= (others=>'1');
      
      wait for 100 us;
      
      axiLiteBusSimWrite(axilClk, axiWriteMaster, axiWriteSlave, x"00000200", x"FF", true);
      axiLiteBusSimWrite(axilClk, axiWriteMaster, axiWriteSlave, x"00000204", x"04", true);
      axiLiteBusSimWrite(axilClk, axiWriteMaster, axiWriteSlave, x"00000208", x"05", true);
      axiLiteBusSimRead(axilClk, axiReadMaster, axiReadSlave, x"00000200", axilRdata, true);
      axiLiteBusSimRead(axilClk, axiReadMaster, axiReadSlave, x"00000204", axilRdata, true);
      axiLiteBusSimRead(axilClk, axiReadMaster, axiReadSlave, x"00000208", axilRdata, true);
      
      --loop
      --
      --   wait for 100 us;
      --   
      --   wait until falling_edge(sroAck);
      --   
      --
      --end loop;
      
      
      wait;
      
   end process WaveGen_Proc;

   

end architecture sim;

