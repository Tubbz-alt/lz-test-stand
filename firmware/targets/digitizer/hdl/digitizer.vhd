-------------------------------------------------------------------------------
-- File       : digitizer.vhd
-- Created    : 2017-06-09
-- Last update: 2017-10-13
-------------------------------------------------------------------------------
-- Description: LZ Digitizer Target's Top Level
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
      -- Inter board synchronization
      clkInP           : in    sl;
      clkInN           : in    sl;
      clkOutP          : out   sl;
      clkOutN          : out   sl;
      cmdInP           : in    sl;
      cmdInN           : in    sl;
      cmdOutP          : out   sl;
      cmdOutN          : out   sl;
      ncInP            : in    slv(1 downto 0); -- unused
      ncInN            : in    slv(1 downto 0); -- unused
      ncOutP           : out   slv(1 downto 0); -- unused
      ncOutN           : out   slv(1 downto 0); -- unused
      -- JESD ADC Ports
      jesdClkP         : in    sl;
      jesdClkN         : in    sl;
      jesdSysRefP      : in    sl;
      jesdSysRefN      : in    sl;
      jesdRxP          : in    slv(15 downto 0);
      jesdRxN          : in    slv(15 downto 0);
      jesdTxP          : out   slv(15 downto 0);
      jesdTxN          : out   slv(15 downto 0);
      jesdSync         : out   slv(3 downto 0);
      -- Fast ADC SPI Ports
      fadcSclk         : out   sl;
      fadcSdin         : out   sl;
      fadcSdout        : in    sl;
      fadcSen          : out   slv(3 downto 0);
      fadcReset        : out   slv(3 downto 0);
      fadcPdn          : out   slv(3 downto 0);
      -- LMK Ports
      lmkRefClkP       : out   sl;
      lmkRefClkN       : out   sl;
      lmkCsL           : out   sl;
      lmkSck           : out   sl;
      lmkSdio          : inout sl;
      lmkRst           : out   sl;
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
      -- temperature sensors
      tmpScl           : inout sl;
      tmpSda           : inout sl;
      -- SYSMON Ports
      vPIn             : in    sl;
      vNIn             : in    sl);
end digitizer;

architecture top_level of digitizer is

   constant NUM_AXI_MASTERS_C : natural := 8;

   constant PWR_SYNC_INDEX_C    : natural := 1;
   constant COMM_INDEX_C        : natural := 2;
   constant SADC_PHY_INDEX_C    : natural := 3;
   constant SADC_BUFFER_INDEX_C : natural := 4;
   constant FADC_PHY_INDEX_C    : natural := 5;
   constant FADC_BUFFER_INDEX_C : natural := 6;
   constant PACKET_INDEX_C      : natural := 7;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"00000000", 31, 24);

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

   signal prbsTxMaster  : AxiStreamMasterType;
   signal prbsTxSlave   : AxiStreamSlaveType;
   signal axisMuxMaster : AxiStreamMasterType;
   signal axisMuxSlave  : AxiStreamSlaveType;
   signal dataTxMaster  : AxiStreamMasterType;
   signal dataTxSlave   : AxiStreamSlaveType;
   signal axisMasters   : AxiStreamMasterArray(1 downto 0);
   signal axisSlaves    : AxiStreamSlaveArray(1 downto 0);

   signal sAdcData           : Slv16Array(7 downto 0);
   signal axiAdcWriteMasters : AxiWriteMasterArray(7 downto 0);
   signal axiAdcWriteSlaves  : AxiWriteSlaveArray(7 downto 0);
   signal axiDoutReadMaster  : AxiReadMasterType;
   signal axiDoutReadSlave   : AxiReadSlaveType;

   signal fAdcValid : slv(7 downto 0);
   signal fAdcData  : Slv64Array(7 downto 0);

   signal adcClk     : sl;
   signal adcRst     : sl;
   signal ddrRstN    : sl;
   signal ddrRstOut  : sl;
   signal bufferRst  : sl;
   signal lmkRefClk  : sl;
   signal sysRst     : sl;
   signal sysRstSync : sl;
   
   signal swTrigger : sl;
   signal swArmTrig : sl;
   signal syncCmd   : sl;
   signal rstCmd    : sl;
   signal pwrLed    : slv(3 downto 0);
   signal gTime     : slv(63 downto 0);
   signal dnaValue  : slv(127 downto 0);
   
   signal ncIn      : slv(1 downto 0);
   signal ncOut     : slv(1 downto 0);
   
   attribute keep : string;                        -- for chipscope
   attribute keep of adcClk : signal is "true";    -- for chipscope

begin

   -------------------
   -- User LED Mapping
   -------------------
   leds(3) <= not(bufferRst);
   
   -- unused RJ45 pairs
   GEN_VEC : for i in 1 downto 0 generate
      U_IBUFDS_1 : IBUFDS
      port map (
         I  => ncInP(i),
         IB => ncInN(i),
         O  => ncIn(i)
      );
      
      U_OBUFDS_1 : OBUFDS
      port map (
         I  => ncOut(i),
         OB => ncOutN(i),
         O  => ncOutP(i)
      );
      ncOut(i) <= ncIn(i) and '0';
   end generate GEN_VEC;

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
         -- PRBS Streaming Interface
         prbsTxMaster     => prbsTxMaster,
         prbsTxSlave      => prbsTxSlave,
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
         swClk            => adcClk,
         swRst            => adcRst,
         swTrigOut        => swTrigger,
         swArmOut         => swArmTrig,
         syncCmd          => syncCmd,
         rstCmd           => rstCmd,
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
      port map (
         -- Clock and Reset
         axilClk            => axilClk,
         axilRst            => axilRst,
         adcClk             => adcClk,
         adcRst             => adcRst,
         ddrRstN            => ddrRstN,
         ddrRstOut          => ddrRstOut,
         lmkRefClk          => lmkRefClk,
         -- Inter board synchronization
         gTime              => gTime,
         syncCmd            => syncCmd,
         rstCmd             => rstCmd,
         clkInP             => clkInP,
         clkInN             => clkInN,
         clkOutP            => clkOutP,
         clkOutN            => clkOutN,
         cmdInP             => cmdInP,
         cmdInN             => cmdInN,
         cmdOutP            => cmdOutP,
         cmdOutN            => cmdOutN,
         clkLed             => leds(2),
         cmdLed             => leds(1),
         mstLed             => leds(0),
         -- temperature sensors
         tmpScl             => tmpScl,
         tmpSda             => tmpSda,
         -- DNA output
         dnaValue           => dnaValue,
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
         axiDoutReadMaster  => axiDoutReadMaster,
         axiDoutReadSlave   => axiDoutReadSlave,
         -- PRBS Streaming Interface
         prbsTxMaster       => prbsTxMaster,
         prbsTxSlave        => prbsTxSlave,
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
   U_PwrCtrl : entity work.PowerController
      generic map (
         TPD_G => TPD_G)
      port map (
         axilClk          => axilClk,
         axilRst          => axilRst,
         sAxilWriteMaster => axilWriteMasters(PWR_SYNC_INDEX_C),
         sAxilWriteSlave  => axilWriteSlaves(PWR_SYNC_INDEX_C),
         sAxilReadMaster  => axilReadMasters(PWR_SYNC_INDEX_C),
         sAxilReadSlave   => axilReadSlaves(PWR_SYNC_INDEX_C),
         sysRst           => sysRst,
         leds             => pwrLed,
         pwrCtrlIn        => pwrCtrlIn,
         pwrCtrlOut       => pwrCtrlOut,
         sadcRst          => sadcRst,
         sadcCtrl1        => sadcCtrl1,
         sadcCtrl2        => sadcCtrl2,
         sampEn           => sampEn,
         ddrRstN          => ddrRstN);

   --------------------
   -- 250 MSPS ADCs PHY
   --------------------
   U_SadcPhy : entity work.SadcPhy
      generic map (
         TPD_G            => TPD_G,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(SADC_PHY_INDEX_C).baseAddr,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- Clocks and Resets
         axilClk         => axilClk,
         axilRst         => axilRst,
         adcClk          => adcClk,
         adcRst          => adcRst,
         refclk200MHz    => adcClk,     -- Should be 200 MHz???
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
         adcData         => sAdcData,
         -- AXI-Lite Interface (axilClk domain)
         axilReadMaster  => axilReadMasters(SADC_PHY_INDEX_C),
         axilReadSlave   => axilReadSlaves(SADC_PHY_INDEX_C),
         axilWriteMaster => axilWriteMasters(SADC_PHY_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(SADC_PHY_INDEX_C));

   -----------------------
   -- 250 MSPS ADCs Buffer
   -----------------------
   U_SadcBuffer : entity work.SadcBuffer
      generic map (
         TPD_G            => TPD_G,
         ADDR_BITS_G      => ADDR_BITS_C,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(SADC_BUFFER_INDEX_C).baseAddr,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- ADC interface
         adcClk          => adcClk,
         adcRst          => bufferRst,
         adcData         => sAdcData,
         gTime           => gTime,
         extTrigger      => swTrigger,
         -- AXI Interface (adcClk)
         axiWriteMaster  => axiAdcWriteMasters,
         axiWriteSlave   => axiAdcWriteSlaves,
         axiReadMaster   => axiDoutReadMaster,
         axiReadSlave    => axiDoutReadSlave,
         -- AxiStream output (axisClk domain)
         axisClk         => axilClk,
         axisRst         => axilRst,
         axisMaster      => axisMasters(0),
         axisSlave       => axisSlaves(0),
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(SADC_BUFFER_INDEX_C),
         axilReadSlave   => axilReadSlaves(SADC_BUFFER_INDEX_C),
         axilWriteMaster => axilWriteMasters(SADC_BUFFER_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(SADC_BUFFER_INDEX_C));

   ---------------------
   -- 1000 MSPS ADCs PHY
   ---------------------
   U_FadcPhy : entity work.FastAdcPhy
      generic map (
         TPD_G            => TPD_G,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(FADC_PHY_INDEX_C).baseAddr,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- JESD ADC Ports
         jesdClkP        => jesdClkP,
         jesdClkN        => jesdClkN,
         jesdSysRefP     => jesdSysRefP,
         jesdSysRefN     => jesdSysRefN,
         jesdRxP         => jesdRxP,
         jesdRxN         => jesdRxN,
         jesdTxP         => jesdTxP,
         jesdTxN         => jesdTxN,
         jesdSync        => jesdSync,
         -- Fast ADC SPI Ports
         fadcSclk        => fadcSclk,
         fadcSdin        => fadcSdin,
         fadcSdout       => fadcSdout,
         fadcSen         => fadcSen,
         fadcPdn         => fadcPdn,
         fadcReset       => fadcReset,
         -- LMK Ports
         lmkRefClk       => lmkRefClk,
         lmkRefClkP      => lmkRefClkP,
         lmkRefClkN      => lmkRefClkN,
         lmkCsL          => lmkCsL,
         lmkSck          => lmkSck,
         lmkSdio         => lmkSdio,
         lmkRst          => lmkRst,
         lmkSync         => lmkSync,
         -- JESD ADC Interface
         adcClk          => adcClk,
         adcRst          => adcRst,
         adcValid        => fAdcValid,
         adcData         => fAdcData,
         swTrigger       => swTrigger,
         swArmTrig       => swArmTrig,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(FADC_PHY_INDEX_C),
         axilReadSlave   => axilReadSlaves(FADC_PHY_INDEX_C),
         axilWriteMaster => axilWriteMasters(FADC_PHY_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(FADC_PHY_INDEX_C));

   ------------------------
   -- 1000 MSPS ADCs Buffer
   ------------------------
   U_FadcBuffer : entity work.FadcBuffer
      generic map (
         TPD_G            => TPD_G,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(FADC_BUFFER_INDEX_C).baseAddr,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         TRIG_ADDR_G    => TRIG_ADDR_C,
         BUFF_ADDR_G    => BUFF_ADDR_C)
      port map (
         -- ADC interface
         adcClk          => adcClk,
         adcRst          => bufferRst,
         adcValid        => fAdcValid,
         adcData         => fAdcData,
         gTime           => gTime,
         extTrigger      => swTrigger,
         -- AXI-Lite Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(FADC_BUFFER_INDEX_C),
         axilReadSlave   => axilReadSlaves(FADC_BUFFER_INDEX_C),
         axilWriteMaster => axilWriteMasters(FADC_BUFFER_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(FADC_BUFFER_INDEX_C),
         axisClk         => axilClk,
         axisRst         => axilRst,
         axisMaster      => axisMasters(1),
         axisSlave       => axisSlaves(1)
         );

   
   --------------
   -- Buffer reset
   --------------
   U_RstSync: entity work.Synchronizer
   port map (
      clk      => adcClk,
      rst      => adcRst,
      dataIn   => sysRst,
      dataOut  => sysRstSync
   );
   bufferRst <= ddrRstOut or sysRstSync;
   
   --------------------------
   ---- 1000 MSPS and 250 MSPS data stream mux
   --------------------------
   U_AxiStreamMux : entity work.AxiStreamMux
      generic map(
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 2,
         PIPE_STAGES_G => 1)
      port map(
         axisClk      => axilClk,
         axisRst      => axilRst,
         sAxisMasters => axisMasters,
         sAxisSlaves  => axisSlaves,
         mAxisMaster  => axisMuxMaster,
         mAxisSlave   => axisMuxSlave);
   
   U_FadcPacketizer: entity work.FadcPacketizer
   port map (
      -- AXI-Lite Interface for local registers 
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => axilReadMasters(PACKET_INDEX_C),
      axilReadSlave     => axilReadSlaves(PACKET_INDEX_C),
      axilWriteMaster   => axilWriteMasters(PACKET_INDEX_C),
      axilWriteSlave    => axilWriteSlaves(PACKET_INDEX_C),
      -- AxiStream interface (axisClk domain)
      axisClk           => axilClk,
      axisRst           => axilRst,
      axisRxMaster      => axisMuxMaster,
      axisRxSlave       => axisMuxSlave,
      axisTxMaster      => dataTxMaster,
      axisTxSlave       => dataTxSlave,
      -- Device DNA input
      dnaValue          => dnaValue
   );

end top_level;
