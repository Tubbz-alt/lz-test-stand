-------------------------------------------------------------------------------
-- File       : digitizer.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-04-26
-------------------------------------------------------------------------------
-- Description: LZ Digitizer Target's Top Level
-- 
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

library unisim;
use unisim.vcomponents.all;

entity digitizer is
   generic (
      TPD_G            : time            := 1 ns;
      SIM_SPEEDUP_G    : boolean         := false;
      BUILD_INFO_G     : BuildInfoType;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C
   );
   port (
      -- LEDs
      leds              : out slv(3 downto 0);
      -- power enable outs
      enDcDcAm6V        : out sl;
      enDcDcAp5V4       : out sl;
      enDcDcAp3V7       : out sl;
      enDcDcAp2V3       : out sl;
      enDcDcAp1V6       : out sl;
      enLdoSlow         : out sl;
      enLdoFast         : out sl;
      enLdoAm5V         : out sl;
      -- DCDC sync outputs
      syncDcDcDp6V      : out sl;
      syncDcDcAp6V      : out sl;
      syncDcDcAm6V      : out sl;
      syncDcDcAp5V4     : out sl;
      syncDcDcAp3V7     : out sl;
      syncDcDcAp2V3     : out sl;
      syncDcDcAp1V6     : out sl;
      syncDcDcDp3V3     : out sl;
      syncDcDcDp1V8     : out sl;
      syncDcDcDp1V2     : out sl;
      syncDcDcDp0V95    : out sl;
      syncDcDcMgt1V0    : out sl;
      syncDcDcMgt1V2    : out sl;
      syncDcDcMgt1V8    : out sl;
      -- power OK ins
      pokDcDcDp6V       : in  sl;
      pokDcDcAp6V       : in  sl;
      pokDcDcAm6V       : in  sl;
      pokDcDcAp5V4      : in  sl;
      pokDcDcAp3V7      : in  sl;
      pokDcDcAp2V3      : in  sl;
      pokDcDcAp1V6      : in  sl;
      pokLdoA0p1V8      : in  sl;
      pokLdoA0p3V3      : in  sl;
      pokLdoAd1p1V2     : in  sl;
      pokLdoAd2p1V2     : in  sl;
      pokLdoA1p1V9      : in  sl;
      pokLdoA2p1V9      : in  sl;
      pokLdoAd1p1V9     : in  sl;
      pokLdoAd2p1V9     : in  sl;
      pokLdoA1p3V3      : in  sl;
      pokLdoA2p3V3      : in  sl;
      pokLdoAvclkp3V3   : in  sl;
      pokLdoA0p5V0      : in  sl;
      pokLdoA1p5V0      : in  sl;
      
      -- fast ADC pins
      devClkP           : in  sl;
      devClkN           : in  sl;
      sysRefClkP        : in  sl;
      sysRefClkN        : in  sl;
      lmkRefClkP        : out sl;
      lmkRefClkN        : out sl;
      
      jesdRxDa2P        : in  slv(3 downto 0);
      jesdRxDa2N        : in  slv(3 downto 0);
      jesdRxDa1P        : in  slv(3 downto 0);
      jesdRxDa1N        : in  slv(3 downto 0);
      jesdRxDb2P        : in  slv(3 downto 0);
      jesdRxDb2N        : in  slv(3 downto 0);
      jesdRxDb1P        : in  slv(3 downto 0);
      jesdRxDb1N        : in  slv(3 downto 0);
      
      jesdSync          : out slv(3 downto 0);
      
      fadcPdn           : out slv(3 downto 0);
      fadcReset         : out slv(3 downto 0);
      fadcSen           : out slv(3 downto 0);
      fadcSclk          : out sl;
      fadcSdin          : out sl;
      fadcSdout         : in  sl;
      
      lmkCs             : out   sl;
      lmkSck            : out   sl;
      lmkSdio           : inout sl;
      lmkReset          : out   sl;
      lmkSync           : out   sl;
      
      -- slow ADC pins
      sadcSclk          : out sl;
      sadcSDin          : in  sl;
      sadcSDout         : out sl;
      sadcCsb           : out slv(3 downto 0);
      sadcRst           : out slv(3 downto 0);
      sadcCtrl1         : out slv(3 downto 0);
      sadcCtrl2         : out slv(3 downto 0);
      sampEn            : out slv(3 downto 0);
      
      sadcClkFbP        : in  slv(3 downto 0);
      sadcClkFbN        : in  slv(3 downto 0);
      sadcDataP         : in  Slv16Array(3 downto 0);
      sadcDataN         : in  Slv16Array(3 downto 0);
      sadcClkP          : out slv(3 downto 0);
      sadcClkN          : out slv(3 downto 0);
      sadcSyncP         : out slv(3 downto 0);
      sadcSyncN         : out slv(3 downto 0);
      
      -- DDR PHY Ref clk
      c0_sys_clk_p      : in    sl;
      c0_sys_clk_n      : in    sl;
      -- DRR Memory interface ports
      --c0_ddr4_dq        : inout slv(63 downto 0);
      --c0_ddr4_dqs_c     : inout slv(7 downto 0);
      --c0_ddr4_dqs_t     : inout slv(7 downto 0);
      c0_ddr4_dq        : inout slv(31 downto 0);
      c0_ddr4_dqs_c     : inout slv(3 downto 0);
      c0_ddr4_dqs_t     : inout slv(3 downto 0);
      c0_ddr4_adr       : out   slv(16 downto 0);
      c0_ddr4_ba        : out   slv(1 downto 0);
      c0_ddr4_bg        : out   slv(0 to 0);
      c0_ddr4_reset_n   : out   sl;
      c0_ddr4_act_n     : out   sl;
      c0_ddr4_ck_t      : out   slv(0 to 0);
      c0_ddr4_ck_c      : out   slv(0 to 0);
      c0_ddr4_cke       : out   slv(0 to 0);
      c0_ddr4_cs_n      : out   slv(0 to 0);
      --c0_ddr4_dm_dbi_n  : inout slv(7 downto 0);
      c0_ddr4_dm_dbi_n  : inout slv(3 downto 0);
      c0_ddr4_odt       : out   slv(0 to 0);
      -- PGP signals
      pgpClkP           : in    sl;
      pgpClkN           : in    sl;
      pgpRxP            : in    sl;
      pgpRxN            : in    sl;
      pgpTxP            : out   sl;
      pgpTxN            : out   sl;
      -- SYSMON Ports
      vPIn              : in    sl;
      vNIn              : in    sl
   );
end digitizer;

architecture top_level of digitizer is

   constant DDR_AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 30,
      DATA_BYTES_C => 32,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');

   constant NUM_AXI_MASTERS_C : natural := 23;

   constant VERSION_INDEX_C   : natural := 0;
   constant SYSMON_INDEX_C    : natural := 1;
   constant BOOT_MEM_INDEX_C  : natural := 2;
   constant DDR_MEM_INDEX_C   : natural := 3;
   constant COMM_INDEX_C      : natural := 4;
   constant POWER_INDEX_C     : natural := 5;
   constant SADCONF_INDEX_C   : natural := 6;
   constant SADCRD0_INDEX_C   : natural := 7;
   constant SADCRD1_INDEX_C   : natural := 8;
   constant SADCRD2_INDEX_C   : natural := 9;
   constant SADCRD3_INDEX_C   : natural := 10;
   constant SADCWR0_INDEX_C   : natural := 11;
   constant SADCWR1_INDEX_C   : natural := 12;
   constant SADCWR2_INDEX_C   : natural := 13;
   constant SADCWR3_INDEX_C   : natural := 14;
   constant SADCWR4_INDEX_C   : natural := 15;
   constant SADCWR5_INDEX_C   : natural := 16;
   constant SADCWR6_INDEX_C   : natural := 17;
   constant SADCWR7_INDEX_C   : natural := 18;
   constant SADCRD_INDEX_C    : natural := 19;
   constant SADCTEST_INDEX_C  : natural := 20;
   constant MMCM_INDEX_C      : natural := 21;
   constant FADC_TOP_INDEX_C  : natural := 22;
   
   function CrossbarConfigInit return AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) is
      variable temp : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0);
   begin
     forLoop: for i in 0 to NUM_AXI_MASTERS_C-1 loop
       temp(i).baseAddr := std_logic_vector(to_unsigned(i * 2**24, 32));
       temp(i).addrBits := 24;
       temp(i).connectivity := x"FFFF";
     end loop;

     return temp;
   end function CrossbarConfigInit;
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := CrossbarConfigInit;
   
   constant ADDR_BITS_C : integer := 27;
   
   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilReadMaster  : AxiLiteReadMasterType;

   signal mbWriteMaster : AxiLiteWriteMasterType;
   signal mbWriteSlave  : AxiLiteWriteSlaveType;
   signal mbReadSlave   : AxiLiteReadSlaveType;
   signal mbReadMaster  : AxiLiteReadMasterType;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal axiClk         : sl;
   signal axiRst         : sl;
   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;
   signal axiWriteMaster : AxiWriteMasterType;
   signal axiWriteSlave  : AxiWriteSlaveType;
   signal calibComplete  : sl;

   signal mbTxMaster : AxiStreamMasterType;
   signal mbTxSlave  : AxiStreamSlaveType;
   signal mbIrq      : slv(7 downto 0) := (others => '0');

   signal bootCsL  : sl;
   signal bootSck  : sl;
   signal bootMosi : sl;
   signal bootMiso : sl;
   signal di       : slv(3 downto 0);
   signal do       : slv(3 downto 0);

   signal dataTxMaster : AxiStreamMasterType;
   signal dataTxSlave  : AxiStreamSlaveType;
   
   signal axiAdcWriteMasters   : AxiWriteMasterArray(7 downto 0);
   signal axiAdcWriteSlaves    : AxiWriteSlaveArray(7 downto 0);
   signal axiDoutReadMaster    : AxiReadMasterType;
   signal axiDoutReadSlave     : AxiReadSlaveType;
   signal axiBistReadMaster    : AxiReadMasterType;
   signal axiBistReadSlave     : AxiReadSlaveType;
   signal axiBistWriteMaster   : AxiWriteMasterType;
   signal axiBistWriteSlave    : AxiWriteSlaveType;
   
   signal adcData       : Slv16Array(7 downto 0);
   signal adcDataTester : Slv32Array(7 downto 0);
   
   signal gTime      : slv(63 downto 0);
   
   signal clk250ddr  : sl;
   signal clk250     : sl;
   signal rst250     : sl;
   
   signal memReady   : sl;
   signal memFailed  : sl;
   signal writerRst  : sl;
   
   signal hdrDout       : Slv32Array(7 downto 0);
   signal hdrValid      : slv(7 downto 0);
   signal hdrRd         : slv(7 downto 0);
   signal memWrAddr     : Slv32Array(7 downto 0);
   signal memFull       : slv(7 downto 0);
   
   signal swTrigger     : sl;
   signal ddrRstN       : sl;
   
   attribute keep : string;
   attribute keep of clk250 : signal is "true";
   attribute keep of rst250 : signal is "true";

begin
   
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
      pgpTxN           => pgpTxN
   );
   
   ----------------------------------------------
   -- Clock Manager
   ----------------------------------------------
   -- clkIn       - 250.00 MHz
   -- clkOut(0)   - 250.00 MHz
   -- clkOut(1)   - 125.00 MHz
   U_PLL : entity work.ClockManagerUltraScale
   generic map(
      TPD_G             => TPD_G,
      TYPE_G            => "MMCM",
      INPUT_BUFG_G      => false,
      FB_BUFG_G         => true,
      RST_IN_POLARITY_G => '1',
      NUM_CLOCKS_G      => 2,
      -- MMCM attributes
      BANDWIDTH_G       => "OPTIMIZED",
      CLKIN_PERIOD_G    => 4.0,
      DIVCLK_DIVIDE_G   => 10,
      CLKFBOUT_MULT_G   => 40,
      CLKOUT0_DIVIDE_G  => 4,
      CLKOUT1_DIVIDE_G  => 8
   )
   port map(
      -- Clock Input
      clkIn             => clk250ddr,
      -- Clock Outputs
      clkOut(0)         => clk250,
      clkOut(1)         => lmkRefOut,
      -- Reset Outputs
      rstOut(0)         => rst250,
      rstOut(1)         => open,
      -- AXI-Lite Interface 
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => axilReadMasters(MMCM_INDEX_C),
      axilReadSlave     => axilReadSlaves(MMCM_INDEX_C),
      axilWriteMaster   => axilWriteMasters(MMCM_INDEX_C),
      axilWriteSlave    => axilWriteSlaves(MMCM_INDEX_C)
   );

   --------------------------------
   -- Microblaze Embedded Processor
   --------------------------------
   U_CPU : entity work.MicroblazeBasicCoreWrapper
   generic map (
      TPD_G           => TPD_G,
      AXIL_ADDR_MSB_C => false)      -- false = [0x00000000:0xFFFFFFFF]
   port map (
      -- Master AXI-Lite Interface: [0x00000000:0xFFFFFFFF]
      mAxilWriteMaster => mbWriteMaster,
      mAxilWriteSlave  => mbWriteSlave,
      mAxilReadMaster  => mbReadMaster,
      mAxilReadSlave   => mbReadSlave,
      -- Streaming
      mAxisMaster      => mbTxMaster,
      mAxisSlave       => mbTxSlave,
      -- IRQ
      interrupt        => mbIrq,
      -- Clock and Reset
      clk              => axilClk,
      rst              => axilRst
   );

   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR : entity work.AxiLiteCrossbar
   generic map (
      TPD_G              => TPD_G,
      DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
      NUM_SLAVE_SLOTS_G  => 2,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
   port map (
      axiClk              => axilClk,
      axiClkRst           => axilRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteMasters(1) => mbWriteMaster,
      sAxiWriteSlaves(0)  => axilWriteSlave,
      sAxiWriteSlaves(1)  => mbWriteSlave,
      sAxiReadMasters(0)  => axilReadMaster,
      sAxiReadMasters(1)  => mbReadMaster,
      sAxiReadSlaves(0)   => axilReadSlave,
      sAxiReadSlaves(1)   => mbReadSlave,
      mAxiWriteMasters    => axilWriteMasters,
      mAxiWriteSlaves     => axilWriteSlaves,
      mAxiReadMasters     => axilReadMasters,
      mAxiReadSlaves      => axilReadSlaves
   );
   
   --------------------------
   -- Power Supply Module
   --------------------------    
   U_PowerController: entity work.PowerController
   port map ( 
      axilClk           => axilClk,
      axilRst           => axilRst,
      sAxilWriteMaster  => axilWriteMasters(POWER_INDEX_C),
      sAxilWriteSlave   => axilWriteSlaves(POWER_INDEX_C),
      sAxilReadMaster   => axilReadMasters(POWER_INDEX_C),
      sAxilReadSlave    => axilReadSlaves(POWER_INDEX_C),
      leds(3)           => open,
      leds(2 downto 0)  => leds(2 downto 0),
      enDcDcAm6V        => enDcDcAm6V,
      enDcDcAp5V4       => enDcDcAp5V4,
      enDcDcAp3V7       => enDcDcAp3V7,
      enDcDcAp2V3       => enDcDcAp2V3,
      enDcDcAp1V6       => enDcDcAp1V6,
      enLdoSlow         => enLdoSlow,
      enLdoFast         => enLdoFast,
      enLdoAm5V         => enLdoAm5V,
      syncDcDcDp6V      => syncDcDcDp6V,
      syncDcDcAp6V      => syncDcDcAp6V,
      syncDcDcAm6V      => syncDcDcAm6V,
      syncDcDcAp5V4     => syncDcDcAp5V4,
      syncDcDcAp3V7     => syncDcDcAp3V7,
      syncDcDcAp2V3     => syncDcDcAp2V3,
      syncDcDcAp1V6     => syncDcDcAp1V6,
      syncDcDcDp3V3     => syncDcDcDp3V3,
      syncDcDcDp1V8     => syncDcDcDp1V8,
      syncDcDcDp1V2     => syncDcDcDp1V2,
      syncDcDcDp0V95    => syncDcDcDp0V95,
      syncDcDcMgt1V0    => syncDcDcMgt1V0,
      syncDcDcMgt1V2    => syncDcDcMgt1V2,
      syncDcDcMgt1V8    => syncDcDcMgt1V8,
      pokDcDcDp6V       => pokDcDcDp6V,
      pokDcDcAp6V       => pokDcDcAp6V,
      pokDcDcAm6V       => pokDcDcAm6V,
      pokDcDcAp5V4      => pokDcDcAp5V4,
      pokDcDcAp3V7      => pokDcDcAp3V7,
      pokDcDcAp2V3      => pokDcDcAp2V3,
      pokDcDcAp1V6      => pokDcDcAp1V6,
      pokLdoA0p1V8      => pokLdoA0p1V8,
      pokLdoA0p3V3      => pokLdoA0p3V3,
      pokLdoAd1p1V2     => pokLdoAd1p1V2,
      pokLdoAd2p1V2     => pokLdoAd2p1V2,
      pokLdoA1p1V9      => pokLdoA1p1V9,
      pokLdoA2p1V9      => pokLdoA2p1V9,
      pokLdoAd1p1V9     => pokLdoAd1p1V9,
      pokLdoAd2p1V9     => pokLdoAd2p1V9,
      pokLdoA1p3V3      => pokLdoA1p3V3,
      pokLdoA2p3V3      => pokLdoA2p3V3,
      pokLdoAvclkp3V3   => pokLdoAvclkp3V3,
      pokLdoA0p5V0      => pokLdoA0p5V0,
      pokLdoA1p5V0      => pokLdoA1p5V0,
      sadcRst           => sadcRst,
      sadcCtrl1         => sadcCtrl1,
      sadcCtrl2         => sadcCtrl2,
      sampEn            => sampEn,
      fadcPdn           => fadcPdn,
      fadcReset         => fadcReset,
      ddrRstN           => ddrRstN
   );
   
   ----------------------------------------------------
   -- 250 MSPS ADCs configuration SPI
   ----------------------------------------------------
   U_SADC_SPI_Conf: entity work.AxiSpiMaster
   generic map (
      ADDRESS_SIZE_G    => 7,
      DATA_SIZE_G       => 8,
      CLK_PERIOD_G      => 6.4E-9,
      SPI_SCLK_PERIOD_G => 1.0E-6,
      SPI_NUM_CHIPS_G   => 4
   )
   port map (
      axiClk         => axilClk,
      axiRst         => axilRst,
      axiReadMaster  => axilReadMasters(SADCONF_INDEX_C),
      axiReadSlave   => axilReadSlaves(SADCONF_INDEX_C),
      axiWriteMaster => axilWriteMasters(SADCONF_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(SADCONF_INDEX_C),
      coreSclk       => sadcSclk,
      coreSDin       => sadcSDin,
      coreSDout      => sadcSDout,
      coreMCsb       => sadcCsb
   );
   
   
   ------------------------------------------------
   -- Temporary global time counter
   ------------------------------------------------
   
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
   
   ------------------------------------------------
   -- 250 MSPS ADCs readout
   ------------------------------------------------
   GEN_250MSPS : for i in 3 downto 0 generate
      
      U_250MspsAdc : entity work.AxiAds42lb69Core
      generic map (
         XIL_DEVICE_G   => "ULTRASCALE"
      )
      port map (
         -- ADC Ports
         adcIn.clkFbP   => sadcClkFbP(i),
         adcIn.clkFbN   => sadcClkFbN(i),
         adcIn.dataP(0) => sadcDataP(i)( 7 downto 0),
         adcIn.dataP(1) => sadcDataP(i)(15 downto 8),
         adcIn.dataN(0) => sadcDataN(i)( 7 downto 0),
         adcIn.dataN(1) => sadcDataN(i)(15 downto 8),
         adcOut.clkP    => sadcClkP(i),
         adcOut.clkN    => sadcClkN(i),
         adcOut.syncP   => sadcSyncP(i),
         adcOut.syncN   => sadcSyncN(i),
         -- ADC signals (adcClk domain)
         adcSync        => '1',
         adcData        => adcData(i*2+1 downto i*2),
         -- AXI-Lite Register Interface (axiClk domain)
         axiReadMaster  => axilReadMasters(SADCRD0_INDEX_C+i),
         axiReadSlave   => axilReadSlaves(SADCRD0_INDEX_C+i),
         axiWriteMaster => axilWriteMasters(SADCRD0_INDEX_C+i),
         axiWriteSlave  => axilWriteSlaves(SADCRD0_INDEX_C+i),
         -- Clocks and Resets
         axiClk         => axilClk,
         axiRst         => axilRst,
         adcClk         => clk250,
         adcRst         => rst250,
         refclk200MHz   => clk250
      );
      
   end generate;
   
   ------------------------------------------------
   -- 250 MSPS ADCs pattern tester
   ------------------------------------------------
   
   GEN_250MSPS_TESTER: for i in 0 to 7 generate
      adcDataTester(i)(31 downto 16)   <= (others=>'0');
      adcDataTester(i)(15 downto 0)    <= adcData(i);
   end generate;
   
   U_AdcPatternTester: entity work.AdcPatternTester
   generic map (
      ADC_BITS_G        => 16,
      NUM_CHANNELS_G    => 8
   )
   port map ( 
      -- ADC Interface
      adcClk            => clk250,
      adcRst            => rst250,
      adcData           => adcDataTester,
      
      -- Axi Interface
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilWriteMaster   => axilWriteMasters(SADCTEST_INDEX_C),
      axilWriteSlave    => axilWriteSlaves(SADCTEST_INDEX_C),
      axilReadMaster    => axilReadMasters(SADCTEST_INDEX_C),
      axilReadSlave     => axilReadSlaves(SADCTEST_INDEX_C),
      
      -- Direct status bits
      testDone          => open,
      testFailed        => open
   );
   
   ------------------------------------------------
   -- 250 MSPS ADCs Buffer Writers
   ------------------------------------------------
   GEN_250MSPS_BUFF : for i in 0 to 7 generate 
      U_SadcBufferWriter : entity work.SadcBufferWriter
      generic map (
         ADDR_BITS_G       => ADDR_BITS_C,
         ADDR_OFFSET_G     => toSlv(i*2**ADDR_BITS_C, 32)
      )
      port map (
         -- ADC interface
         adcClk            => clk250,
         adcRst            => writerRst,
         adcData           => adcData(i),
         gTime             => gTime,
         extTrigger        => swTrigger,
         -- AXI-Lite Interface for local registers 
         axilClk           => axilClk,
         axilRst           => axilRst,
         axilReadMaster    => axilReadMasters(SADCWR0_INDEX_C+i),
         axilReadSlave     => axilReadSlaves(SADCWR0_INDEX_C+i),
         axilWriteMaster   => axilWriteMasters(SADCWR0_INDEX_C+i),
         axilWriteSlave    => axilWriteSlaves(SADCWR0_INDEX_C+i),
         -- AXI Interface (adcClk)
         axiWriteMaster    => axiAdcWriteMasters(i),
         axiWriteSlave     => axiAdcWriteSlaves(i),
         -- Trigger information to data reader (adcClk)
         hdrDout           => hdrDout(i),
         hdrValid          => hdrValid(i),
         hdrRd             => hdrRd(i),
         -- Buffer handshake to/from data reader (adcClk)
         memWrAddr         => memWrAddr(i),
         memFull           => memFull(i)
      );
   end generate;
   
   ------------------------------------------------
   -- 250 MSPS ADCs Buffer Reader
   ------------------------------------------------
   U_SadcBufferReader: entity work.SadcBufferReader
   generic map (
      ADDR_BITS_G       => ADDR_BITS_C
   )
   port map (
      -- ADC Clock Domain
      adcClk            => clk250,
      adcRst            => writerRst,
      -- AXI-Lite Interface for local registers 
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => axilReadMasters(SADCRD_INDEX_C),
      axilReadSlave     => axilReadSlaves(SADCRD_INDEX_C),
      axilWriteMaster   => axilWriteMasters(SADCRD_INDEX_C),
      axilWriteSlave    => axilWriteSlaves(SADCRD_INDEX_C),
      -- AXI Interface (adcClk)
      axiReadMaster     => axiDoutReadMaster,
      axiReadSlave      => axiDoutReadSlave,
      -- Trigger information from data writers (adcClk)
      hdrDout           => hdrDout,
      hdrValid          => hdrValid,
      hdrRd             => hdrRd,
      -- Buffer handshake to/from data writers (adcClk)
      memWrAddr         => memWrAddr,
      memFull           => memFull,
      -- AxiStream output
      axisClk           => axilClk,
      axisRst           => axilRst,
      axisMaster        => dataTxMaster,
      axisSlave         => dataTxSlave
   );
   
   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
   generic map (
      TPD_G           => TPD_G,
      BUILD_INFO_G    => BUILD_INFO_G,
      XIL_DEVICE_G    => "ULTRASCALE",
      EN_DEVICE_DNA_G => true)
   port map (
      -- AXI-Lite Register Interface
      axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
      axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
      axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C),
      -- Clocks and Resets
      axiClk         => axilClk,
      axiRst         => axilRst
   );

   --------------------------
   -- AXI-Lite: SYSMON Module
   --------------------------
   U_SysMon : entity work.LzDigitizerSysMon
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
   port map (
      -- SYSMON Ports
      vPIn            => vPIn,
      vNIn            => vNIn,
      -- AXI-Lite Register Interface
      axilReadMaster  => axilReadMasters(SYSMON_INDEX_C),
      axilReadSlave   => axilReadSlaves(SYSMON_INDEX_C),
      axilWriteMaster => axilWriteMasters(SYSMON_INDEX_C),
      axilWriteSlave  => axilWriteSlaves(SYSMON_INDEX_C),
      -- Clocks and Resets
      axilClk         => axilClk,
      axilRst         => axilRst
   );

   ------------------------------
   -- AXI-Lite: Boot Flash Module
   ------------------------------
   U_BootProm : entity work.AxiMicronN25QCore
   generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      MEM_ADDR_MASK_G  => x"00000000",  -- Using hardware write protection
      AXI_CLK_FREQ_G   => 156.25E+6,        -- units of Hz
      SPI_CLK_FREQ_G   => (156.25E+6/4.0))  -- units of Hz
   port map (
      -- FLASH Memory Ports
      csL            => bootCsL,
      sck            => bootSck,
      mosi           => bootMosi,
      miso           => bootMiso,
      -- AXI-Lite Register Interface
      axiReadMaster  => axilReadMasters(BOOT_MEM_INDEX_C),
      axiReadSlave   => axilReadSlaves(BOOT_MEM_INDEX_C),
      axiWriteMaster => axilWriteMasters(BOOT_MEM_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(BOOT_MEM_INDEX_C),
      -- Clocks and Resets
      axiClk         => axilClk,
      axiRst         => axilRst
   );

   U_STARTUPE3 : STARTUPE3
   generic map (
      PROG_USR      => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
      SIM_CCLK_FREQ => 0.0)  -- Set the Configuration Clock Frequency(ns) for simulation
   port map (
      CFGCLK    => open,  -- 1-bit output: Configuration main clock output
      CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
      DI        => di,  -- 4-bit output: Allow receiving on the D[3:0] input pins
      EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
      DO        => do,  -- 4-bit input: Allows control of the D[3:0] pin outputs
      DTS       => "1110",  -- 4-bit input: Allows tristate of the D[3:0] pins
      FCSBO     => bootCsL,  -- 1-bit input: Contols the FCS_B pin for flash access
      FCSBTS    => '0',              -- 1-bit input: Tristate the FCS_B pin
      GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO  => bootSck,          -- 1-bit input: User CCLK input
      USRCCLKTS => '0',  -- 1-bit input: User CCLK 3-state enable input
      USRDONEO  => '1',  -- 1-bit input: User DONE pin output control
      USRDONETS => '0'   -- 1-bit input: User DONE 3-state enable output
   );  
   
   do       <= "111" & bootMosi;
   bootMiso <= di(1);

   --------------------
   -- DDR memory tester
   --------------------
   U_AxiMemTester : entity work.AxiMemTester
   generic map (
      TPD_G        => TPD_G,
      START_ADDR_G => START_ADDR_C,
      STOP_ADDR_G  => STOP_ADDR_C,
      AXI_CONFIG_G => DDR_AXI_CONFIG_C)
   port map (
      -- AXI-Lite Interface
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => axilReadMasters(DDR_MEM_INDEX_C),
      axilReadSlave   => axilReadSlaves(DDR_MEM_INDEX_C),
      axilWriteMaster => axilWriteMasters(DDR_MEM_INDEX_C),
      axilWriteSlave  => axilWriteSlaves(DDR_MEM_INDEX_C),
      memReady        => memReady,
      memError        => memFailed,
      -- DDR Memory Interface
      axiClk          => axiClk,
      axiRst          => axiRst,
      start           => calibComplete,
      axiWriteMaster  => axiBistWriteMaster,
      axiWriteSlave   => axiBistWriteSlave,
      axiReadMaster   => axiBistReadMaster,
      axiReadSlave    => axiBistReadSlave
   );

   ------------------------------------------------
   -- DDR memory controller
   ------------------------------------------------
   U_DDR : entity work.MigCoreWrapper
   generic map (
      TPD_G => TPD_G)
   port map (
      -- AXI Slave
      axiClk           => axiClk,
      axiRst           => axiRst,
      axiReadMaster    => axiReadMaster,
      axiReadSlave     => axiReadSlave,
      axiWriteMaster   => axiWriteMaster,
      axiWriteSlave    => axiWriteSlave,
      -- DDR PHY Ref clk
      c0_sys_clk_p     => c0_sys_clk_p,
      c0_sys_clk_n     => c0_sys_clk_n,
      -- DRR Memory interface ports
      c0_ddr4_adr      => c0_ddr4_adr,
      c0_ddr4_ba       => c0_ddr4_ba,
      c0_ddr4_cke      => c0_ddr4_cke,
      c0_ddr4_cs_n     => c0_ddr4_cs_n,
      c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n,
      c0_ddr4_dq       => c0_ddr4_dq,
      c0_ddr4_dqs_c    => c0_ddr4_dqs_c,
      c0_ddr4_dqs_t    => c0_ddr4_dqs_t,
      c0_ddr4_odt      => c0_ddr4_odt,
      c0_ddr4_bg       => c0_ddr4_bg,
      c0_ddr4_reset_n  => c0_ddr4_reset_n,
      c0_ddr4_act_n    => c0_ddr4_act_n,
      c0_ddr4_ck_c     => c0_ddr4_ck_c,
      c0_ddr4_ck_t     => c0_ddr4_ck_t,
      calibComplete    => calibComplete,
      c0_ddr4_aresetn  => ddrRstN,
      clk250out        => clk250ddr
   );
   
   ------------------------------------------------
   -- DDR memory AXI interconnect
   ------------------------------------------------
   U_AxiIcWrapper : entity work.AxiIcWrapper
   port map (
      -- AXI Slaves for ADC channels
      -- 128 Bit Data Bus
      -- 1 burst packet FIFOs
      axiAdcClk            => clk250,
      axiAdcWriteMasters   => axiAdcWriteMasters,
      axiAdcWriteSlaves    => axiAdcWriteSlaves,
      
      -- AXI Slave for data readout
      -- 32 Bit Data Bus
      axiDoutClk           => clk250,
      axiDoutReadMaster    => axiDoutReadMaster,
      axiDoutReadSlave     => axiDoutReadSlave,
      
      -- AXI Slave for memory tester (aximClk domain)
      -- 512 Bit Data Bus
      axiBistReadMaster    => axiBistReadMaster,
      axiBistReadSlave     => axiBistReadSlave ,
      axiBistWriteMaster   => axiBistWriteMaster,
      axiBistWriteSlave    => axiBistWriteSlave,
      
      -- AXI Master
      -- 512 Bit Data Bus
      aximClk              => axiClk,
      aximRst              => axiRst,
      aximReadMaster       => axiReadMaster,
      aximReadSlave        => axiReadSlave,
      aximWriteMaster      => axiWriteMaster,
      aximWriteSlave       => axiWriteSlave
   );
   
   -- keep memory writers in reset during memory test
   memRst : process (clk250) is
   begin
      if rising_edge(clk250) then
         if rst250 = '1' then
            writerRst <= '1' after TPD_G;
         elsif memReady = '1' and memFailed = '0' then
            writerRst <= '0' after TPD_G;
         end if;
      end if;
   end process memRst;
   
   leds(3) <= not writerRst;

end top_level;
