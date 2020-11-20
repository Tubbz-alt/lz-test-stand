-------------------------------------------------------------------------------
-- File       : LztsSynchronizerTb.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-05
-- Last update: 2017-07-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for LztsSynchronizer
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

library unisim;
use unisim.vcomponents.all;

entity LztsSynchronizerTb is end LztsSynchronizerTb;

architecture testbed of LztsSynchronizerTb is

   signal axilClk : sl:='1';
   signal axilRst : sl:='1';
   signal locClk  : sl:='1';
   
   signal axilWriteMaster   : AxiLiteWriteMasterType;
   signal axilWriteSlave    : AxiLiteWriteSlaveType;
   signal axilReadMaster    : AxiLiteReadMasterType;
   signal axilReadSlave     : AxiLiteReadSlaveType;
   signal syncCmd    : sl;
   signal rstCmd     : sl;
   signal cmdOutP    : sl;
   signal cmdOutN    : sl;
   signal clkOutP    : sl;
   signal clkOutN    : sl;
   signal clkOutM    : sl;
   signal rstOutM    : sl;
   signal gTimeM     : slv(63 downto 0);
   signal clkLedM    : sl;
   signal cmdLedM   : sl;
   signal mstLedM    : sl;
   
   signal clkOutS    : sl;
   signal rstOutS    : sl;
   signal gTimeS     : slv(63 downto 0);
   signal clkLedS    : sl;
   signal cmdLedS   : sl;
   signal mstLedS    : sl;

begin
   
   -- generate clocks and reset
   axilClk <= not axilClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axilRst <= '0' after 100 ns;
   locClk <= not locClk after 2 ns;       -- 250 MHz local clock
   
   ------------------------------------------------
   -- UUT
   ------------------------------------------------
   UUT_Master : entity work.LztsSynchronizer
   generic map (
      SIM_SPEEDUP_G     => true
   )
   port map (
      -- AXI-Lite Interface for local registers 
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => AXI_LITE_READ_MASTER_INIT_C,
      axilReadSlave     => open,
      axilWriteMaster   => AXI_LITE_WRITE_MASTER_INIT_C,
      axilWriteSlave    => open,
      -- local clock input/output
      locClk            => locClk,
      -- Master command inputs (synchronous to clkOut)
      syncCmd           => syncCmd,
      rstCmd            => rstCmd,
      -- Inter-board clock and command
      clkInP            => '0',
      clkInN            => '1',
      clkOutP           => clkOutP,
      clkOutN           => clkOutN,
      cmdInP            => '0',
      cmdInN            => '1',
      cmdOutP           => cmdOutP,
      cmdOutN           => cmdOutN,
      -- globally synchronized outputs
      clkOut            => clkOutM,
      rstOut            => rstOutM,
      gTime             => gTimeM,
      -- status LEDs
      clkLed            => clkLedM,
      cmdLed            => cmdLedM,
      mstLed            => mstLedM
   );
   
   UUT_Slave : entity work.LztsSynchronizer
   generic map (
      SIM_SPEEDUP_G     => true
   )
   port map (
      -- AXI-Lite Interface for local registers 
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => axilReadMaster,
      axilReadSlave     => axilReadSlave,
      axilWriteMaster   => axilWriteMaster,
      axilWriteSlave    => axilWriteSlave,
      -- local clock input/output
      locClk            => locClk,
      -- Master command inputs (synchronous to clkOut)
      syncCmd           => syncCmd,
      rstCmd            => rstCmd,
      -- Inter-board clock and command
      clkInP            => clkOutP,
      clkInN            => clkOutN,
      clkOutP           => open,
      clkOutN           => open,
      cmdInP            => cmdOutP,
      cmdInN            => cmdOutN,
      cmdOutP           => open,
      cmdOutN           => open,
      -- globally synchronized outputs
      clkOut            => clkOutS,
      rstOut            => rstOutS,
      gTime             => gTimeS,
      -- status LEDs
      clkLed            => clkLedS,
      cmdLed            => cmdLedS,
      mstLed            => mstLedS
   );
   
   -----------------------------------------------------------------------
   -- Test process
   -----------------------------------------------------------------------
   process
   begin
      
      
      syncCmd <= '0';
      rstCmd <= '0';
      
      wait for 100 us;
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000000", x"01", false);  -- set as slave device (master by default)
      
      wait for 100 us;
      
      wait until falling_edge(clkOutM);
      syncCmd <= '1';
      wait until falling_edge(clkOutM);
      syncCmd <= '0';
      
      wait for 100 us;
      
      wait until falling_edge(clkOutM);
      rstCmd <= '1';
      syncCmd <= '1';
      wait until falling_edge(clkOutM);
      rstCmd <= '0';
      syncCmd <= '0';
      
      wait for 100 us;
      
      report "Simulation done" severity failure;
      
   end process;

end testbed;
