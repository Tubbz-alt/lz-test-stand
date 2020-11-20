-------------------------------------------------------------------------------
-- File       : DebouncerTb.vhd
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

entity DebouncerTb is end DebouncerTb;

architecture testbed of DebouncerTb is
   

   signal clk        : sl := '0';
   signal rst        : sl := '1';
   signal i          : sl;
   signal o          : sl;
   


begin
   
   clk <= not clk after 5 ns;
   rst <= '0' after 20 ns;
   
   ------------------------------------------------
   -- UUT
   ------------------------------------------------
   
   UUT : entity work.Debouncer
   generic map (
      INPUT_POLARITY_G  => '0',
      OUTPUT_POLARITY_G => '1',
      --CLK_PERIOD_G      => 10.0E-9,   -- units of seconds
      CLK_FREQ_G        => 100.0E+6,   -- units of Hz
      DEBOUNCE_PERIOD_G => 10.0E-6,    -- units of seconds
      SYNCHRONIZE_G     => true
   )
   port map (
      clk => clk,
      rst => rst,
      i   => i,
      o   => o
   );
   
   -----------------------------------------------------------------------
   -- stimuli
   -----------------------------------------------------------------------
   process
   begin
      i <= '0';
      
      wait for 10 us;
      
      
      -- bounce and change the input state
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      
      wait for 100 us;
      
      
      -- bounce and change the input state
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      i <= not i;
      wait for 20 ns;
      
      
      wait for 100 us;
      
      
      report "Simulation done" severity failure;
      
      
   end process;

end testbed;
