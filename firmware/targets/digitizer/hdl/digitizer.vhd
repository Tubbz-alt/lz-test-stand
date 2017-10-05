-------------------------------------------------------------------------------
-- File       : digitizer.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-05
-------------------------------------------------------------------------------
-- Description: LZ Digitizer Target's Top Level
-------------------------------------------------------------------------------
-- This file is part of 'firmware-template'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'firmware-template', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiAds42lb69Pkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity digitizer is
   generic (
      TPD_G            : time            := 1 ns;
      BUILD_INFO_G     : BuildInfoType;
      SIM_SPEEDUP_G    : boolean         := false;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- System Ports
      leds             : out   slv(3 downto 0);
      pwrCtrlIn        : in    PwrCtrlInType;
      pwrCtrlOut       : out   PwrCtrlOutType;
      -- JESD ADC Ports
      devClkP          : in    sl;
      devClkN          : in    sl;
      sysRefClkP       : in    sl;
      sysRefClkN       : in    sl;
      lmkRefClkP       : out   sl;
      lmkRefClkN       : out   sl;
      jesdRxDa2P       : in    slv(3 downto 0);
      jesdRxDa2N       : in    slv(3 downto 0);
      jesdRxDa1P       : in    slv(3 downto 0);
      jesdRxDa1N       : in    slv(3 downto 0);
      jesdRxDb2P       : in    slv(3 downto 0);
      jesdRxDb2N       : in    slv(3 downto 0);
      jesdRxDb1P       : in    slv(3 downto 0);
      jesdRxDb1N       : in    slv(3 downto 0);
      jesdSync         : out   slv(3 downto 0);
      fadcPdn          : out   slv(3 downto 0);
      fadcReset        : out   slv(3 downto 0);
      fadcSen          : out   slv(3 downto 0);
      fadcSclk         : out   sl;
      fadcSdin         : out   sl;
      fadcSdout        : in    sl;
      lmkCs            : out   sl;
      lmkSck           : out   sl;
      lmkSdio          : inout sl;
      lmkReset         : out   sl;
      lmkSync          : out   sl;
      -- Parallel LVDS ADC Ports
      sadcSclk         : out   sl;
      sadcSDin         : in    sl;
      sadcSDout        : out   sl;
      sadcCsb          : out   slv(3 downto 0);
      sadcRst          : out   slv(3 downto 0);
      sadcCtrl1        : out   slv(3 downto 0);
      sadcCtrl2        : out   slv(3 downto 0);
      sampEn           : out   slv(3 downto 0);
      sadcClkFbP       : in    slv(3 downto 0);
      sadcClkFbN       : in    slv(3 downto 0);
      sadcDataP        : in    Slv16Array(3 downto 0);
      sadcDataN        : in    Slv16Array(3 downto 0);
      sadcClkP         : out   slv(3 downto 0);
      sadcClkN         : out   slv(3 downto 0);
      sadcSyncP        : out   slv(3 downto 0);
      sadcSyncN        : out   slv(3 downto 0);
      -- DRR Memory interface ports
      c0_sys_clk_p     : in    sl;
      c0_sys_clk_n     : in    sl;
      c0_ddr4_dq       : inout slv(DDR_WIDTH_C-1 downto 0);
      c0_ddr4_dqs_c    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_dqs_t    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_adr      : out   slv(16 downto 0);
      c0_ddr4_ba       : out   slv(1 downto 0);
      c0_ddr4_bg       : out   slv(0 to 0);
      c0_ddr4_reset_n  : out   sl;
      c0_ddr4_act_n    : out   sl;
      c0_ddr4_ck_t     : out   slv(0 to 0);
      c0_ddr4_ck_c     : out   slv(0 to 0);
      c0_ddr4_cke      : out   slv(0 to 0);
      c0_ddr4_cs_n     : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_odt      : out   slv(0 to 0);
      -- PGP Ports
      pgpClkP          : in    sl;
      pgpClkN          : in    sl;
      pgpRxP           : in    sl;
      pgpRxN           : in    sl;
      pgpTxP           : out   sl;
      pgpTxN           : out   sl;
      -- SYSMON Ports
      vPIn             : in    sl;
      vNIn             : in    sl);
end digitizer;

architecture top_level of digitizer is

   constant NUM_AXI_MASTERS_C : natural := 5;

   constant PWR_SYNC_INDEX_C    : natural := 1;
   constant COMM_INDEX_C        : natural := 2;
   constant SADC_PHY_INDEX_C    : natural := 3;
   constant SADC_BUFFER_INDEX_C : natural := 4;
   constant FADC_PHY_INDEX_C    : natural := 5;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS0_C, AXI_BASE_ADDR_G, 31, 24);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 1);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 1);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 1);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 1);

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilReadMaster  : AxiLiteReadMasterType;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal mbTxMaster   : AxiStreamMasterType;
   signal mbTxSlave    : AxiStreamSlaveType;
   signal dataTxMaster : AxiStreamMasterType;
   signal dataTxSlave  : AxiStreamSlaveType;

   signal adcData            : Slv16Array(7 downto 0);
   signal axiAdcWriteMasters : AxiWriteMasterArray(7 downto 0);
   signal axiAdcWriteSlaves  : AxiWriteSlaveArray(7 downto 0);
   signal axiDoutReadMaster  : AxiReadMasterType;
   signal axiDoutReadSlave   : AxiReadSlaveType;

   signal clk250    : sl;
   signal rst250    : sl;
   signal ddrRstN   : sl;
   signal writerRst : sl;

   signal swTrigger : sl;
   signal pwrLed    : slv(3 downto 0);
   signal gTime     : slv(63 downto 0);

   attribute keep           : string;
   attribute keep of clk250 : signal is "true";
   attribute keep of rst250 : signal is "true";

begin

   --------------------------------
   -- Temporary global time counter
   --------------------------------
   process(clk250)
   begin
      if rising_edge(clk250) then
         if rst250 = '1' then
            gTime <= (others => '0') after TPD_G;
         else
            gTime <= gTime + 1 after TPD_G;
         end if;
      end if;
   end process;

   -------------------
   -- User LED Mapping
   -------------------
   leds(3) <= not(writerRst);
   leds(2) <= pwrLed(2);
   leds(1) <= pwrLed(1);
   leds(0) <= pwrLed(0);

   -----------------------
   -- Communication Module
   -----------------------
   U_PGP : entity work.LzDigitizerPgpCore
      generic map (
         TPD_G            => TPD_G,
         SIM_SPEEDUP_G    => SIM_SPEEDUP_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- Clock and Reset
         axilClk          => axilClk,
         axilRst          => axilRst,
         -- Data Streaming Interface
         dataTxMaster     => dataTxMaster,
         dataTxSlave      => dataTxSlave,
         -- Microblaze Streaming Interface
         mbTxMaster       => mbTxMaster,
         mbTxSlave        => mbTxSlave,
         -- AXI-Lite Register Interface
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave,
         -- Debug AXI-Lite Interface         
         sAxilReadMaster  => axilReadMasters(COMM_INDEX_C),
         sAxilReadSlave   => axilReadSlaves(COMM_INDEX_C),
         sAxilWriteMaster => axilWriteMasters(COMM_INDEX_C),
         sAxilWriteSlave  => axilWriteSlaves(COMM_INDEX_C),
         -- Software trigger interface
         swClk            => clk250,
         swRst            => rst250,
         swTrigOut        => swTrigger,
         -- PGP Ports
         pgpClkP          => pgpClkP,
         pgpClkN          => pgpClkN,
         pgpRxP           => pgpRxP,
         pgpRxN           => pgpRxN,
         pgpTxP           => pgpTxP,
         pgpTxN           => pgpTxN);

   --------------
   -- System Core
   --------------
   U_Core : entity work.SystemCore
      generic map (
         TPD_G             => TPD_G,
         BUILD_INFO_G      => BUILD_INFO_G,
         NUM_AXI_MASTERS_G => NUM_AXI_MASTERS_C,
         AXI_CONFIG_G      => AXI_CONFIG_C,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G)
      port (
         -- Clock and Reset
         axilClk            => axilClk,
         axilRst            => axilRst,
         clk250             => clk250,
         rst250             => rst250,
         writerRst          => writerRst,
         -- DRR Memory interface ports
         c0_sys_clk_p       => c0_sys_clk_p,
         c0_sys_clk_n       => c0_sys_clk_n,
         c0_ddr4_dq         => c0_ddr4_dq,
         c0_ddr4_dqs_c      => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t      => c0_ddr4_dqs_t,
         c0_ddr4_adr        => c0_ddr4_adr,
         c0_ddr4_ba         => c0_ddr4_ba,
         c0_ddr4_bg         => c0_ddr4_bg,
         c0_ddr4_reset_n    => c0_ddr4_reset_n,
         c0_ddr4_act_n      => c0_ddr4_act_n,
         c0_ddr4_ck_t       => c0_ddr4_ck_t,
         c0_ddr4_ck_c       => c0_ddr4_ck_c,
         c0_ddr4_cke        => c0_ddr4_cke,
         c0_ddr4_cs_n       => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n   => c0_ddr4_dm_dbi_n,
         c0_ddr4_odt        => c0_ddr4_odt,
         -- ADC AXI Interface (clk250 domain)
         axiAdcWriteMasters => axiAdcWriteMasters,
         axiAdcWriteSlaves  => axiAdcWriteSlaves,
         -- MB Streaming Interface
         mbTxMaster         => mbTxMaster,
         mbTxSlave          => mbTxSlave,
         -- AXI-Lite Register Interface (axilClk domain)
         mAxilReadMaster    => axilReadMaster,
         mAxilReadSlave     => axilReadSlave,
         mAxilWriteMaster   => axilWriteMaster,
         mAxilWriteSlave    => axilWriteSlave,
         sAxilReadMasters   => axilReadMasters,
         sAxilReadSlaves    => axilReadSlaves,
         sAxilWriteMasters  => axilWriteMasters,
         sAxilWriteSlaves   => axilWriteSlaves,
         -- SYSMON Ports
         vPIn               => vPIn,
         vNIn               => vNIn);

   ----------------------
   -- Power Supply Module
   ----------------------
   U_PowerController : entity work.PowerController
      generic map (
         TPD_G => TPD_G)
      port map (
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilWriteMaster => axilWriteMasters(PWR_SYNC_INDEX_C),
         sAxilWriteSlave  => axilWriteSlaves(PWR_SYNC_INDEX_C),
         sAxilReadMaster  => axilReadMasters(PWR_SYNC_INDEX_C),
         sAxilReadSlave   => axilReadSlaves(PWR_SYNC_INDEX_C),
         leds             => pwrLed,
         pwrCtrlIn        => pwrCtrlIn,
         pwrCtrlOut       => pwrCtrlOut,
         sadcRst          => sadcRst,
         sadcCtrl1        => sadcCtrl1,
         sadcCtrl2        => sadcCtrl2,
         sampEn           => sampEn,
         fadcPdn          => fadcPdn,
         fadcReset        => fadcReset,
         ddrRstN          => ddrRstN);

   -----------------------
   -- 250 MSPS ADCs Buffer
   -----------------------
   U_SadcPhy : entity work.SadcPhy
      generic map (
         TPD_G            => TPD_G,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(SADC_PHY_INDEX_C).baseAddr,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port (
         -- Clocks and Resets
         axilClk         => axilClk,
         axilRst         => axilRst,
         adcClk          => clk250,
         adcRst          => rst250,
         refclk200MHz    => clk250,
         -- Parallel LVDS ADC Ports
         sadcSclk        => sadcSclk,
         sadcSDin        => sadcSDin,
         sadcSDout       => sadcSDout,
         sadcCsb         => sadcCsb,
         sadcRst         => sadcRst,
         sadcCtrl1       => sadcCtrl1,
         sadcCtrl2       => sadcCtrl2,
         sampEn          => sampEn,
         sadcClkFbP      => sadcClkFbP,
         sadcClkFbN      => sadcClkFbN,
         sadcDataP       => sadcDataP,
         sadcDataN       => sadcDataN,
         sadcClkP        => sadcClkP,
         sadcClkN        => sadcClkN,
         sadcSyncP       => sadcSyncP,
         sadcSyncN       => sadcSyncN,
         -- ADC Interface (adcClk domain)
         adcData         => adcData,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(SADC_BUFFER_INDEX_C),
         axilReadSlave   => axilReadSlaves(SADC_BUFFER_INDEX_C),
         axilWriteMaster => axilWriteMasters(SADC_BUFFER_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(SADC_BUFFER_INDEX_C));

   -----------------------
   -- 250 MSPS ADCs Buffer
   -----------------------
   U_SadcBuffer : entity work.SadcBuffer
      generic map (
         TPD_G            => TPD_G,
         ADDR_BITS_G      => ADDR_BITS_C,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(SADC_BUFFER_INDEX_C).baseAddr,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port (
         -- ADC interface
         adcClk          => clk250,
         adcRst          => writerRst,
         adcData         => adcData,
         gTime           => gTime,
         extTrigger      => swTrigger,
         -- AXI Interface (adcClk)
         axiWriteMaster  => axiAdcWriteMasters,
         axiWriteSlave   => axiAdcWriteSlaves,
         axiReadMaster   => axiDoutReadMaster,
         axiReadSlave    => axiDoutReadSlave,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(SADC_BUFFER_INDEX_C),
         axilReadSlave   => axilReadSlaves(SADC_BUFFER_INDEX_C),
         axilWriteMaster => axilWriteMasters(SADC_BUFFER_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(SADC_BUFFER_INDEX_C));

end top_level;
