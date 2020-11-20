-------------------------------------------------------------------------------
-- File       : AdcPatternTesterTb.vhd
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

library unisim;
use unisim.vcomponents.all;

entity AdcPatternTesterTb is end AdcPatternTesterTb;

architecture testbed of AdcPatternTesterTb is

   signal axilClk : sl:='1';
   signal axilRst : sl:='1';
   signal adcClk  : sl:='1';
   signal adcRst  : sl:='1';
   
   signal axilWriteMaster   : AxiLiteWriteMasterType;
   signal axilWriteSlave    : AxiLiteWriteSlaveType;
   signal axilReadMaster    : AxiLiteReadMasterType;
   signal axilReadSlave     : AxiLiteReadSlaveType;
   signal adcData           : Slv32Array(7 downto 0);
   signal testDone          : sl;
   signal testFailed        : sl;

begin
   
   -- generate clocks and reset
   axilClk <= not axilClk after 3.2 ns;   -- 156.25 MHz (PGP) clock
   axilRst <= '0' after 100 ns;
   adcClk <= not adcClk after 2 ns;       -- 250 MHz ADC clock
   adcRst <= '0' after 100 ns;
   
   ------------------------------------------------
   -- UUT
   ------------------------------------------------
   U_AdcPatternTester : entity work.AdcPatternTester
   port map ( 
      adcClk            => adcClk  ,
      adcRst            => adcRst  ,
      adcData           => adcData ,
      axilClk           => axilClk        ,
      axilRst           => axilRst        ,
      axilWriteMaster   => axilWriteMaster,
      axilWriteSlave    => axilWriteSlave ,
      axilReadMaster    => axilReadMaster ,
      axilReadSlave     => axilReadSlave  ,
      testDone          => testDone,
      testFailed        => testFailed
   );
   
   
   
   -----------------------------------------------------------------------
   -- Test process
   -----------------------------------------------------------------------
   process
   begin
   
      adcData     <= (others=>x"00001001");
      adcData(1)  <= x"00001002";
      
      wait for 1 us;
      
      -- initial setup
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000004", x"EFFF", true); -- mask
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000008", x"0001", true); -- pattern
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"0000000C", x"00FF", true); -- samples count
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0001", true); -- trigger test

      wait until testDone = '1';
      
      -- restart test
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0000", true); 
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0001", true); 
      
      wait until testDone = '1';
      
      adcData(0) <= x"00000010";
      
      -- restart test
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0000", true); 
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0001", true); 
      
      wait until testDone = '1';
      
      adcData(0) <= x"00000001";
      
      -- restart test
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0000", true); 
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0001", true); 
      
      wait for 100 ns;
      adcData(0) <= x"00000100";
      
      wait until testDone = '1';
      
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000000", x"0001", true); -- channel
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000008", x"0001", true); -- pattern
      -- restart test
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0000", true); 
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0001", true); 
      
      wait until testDone = '1';
      
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000008", x"0002", true); -- pattern
      -- restart test
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0000", true); 
      axiLiteBusSimWrite(axilClk, axilWriteMaster, axilWriteSlave, x"00000010", x"0001", true); 
      
      wait until testDone = '1';
      
      wait for 1 us;
      
      report "Simulation done" severity failure;
      
   end process;

end testbed;
