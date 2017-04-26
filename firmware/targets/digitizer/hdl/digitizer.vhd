-------------------------------------------------------------------------------
-- File       : digitizer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-02-07
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
use work.SsiPkg.all;
use work.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity digitizer is
   generic (
      TPD_G          : time            := 1 ns;
      SIM_SPEEDUP_G  : boolean         := false;
      BUILD_INFO_G   : BuildInfoType
   );
   port (
      -- PGP signals
      pgpClkP           : in    sl;
      pgpClkN           : in    sl;
      pgpRxP            : in    sl;
      pgpRxN            : in    sl;
      pgpTxP            : out   sl;
      pgpTxN            : out   sl;
      
      -- DDR PHY Ref clk
      c0_sys_clk_p      : in    sl;
      c0_sys_clk_n      : in    sl;
      -- DRR Memory interface ports
      c0_ddr4_dq        : inout slv(63 downto 0);
      c0_ddr4_dqs_c     : inout slv(7 downto 0);
      c0_ddr4_dqs_t     : inout slv(7 downto 0);
      c0_ddr4_adr       : out   slv(16 downto 0);
      c0_ddr4_ba        : out   slv(1 downto 0);
      c0_ddr4_bg        : out   slv(0 to 0);
      c0_ddr4_reset_n   : out   sl;
      c0_ddr4_act_n     : out   sl;
      c0_ddr4_ck_t      : out   slv(0 to 0);
      c0_ddr4_ck_c      : out   slv(0 to 0);
      c0_ddr4_cke       : out   slv(0 to 0);
      c0_ddr4_cs_n      : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n  : inout slv(7 downto 0);
      c0_ddr4_odt       : out   slv(0 to 0)
   );
end digitizer;

architecture top_level of digitizer is
   
   constant DDR_AXI_CONFIG_C : AxiConfigType := axiConfig(
      ADDR_WIDTH_C => 31,
      DATA_BYTES_C => 64,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);
   
   constant START_ADDR_C : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(DDR_AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');
   
   -- AXI-Lite Constants
   constant NUM_AXI_MASTER_SLOTS_C  : natural := 2;
   constant NUM_AXI_SLAVE_SLOTS_C   : natural := 2;
   
   constant AXI_VERSION_INDEX_C     : natural := 0;
   constant TESTMEM_AXI_INDEX_C     : natural := 1;
   
   
   constant AXI_VERSION_BASE_ADDR_C   : slv(31 downto 0) := X"00000000";
   constant TESTMEM_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"04000000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0) := (
      AXI_VERSION_INDEX_C     => (
         baseAddr             => AXI_VERSION_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF"),
      TESTMEM_AXI_INDEX_C     => (
         baseAddr             => TESTMEM_AXI_BASE_ADDR_C,
         addrBits             => 26,
         connectivity         => x"FFFF")
   );

   -- AXI-Lite Signals
   signal sAxiReadMaster   : AxiLiteReadMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiReadSlave    : AxiLiteReadSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteMaster  : AxiLiteWriteMasterArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal sAxiWriteSlave   : AxiLiteWriteSlaveArray(NUM_AXI_SLAVE_SLOTS_C-1 downto 0);
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTER_SLOTS_C-1 downto 0); 
   
   -- AXI Signals
   signal axiClk           : sl;
   signal axiRst           : sl;
   signal axiReadMaster    : AxiReadMasterType;
   signal axiReadSlave     : AxiReadSlaveType;
   signal axiWriteMaster   : AxiWriteMasterType;
   signal axiWriteSlave    : AxiWriteSlaveType;
   
   signal calibComplete    : sl;
   
   constant AXIS_SIZE_C : positive := 4;

   signal txMasters  : AxiStreamMasterArray(AXIS_SIZE_C-1 downto 0);
   signal txSlaves   : AxiStreamSlaveArray(AXIS_SIZE_C-1 downto 0);
   signal rxMasters  : AxiStreamMasterArray(AXIS_SIZE_C-1 downto 0);
   signal rxCtrl     : AxiStreamCtrlArray(AXIS_SIZE_C-1 downto 0);

   signal pgpTxOut   : Pgp2bTxOutType;
   signal pgpRxOut   : Pgp2bRxOutType;

   signal pgpRefClk     : sl;
   signal pgpRefClkDiv2 : sl;
   signal clk           : sl;
   signal rst           : sl;

begin
   
   ---------------------------------------------
   -- PGP 
   ---------------------------------------------
   U_IBUFDS_GTE3 : IBUFDS_GTE3
   generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
      REFCLK_ICNTL_RX    => "00"
   )
   port map (
      I     => pgpClkP,
      IB    => pgpClkN,
      CEB   => '0',
      ODIV2 => pgpRefClkDiv2,      -- Divide by 1
      O     => pgpRefClk
   );

   U_BUFG_GT : BUFG_GT
   port map (
      I       => pgpRefClkDiv2,
      CE      => '1',
      CLR     => '0',
      CEMASK  => '1',
      CLRMASK => '1',
      DIV     => "000",           -- Divide by 1
      O       => clk
   );
   
   U_PwrUpRst : entity work.PwrUpRst
   generic map (
      TPD_G          => TPD_G,
      SIM_SPEEDUP_G  => SIM_SPEEDUP_G,
      IN_POLARITY_G  => '1',
      OUT_POLARITY_G => '1'
   )
   port map (
      clk    => clk,
      rstOut => rst
   );

   U_PGP : entity work.Pgp2bGthUltra
   generic map (
      TPD_G             => TPD_G,
      PAYLOAD_CNT_TOP_G => 7,
      VC_INTERLEAVE_G   => 1,
      NUM_VC_EN_G       => 4
   )
   port map (
      stableClk       => clk,
      stableRst       => rst,
      gtRefClk        => pgpRefClk,
      pgpGtTxP        => pgpTxP,
      pgpGtTxN        => pgpTxN,
      pgpGtRxP        => pgpRxP,
      pgpGtRxN        => pgpRxN,
      pgpTxReset      => rst,
      pgpTxRecClk     => open,
      pgpTxClk        => clk,
      pgpTxMmcmLocked => '1',
      pgpRxReset      => rst,
      pgpRxRecClk     => open,
      pgpRxClk        => clk,
      pgpRxMmcmLocked => '1',
      pgpTxIn         => PGP2B_TX_IN_INIT_C,
      pgpTxOut        => pgpTxOut,
      pgpRxIn         => PGP2B_RX_IN_INIT_C,
      pgpRxOut        => pgpRxOut,
      pgpTxMasters    => txMasters,
      pgpTxSlaves     => txSlaves,
      pgpRxMasters    => rxMasters,
      pgpRxCtrl       => rxCtrl
   );
   
   U_PgpVcMapping: entity work.PgpVcMapping
   port map (
      -- PGP Clock and Reset
      clk             => clk,
      rst             => rst,
      -- AXIS interface
      txMasters       => txMasters,
      txSlaves        => txSlaves,
      rxMasters       => rxMasters,
      rxCtrl          => rxCtrl,
      -- Data Interface
      dataClk         => clk,
      dataRst         => rst,
      dataTxMaster    => AXI_STREAM_MASTER_INIT_C,
      dataTxSlave     => open,
      -- AXI-Lite Interface
      axilClk         => clk,
      axilRst         => rst,
      axilWriteMaster => sAxiWriteMaster(0),
      axilWriteSlave  => sAxiWriteSlave(0),
      axilReadMaster  => sAxiReadMaster(0),
      axilReadSlave   => sAxiReadSlave(0)
   );
   
   ---------------------------------------------
   -- Microblaze 
   ---------------------------------------------
   U_CPU : entity work.MicroblazeBasicCoreWrapper
   generic map (
      TPD_G            => TPD_G)
   port map (
      -- Master AXI-Lite Interface: [0x00000000:0x7FFFFFFF]
      mAxilWriteMaster => sAxiWriteMaster(1),
      mAxilWriteSlave  => sAxiWriteSlave(1),
      mAxilReadMaster  => sAxiReadMaster(1),
      mAxilReadSlave   => sAxiReadSlave(1),
      -- Interrupt Interface
      interrupt(7 downto 0)   => "00000000",
      -- Clock and Reset
      clk              => clk,
      rst              => rst
   );
   
   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
   generic map (
      TPD_G           => TPD_G,
      BUILD_INFO_G    => BUILD_INFO_G,
      EN_DEVICE_DNA_G => false)   
   port map (
      -- AXI-Lite Register Interface
      axiReadMaster  => mAxiReadMasters(AXI_VERSION_INDEX_C),
      axiReadSlave   => mAxiReadSlaves(AXI_VERSION_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(AXI_VERSION_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves(AXI_VERSION_INDEX_C),
      -- Clocks and Resets
      axiClk         => clk,
      axiRst         => rst
   );
   
   ---------------------------------------------
   -- DDR memory tester
   ---------------------------------------------
   U_AxiMemTester : entity work.AxiMemTester
   generic map (
      TPD_G            => TPD_G,
      START_ADDR_G     => START_ADDR_C,
      STOP_ADDR_G      => STOP_ADDR_C,
      AXI_CONFIG_G     => DDR_AXI_CONFIG_C
   )
   port map (
      -- AXI-Lite Interface
      axilClk         => clk,
      axilRst         => rst,
      axilReadMaster  => mAxiReadMasters(TESTMEM_AXI_INDEX_C),
      axilReadSlave   => mAxiReadSlaves(TESTMEM_AXI_INDEX_C),
      axilWriteMaster => mAxiWriteMasters(TESTMEM_AXI_INDEX_C),
      axilWriteSlave  => mAxiWriteSlaves(TESTMEM_AXI_INDEX_C),
      memReady        => open,
      memError        => open,
      -- DDR Memory Interface
      axiClk          => axiClk,
      axiRst          => axiRst,
      start           => calibComplete,
      axiWriteMaster  => axiWriteMaster,
      axiWriteSlave   => axiWriteSlave,
      axiReadMaster   => axiReadMaster,
      axiReadSlave    => axiReadSlave
   );
   
   
   ----------------------------------------
   -- DDR memory controller
   ----------------------------------------
   U_AxiDdr4ControllerWrapper : entity work.AxiDdr4ControllerWrapper
   port map ( 
      -- AXI Slave
      axiClk            => axiClk,
      axiRst            => axiRst,
      axiReadMaster     => axiReadMaster,
      axiReadSlave      => axiReadSlave,
      axiWriteMaster    => axiWriteMaster,
      axiWriteSlave     => axiWriteSlave,
      
      -- DDR PHY Ref clk
      c0_sys_clk_p      => c0_sys_clk_p,
      c0_sys_clk_n      => c0_sys_clk_n,

      -- DRR Memory interface ports
      c0_ddr4_adr       => c0_ddr4_adr,
      c0_ddr4_ba        => c0_ddr4_ba,
      c0_ddr4_cke       => c0_ddr4_cke,
      c0_ddr4_cs_n      => c0_ddr4_cs_n,
      c0_ddr4_dm_dbi_n  => c0_ddr4_dm_dbi_n,
      c0_ddr4_dq        => c0_ddr4_dq,
      c0_ddr4_dqs_c     => c0_ddr4_dqs_c,
      c0_ddr4_dqs_t     => c0_ddr4_dqs_t,
      c0_ddr4_odt       => c0_ddr4_odt,
      c0_ddr4_bg        => c0_ddr4_bg,
      c0_ddr4_reset_n   => c0_ddr4_reset_n,
      c0_ddr4_act_n     => c0_ddr4_act_n,
      c0_ddr4_ck_c      => c0_ddr4_ck_c,
      c0_ddr4_ck_t      => c0_ddr4_ck_t,
      calibComplete     => calibComplete
   );

end top_level;
