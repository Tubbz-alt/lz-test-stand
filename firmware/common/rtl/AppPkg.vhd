-------------------------------------------------------------------------------
-- File       : AppPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-05
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

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.I2cPkg.all;

package AppPkg is

   constant I2C_TEMP_CONFIG_C : I2cAxiLiteDevArray(3 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("1001000", 8, 8, '0')),
      1 => (MakeI2cAxiLiteDevType("1001001", 8, 8, '0')),
      2 => (MakeI2cAxiLiteDevType("1001011", 8, 8, '0')),
      3 => (MakeI2cAxiLiteDevType("1001111", 8, 8, '0'))
   );
   
   
   constant DDR_WIDTH_C : positive := 32;
   constant DDR_AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 30,
      DATA_BYTES_C => DDR_WIDTH_C,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');
   
   -- address space of the slow ADC single channel
   constant ADDR_BITS_C : integer := 27;
   
   -- buffer size of the fast ADC single channel
   -- 4 samples per address 2**8x4 = 1024 samples = 1us max buffer
   constant TRIG_ADDR_C  : integer := 8;
   -- 2**3 = 8 buffers per channel
   constant BUFF_ADDR_C  : integer := 3;
   
   constant JESD_LANE_C : integer := 16;

   type PwrCtrlInType is record
      -- power OK ins
      pokDcDcDp6V     : sl;
      pokDcDcAp6V     : sl;
      pokDcDcAm6V     : sl;
      pokDcDcAp5V4    : sl;
      pokDcDcAp3V7    : sl;
      pokDcDcAp2V3    : sl;
      pokDcDcAp1V6    : sl;
      pokLdoA0p1V8    : sl;
      pokLdoA0p3V3    : sl;
      pokLdoAd1p1V2   : sl;
      pokLdoAd2p1V2   : sl;
      pokLdoA1p1V9    : sl;
      pokLdoA2p1V9    : sl;
      pokLdoAd1p1V9   : sl;
      pokLdoAd2p1V9   : sl;
      pokLdoA1p3V3    : sl;
      pokLdoA2p3V3    : sl;
      pokLdoAvclkp3V3 : sl;
      pokLdoA0p5V0    : sl;
      pokLdoA1p5V0    : sl;
   end record;

   type PwrCtrlOutType is record
      -- power enable outs
      enDcDcAm6V     : sl;
      enDcDcAp5V4    : sl;
      enDcDcAp3V7    : sl;
      enDcDcAp2V3    : sl;
      enDcDcAp1V6    : sl;
      enLdoSlow      : sl;
      enLdoFast      : sl;
      enLdoAm5V      : sl;
      -- DCDC sync outputs
      syncDcDcDp6V   : sl;
      syncDcDcAp6V   : sl;
      syncDcDcAm6V   : sl;
      syncDcDcAp5V4  : sl;
      syncDcDcAp3V7  : sl;
      syncDcDcAp2V3  : sl;
      syncDcDcAp1V6  : sl;
      syncDcDcDp3V3  : sl;
      syncDcDcDp1V8  : sl;
      syncDcDcDp1V2  : sl;
      syncDcDcDp0V95 : sl;
      syncDcDcMgt1V0 : sl;
      syncDcDcMgt1V2 : sl;
      syncDcDcMgt1V8 : sl;
   end record;

end package AppPkg;
