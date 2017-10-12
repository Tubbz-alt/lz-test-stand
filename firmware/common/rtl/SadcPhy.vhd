-------------------------------------------------------------------------------
-- File       : SadcPhy.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-04
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity SadcPhy is
   generic (
      TPD_G            : time             := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C;
      AXI_BASE_ADDR_G  : slv(31 downto 0) := (others => '0'));
   port (
      -- Clocks and Resets
      axilClk         : in  sl;
      axilRst         : in  sl;
      adcClk          : in  sl;
      adcRst          : in  sl;
      refclk200MHz    : in  sl;
      -- Parallel LVDS ADC Ports
      sadcSclk        : out sl;
      sadcSDin        : in  sl;
      sadcSDout       : out sl;
      sadcCsb         : out slv(3 downto 0);
      sadcRst         : out slv(3 downto 0);
      sadcCtrl1       : out slv(3 downto 0);
      sadcCtrl2       : out slv(3 downto 0);
      sampEn          : out slv(3 downto 0);
      sadcClkFbP      : in  slv(3 downto 0);
      sadcClkFbN      : in  slv(3 downto 0);
      sadcDataP       : in  Slv16Array(3 downto 0);
      sadcDataN       : in  Slv16Array(3 downto 0);
      sadcClkP        : out slv(3 downto 0);
      sadcClkN        : out slv(3 downto 0);
      sadcSyncP       : out slv(3 downto 0);
      sadcSyncN       : out slv(3 downto 0);
      -- ADC Interface (adcClk domain)
      adcData         : out Slv16Array(7 downto 0);
      -- AXI-Lite Interface (axilClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end SadcPhy;

architecture mapping of SadcPhy is

   constant NUM_AXI_MASTERS_C : natural := 5;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

begin

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ------------------------
   -- 250 MSPS ADCs readout
   ------------------------
   GEN_VEC : for i in 3 downto 0 generate

      U_Phy : entity work.AxiAds42lb69Core
         generic map (
            TPD_G        => TPD_G,
            XIL_DEVICE_G => "ULTRASCALE")
         port map (
            -- ADC Ports
            adcIn.clkFbP   => sadcClkFbP(i),
            adcIn.clkFbN   => sadcClkFbN(i),
            adcIn.dataP(0) => sadcDataP(i)(7 downto 0),
            adcIn.dataP(1) => sadcDataP(i)(15 downto 8),
            adcIn.dataN(0) => sadcDataN(i)(7 downto 0),
            adcIn.dataN(1) => sadcDataN(i)(15 downto 8),
            adcOut.clkP    => sadcClkP(i),
            adcOut.clkN    => sadcClkN(i),
            adcOut.syncP   => sadcSyncP(i),
            adcOut.syncN   => sadcSyncN(i),
            -- ADC signals (adcClk domain)
            adcSync        => '1',
            adcData        => adcData(i*2+1 downto i*2),
            -- AXI-Lite Register Interface (axiClk domain)
            axiReadMaster  => axilReadMasters(i),
            axiReadSlave   => axilReadSlaves(i),
            axiWriteMaster => axilWriteMasters(i),
            axiWriteSlave  => axilWriteSlaves(i),
            -- Clocks and Resets
            axiClk         => axilClk,
            axiRst         => axilRst,
            adcClk         => adcClk,
            adcRst         => adcRst,
            refclk200MHz   => refclk200MHz);

   end generate GEN_VEC;

   ----------------------------------
   -- 250 MSPS ADCs configuration SPI
   ----------------------------------
   U_Spi : entity work.AxiSpiMaster
      generic map (
         TPD_G             => TPD_G,
         ADDRESS_SIZE_G    => 7,
         DATA_SIZE_G       => 8,
         CLK_PERIOD_G      => 6.4E-9,
         SPI_SCLK_PERIOD_G => 1.0E-6,
         SPI_NUM_CHIPS_G   => 4)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMasters(4),
         axiReadSlave   => axilReadSlaves(4),
         axiWriteMaster => axilWriteMasters(4),
         axiWriteSlave  => axilWriteSlaves(4),
         coreSclk       => sadcSclk,
         coreSDin       => sadcSDin,
         coreSDout      => sadcSDout,
         coreMCsb       => sadcCsb);

end mapping;
