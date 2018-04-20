-------------------------------------------------------------------------------
-- File       : SystemCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-10
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
use work.AppPkg.all;
use work.I2cPkg.all;
use work.AxiI2cMasterPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SystemCore is
   generic (
      TPD_G              : time            := 1 ns;
      BUILD_INFO_G       : BuildInfoType;
      NUM_AXI_MASTERS_G  : positive;
      AXI_CONFIG_G       : AxiLiteCrossbarMasterConfigArray);
   port (
      -- Clock and Reset
      axilClk            : in    sl;
      axilRst            : in    sl;
      adcClk             : out   sl;
      adcRst             : out   sl;
      ddrRstN            : in    sl;
      ddrRstOut          : out   sl;
      lmkRefClk          : out   sl;
      -- Inter board synchronization
      gTime              : out slv(63 downto 0);
      syncCmd            : in  sl;
      rstCmd             : in  sl;
      clkInP             : in  sl;
      clkInN             : in  sl;
      clkOutP            : out sl;
      clkOutN            : out sl;
      cmdInP             : in  sl;
      cmdInN             : in  sl;
      cmdOutP            : out sl;
      cmdOutN            : out sl;
      clkLed             : out sl;
      cmdLed             : out sl;
      mstLed             : out sl;
      -- power/temperature sensors
      tmpScl             : inout sl;
      tmpSda             : inout sl;
      pwrScl             : inout sl;
      pwrSda             : inout sl;
      -- DNA output
      dnaValue           : out   slv(127 downto 0);
      -- DDR PHY Ref clk
      c0_sys_clk_p       : in    sl;
      c0_sys_clk_n       : in    sl;
      c0_ddr4_dq         : inout slv(DDR_WIDTH_C-1 downto 0);
      c0_ddr4_dqs_c      : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_dqs_t      : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_adr        : out   slv(16 downto 0);
      c0_ddr4_ba         : out   slv(1 downto 0);
      c0_ddr4_bg         : out   slv(0 to 0);
      c0_ddr4_reset_n    : out   sl;
      c0_ddr4_act_n      : out   sl;
      c0_ddr4_ck_t       : out   slv(0 to 0);
      c0_ddr4_ck_c       : out   slv(0 to 0);
      c0_ddr4_cke        : out   slv(0 to 0);
      c0_ddr4_cs_n       : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n   : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_odt        : out   slv(0 to 0);
      -- ADC AXI Interface (clk250 domain)
      axiAdcWriteMasters : in    AxiWriteMasterArray(7 downto 0);
      axiAdcWriteSlaves  : out   AxiWriteSlaveArray(7 downto 0);
      axiDoutReadMaster  : in    AxiReadMasterType;
      axiDoutReadSlave   : out   AxiReadSlaveType;
      -- PRBS Streaming Interface (axilClk domain)
      prbsTxMaster       : out   AxiStreamMasterType;
      prbsTxSlave        : in    AxiStreamSlaveType;
      -- AXI-Lite Register Interface (axilClk domain)
      mAxilReadMaster    : in    AxiLiteReadMasterType;
      mAxilReadSlave     : out   AxiLiteReadSlaveType;
      mAxilWriteMaster   : in    AxiLiteWriteMasterType;
      mAxilWriteSlave    : out   AxiLiteWriteSlaveType;
      sAxilReadMasters   : out   AxiLiteReadMasterArray(NUM_AXI_MASTERS_G-1 downto 1);
      sAxilReadSlaves    : in    AxiLiteReadSlaveArray(NUM_AXI_MASTERS_G-1 downto 1);
      sAxilWriteMasters  : out   AxiLiteWriteMasterArray(NUM_AXI_MASTERS_G-1 downto 1);
      sAxilWriteSlaves   : in    AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_G-1 downto 1);
      -- SYSMON Ports
      vPIn               : in    sl;
      vNIn               : in    sl;
      -- Temp alert interrupt
      tempAlertInt       : in    sl);
end SystemCore;

architecture top_level of SystemCore is

   constant I2C_TEMP_CONFIG_C : I2cAxiLiteDevArray(3 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("1001000", 8, 8, '0')),
      1 => (MakeI2cAxiLiteDevType("1001001", 8, 8, '0')),
      2 => (MakeI2cAxiLiteDevType("1001011", 8, 8, '0')),
      3 => (MakeI2cAxiLiteDevType("1001111", 8, 8, '0'))
   );
   
   constant I2C_PWR_CONFIG_C : I2cAxiLiteDevArray(2 downto 0) := (
      0 => (MakeI2cAxiLiteDevType("1001000", 8, 8, '0')),
      1 => (MakeI2cAxiLiteDevType("1100111", 8, 8, '0', '1')),
      2 => (MakeI2cAxiLiteDevType("1101111", 8, 8, '0', '1'))
   );   

   constant NUM_AXI_MASTERS_C : natural := 9;

   constant VERSION_INDEX_C  : natural := 0;
   constant SYSMON_INDEX_C   : natural := 1;
   constant BOOT_MEM_INDEX_C : natural := 2;
   constant DDR_MEM_INDEX_C  : natural := 3;
   constant MMCM_INDEX_C     : natural := 4;
   constant SYNC_INDEX_C     : natural := 5;
   constant TEMP_SNS_INDEX_C : natural := 6;
   constant PRBS_INDEX_C     : natural := 7;
   constant PWR_SNS_INDEX_C  : natural := 8;

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"00000000", 24, 20);
   
   signal mbReadMaster     : AxiLiteReadMasterType;
   signal mbReadSlave      : AxiLiteReadSlaveType;
   signal mbWriteMaster    : AxiLiteWriteMasterType;
   signal mbWriteSlave     : AxiLiteWriteSlaveType;

   signal regWriteMasters  : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_G-1 downto 0);
   signal regWriteSlaves   : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_G-1 downto 0);
   signal regReadMasters   : AxiLiteReadMasterArray(NUM_AXI_MASTERS_G-1 downto 0);
   signal regReadSlaves    : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_G-1 downto 0);

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

   signal axiBistReadMaster  : AxiReadMasterType;
   signal axiBistReadSlave   : AxiReadSlaveType;
   signal axiBistWriteMaster : AxiWriteMasterType;
   signal axiBistWriteSlave  : AxiWriteSlaveType;

   signal bootCsL  : sl;
   signal bootSck  : sl;
   signal bootMosi : sl;
   signal bootMiso : sl;
   signal di       : slv(3 downto 0);
   signal do       : slv(3 downto 0);

   signal calibComplete : sl;
   signal memReady      : sl;
   signal memFailed     : sl;
   signal ddrReset      : sl;
   signal clk250ddr     : sl;
   signal adcClock      : sl;
   signal adcReset      : sl;
   
   signal muxClk        : slv(2 downto 0);
   
   signal mbIrq             : slv(7 downto 0) := (others => '0');  -- unused 

begin
   
   ------------------------------------------------
   -- LztsSynchronizer instance
   -- synchronizes global timer
   -- selects local clock (master) or external clock (slave)
   -- generates commands (master) receives and repeats commands (slave)
   ------------------------------------------------
   U_LztsSynchronizer : entity work.LztsSynchronizer
   port map (
      -- AXI-Lite Interface for local registers 
      axilClk           => axilClk,
      axilRst           => axilRst,
      axilReadMaster    => axilReadMasters(SYNC_INDEX_C),
      axilReadSlave     => axilReadSlaves(SYNC_INDEX_C),
      axilWriteMaster   => axilWriteMasters(SYNC_INDEX_C),
      axilWriteSlave    => axilWriteSlaves(SYNC_INDEX_C),
      -- PLL clock input
      pllClk            => adcClock,
      -- local clock input/output
      locClk            => clk250ddr,
      -- Master command inputs (synchronous to clkOut)
      syncCmd           => syncCmd,
      rstCmd            => rstCmd,
      -- Inter-board clock and command
      clkInP            => clkInP,
      clkInN            => clkInN,
      clkOutP           => clkOutP,
      clkOutN           => clkOutN,
      cmdInP            => cmdInP,
      cmdInN            => cmdInN,
      cmdOutP           => cmdOutP,
      cmdOutN           => cmdOutN,
      -- globally synchronized outputs
      muxClk            => muxClk(0),
      rstOut            => open,
      gTime             => gTime,
      -- status LEDs
      clkLed            => clkLed,
      cmdLed            => cmdLed,
      mstLed            => mstLed
   );
   
   
   ------------------------------------------------
   -- Clock Managers Cascade (clock cleaner)
   ------------------------------------------------
   U_PLL0 : entity work.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => false,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- MMCM attributes
         CLKIN_PERIOD_G    => 4.0,      -- 250 MHz
         DIVCLK_DIVIDE_G   => 1,        -- 250 MHz/1
         CLKFBOUT_MULT_G   => 4,        -- 1 GHz = 250 MHz x 4
         CLKOUT0_DIVIDE_G  => 4)        -- 250 MHz = 1 GHz /4
      port map(
         -- Clock Input
         clkIn           => muxClk(0),
         -- Clock Outputs
         clkOut(0)       => muxClk(1));
   
   U_PLL1 : entity work.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => false,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- MMCM attributes
         CLKIN_PERIOD_G    => 4.0,      -- 250 MHz
         DIVCLK_DIVIDE_G   => 1,        -- 250 MHz/1
         CLKFBOUT_MULT_G   => 4,        -- 1 GHz = 250 MHz x 4
         CLKOUT0_DIVIDE_G  => 4)        -- 250 MHz = 1 GHz /4
      port map(
         -- Clock Input
         clkIn           => muxClk(1),
         -- Clock Outputs
         clkOut(0)       => muxClk(2));
   
   U_PLL : entity work.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => false,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 2,
         -- MMCM attributes
         CLKIN_PERIOD_G    => 4.0,      -- 250 MHz
         DIVCLK_DIVIDE_G   => 1,        -- 250 MHz/1
         CLKFBOUT_MULT_G   => 4,        -- 1 GHz = 250 MHz x 4
         CLKOUT0_DIVIDE_G  => 4,        -- 250 MHz = 1 GHz /4
         CLKOUT1_DIVIDE_G  => 100)      -- 10 MHz = 1 GHz /100
      port map(
         -- Clock Input
         clkIn           => muxClk(2),
         -- Clock Outputs
         clkOut(0)       => adcClock,
         clkOut(1)       => lmkRefClk,
         -- Reset Outputs
         rstOut(0)       => adcReset,
         rstOut(1)       => open,
         -- AXI-Lite Interface 
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(MMCM_INDEX_C),
         axilReadSlave   => axilReadSlaves(MMCM_INDEX_C),
         axilWriteMaster => axilWriteMasters(MMCM_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(MMCM_INDEX_C));

   -- Help with timing   
   U_RstPipeline : entity work.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => adcClock,
         rstIn  => adcReset,
         rstOut => adcRst);

   adcClk <= adcClock;
   
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
         -- IRQ
         interrupt        => mbIrq,
         -- Clock and Reset
         clk              => axilClk,
         rst              => axilRst);
   
   
   U_SynchEdge : entity work.SynchronizerEdge
      port map (
         clk         => axilClk,
         rst         => axilRst,
         dataIn      => tempAlertInt,
         risingEdge  => mbIrq(0),
         fallingEdge => mbIrq(1));
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_G,
         MASTERS_CONFIG_G   => AXI_CONFIG_G)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => mAxilWriteMaster,
         sAxiWriteMasters(1) => mbWriteMaster,
         sAxiWriteSlaves(0)  => mAxilWriteSlave,
         sAxiWriteSlaves(1)  => mbWriteSlave,
         sAxiReadMasters(0)  => mAxilReadMaster,
         sAxiReadMasters(1)  => mbReadMaster,
         sAxiReadSlaves(0)   => mAxilReadSlave,
         sAxiReadSlaves(1)   => mbReadSlave,
         mAxiWriteMasters    => regWriteMasters,
         mAxiWriteSlaves     => regWriteSlaves,
         mAxiReadMasters     => regReadMasters,
         mAxiReadSlaves      => regReadSlaves);

   sAxilWriteMasters(NUM_AXI_MASTERS_G-1 downto 1) <= regWriteMasters(NUM_AXI_MASTERS_G-1 downto 1);
   regWriteSlaves(NUM_AXI_MASTERS_G-1 downto 1)    <= sAxilWriteSlaves(NUM_AXI_MASTERS_G-1 downto 1);

   sAxilReadMasters                            <= regReadMasters(NUM_AXI_MASTERS_G-1 downto 1);
   regReadSlaves(NUM_AXI_MASTERS_G-1 downto 1) <= sAxilReadSlaves(NUM_AXI_MASTERS_G-1 downto 1);

   U_XBAR1 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => regWriteMasters(0),
         sAxiWriteSlaves(0)  => regWriteSlaves(0),
         sAxiReadMasters(0)  => regReadMasters(0),
         sAxiReadSlaves(0)   => regReadSlaves(0),

         mAxiWriteMasters => axilWriteMasters,
         mAxiWriteSlaves  => axilWriteSlaves,
         mAxiReadMasters  => axilReadMasters,
         mAxiReadSlaves   => axilReadSlaves);

   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
      generic map (
         TPD_G           => TPD_G,
         BUILD_INFO_G    => BUILD_INFO_G,
         XIL_DEVICE_G    => "ULTRASCALE",
         EN_ICAP_G       => true,
         EN_DEVICE_DNA_G => true)
      port map (
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C),
         -- Clocks and Resets
         axiClk         => axilClk,
         axiRst         => axilRst,
         dnaValueOut    => dnaValue
      );

   --------------------------
   -- AXI-Lite: SYSMON Module
   --------------------------
   U_SysMon : entity work.LzDigitizerSysMon
      generic map (
         TPD_G            => TPD_G)
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
         axilRst         => axilRst);

   ------------------------------
   -- AXI-Lite: Boot Flash Module
   ------------------------------
   U_BootProm : entity work.AxiMicronN25QCore
      generic map (
         TPD_G            => TPD_G,
         MEM_ADDR_MASK_G  => x"00000000",  -- Using hardware write protection
         AXI_CLK_FREQ_G   => 156.25E+6,    -- units of Hz
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
         axiRst         => axilRst);

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
         USRDONETS => '0'  -- 1-bit input: User DONE 3-state enable output
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
         axiReadSlave    => axiBistReadSlave);

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
         clk250out        => clk250ddr);

   ------------------------------------------------
   -- DDR memory AXI interconnect
   ------------------------------------------------
   U_AxiIcWrapper : entity work.AxiIcWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- AXI Slaves for ADC channels
         -- 128 Bit Data Bus
         -- 1 burst packet FIFOs
         axiAdcClk          => adcClock,
         axiAdcWriteMasters => axiAdcWriteMasters,
         axiAdcWriteSlaves  => axiAdcWriteSlaves,
         -- AXI Slave for data readout
         -- 32 Bit Data Bus
         axiDoutClk         => adcClock,
         axiDoutReadMaster  => axiDoutReadMaster,
         axiDoutReadSlave   => axiDoutReadSlave,
         -- AXI Slave for memory tester (aximClk domain)
         -- 512 Bit Data Bus
         axiBistReadMaster  => axiBistReadMaster,
         axiBistReadSlave   => axiBistReadSlave,
         axiBistWriteMaster => axiBistWriteMaster,
         axiBistWriteSlave  => axiBistWriteSlave,
         -- AXI Master
         -- 512 Bit Data Bus
         aximClk            => axiClk,
         aximRst            => axiRst,
         aximReadMaster     => axiReadMaster,
         aximReadSlave      => axiReadSlave,
         aximWriteMaster    => axiWriteMaster,
         aximWriteSlave     => axiWriteSlave);

   -- keep memory writers in reset during memory test
   memRst : process (adcClock) is
   begin
      if rising_edge(adcClock) then
         if adcReset = '1' then
            ddrReset <= '1' after TPD_G;
         elsif memReady = '1' and memFailed = '0' then
            ddrReset <= '0' after TPD_G;
         end if;
      end if;
   end process memRst;

   ddrRstOut <= ddrReset;
   
   ------------------------------------------------
   -- Temperature sensors readout
   ------------------------------------------------
   U_TempI2C : entity work.AxiI2cMasterCore
   generic map (
      DEVICE_MAP_G     => I2C_TEMP_CONFIG_C,
      AXI_CLK_FREQ_G   => 156.25E+6,
      I2C_SCL_FREQ_G   => 100.0E+3
   )
   port map (
      i2cInOut.scl   => tmpScl,
      i2cInOut.sda   => tmpSda,
      axiReadMaster  => axilReadMasters(TEMP_SNS_INDEX_C),
      axiReadSlave   => axilReadSlaves(TEMP_SNS_INDEX_C),
      axiWriteMaster => axilWriteMasters(TEMP_SNS_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(TEMP_SNS_INDEX_C),
      axiClk         => axilClk,
      axiRst         => axilRst
   );
   
   ------------------------------------------------
   -- Power sensors readout
   ------------------------------------------------
   U_PowerI2C : entity work.AxiI2cMasterCore
   generic map (
      DEVICE_MAP_G     => I2C_PWR_CONFIG_C,
      AXI_CLK_FREQ_G   => 156.25E+6,
      I2C_SCL_FREQ_G   => 100.0E+3
   )
   port map (
      i2cInOut.scl   => pwrScl,
      i2cInOut.sda   => pwrSda,
      axiReadMaster  => axilReadMasters(PWR_SNS_INDEX_C),
      axiReadSlave   => axilReadSlaves(PWR_SNS_INDEX_C),
      axiWriteMaster => axilWriteMasters(PWR_SNS_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(PWR_SNS_INDEX_C),
      axiClk         => axilClk,
      axiRst         => axilRst
   );   
   
   ------------------------------------------------
   -- PRBS Tx generator
   ------------------------------------------------
   U_SsiPrbsTx: entity work.SsiPrbsTx
   generic map (
      MASTER_AXI_STREAM_CONFIG_G => ssiAxiStreamConfig(4, TKEEP_COMP_C)
   )
   port map (
      mAxisClk        => axilClk,
      mAxisRst        => axilRst,
      mAxisMaster     => prbsTxMaster,
      mAxisSlave      => prbsTxSlave,
      locClk          => axilClk,
      locRst          => axilRst,
      trig            => '0',
      packetLength    => X"00000000",
      axilReadMaster  => axilReadMasters(PRBS_INDEX_C),
      axilReadSlave   => axilReadSlaves(PRBS_INDEX_C),
      axilWriteMaster => axilWriteMasters(PRBS_INDEX_C),
      axilWriteSlave  => axilWriteSlaves(PRBS_INDEX_C)
   );

end top_level;
