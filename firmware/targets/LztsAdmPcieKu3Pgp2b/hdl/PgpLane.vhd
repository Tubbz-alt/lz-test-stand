-------------------------------------------------------------------------------
-- File       : PgpLane.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-04
-- Last update: 2018-02-20
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP Gen3 Card'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP Gen3 Card', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;
use work.Pgp2bPkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity PgpLane is
   generic (
      TPD_G            : time                  := 1 ns;
      LANE_G           : positive range 0 to 7 := 0;
      AXI_BASE_ADDR_G  : slv(31 downto 0)      := (others => '0'));
   port (
      -- DRP Clock and Reset
      drpClk          : in  sl;
      drpRst          : in  sl;
      -- PGP Serial Ports
      pgpTxP          : out sl;
      pgpTxN          : out sl;
      pgpRxP          : in  sl;
      pgpRxN          : in  sl;
      pgpRefClk       : in  sl;
      -- DMA Interface (dmaClk domain)
      dmaClk          : in  sl;
      dmaRst          : in  sl;
      dmaObMaster     : in  AxiStreamMasterType;
      dmaObSlave      : out AxiStreamSlaveType;
      dmaIbMaster     : out AxiStreamMasterType;
      dmaIbSlave      : in  AxiStreamSlaveType;
      -- SRPv3 Tap Interface (dmaClk domain)
      regObMaster     : in  AxiStreamMasterType;
      regObSlave      : out AxiStreamSlaveType;
      regIbMaster     : out AxiStreamMasterType;
      regIbSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end PgpLane;

architecture mapping of PgpLane is

   constant NUM_AXI_MASTERS_C : natural := 3;

   constant GT_INDEX_C   : natural := 0;
   constant MON_INDEX_C  : natural := 1;
   constant CTRL_INDEX_C : natural := 2;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 16, 12);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal pgpTxIn  : Pgp2bTxInType;
   signal pgpTxOut : Pgp2bTxOutType;

   signal pgpRxIn  : Pgp2bRxInType;
   signal pgpRxOut : Pgp2bRxOutType;

   signal pgpTxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpTxSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal pgpRxMasters : AxiStreamMasterArray(3 downto 0);
   signal pgpRxCtrl    : AxiStreamCtrlArray(3 downto 0);

   signal pgpTxOutClk : sl;
   signal pgpTxClk    : sl;
   signal pgpTxRst    : sl;

   signal pgpRxOutClk : sl;
   signal pgpRxClk    : sl;
   signal pgpRxRst    : sl;

   signal config : ConfigType;

begin

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
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

   -----------
   -- PGP Core
   -----------
   U_Pgp : entity work.Pgp2bGthUltra
      generic map (
         TPD_G             => TPD_G,
         VC_INTERLEAVE_G   => 1)        -- AxiStreamDmaV2 supports interleaving
      port map (
         -- GT Clocking
         stableClk       => drpClk,
         stableRst       => drpRst,
         gtRefClk        => pgpRefClk,
         -- Gt Serial IO
         pgpGtTxP        => pgpTxP,
         pgpGtTxN        => pgpTxN,
         pgpGtRxP        => pgpRxP,
         pgpGtRxN        => pgpRxN,
         -- Tx Clocking
         pgpTxReset      => pgpTxRst,
         pgpTxOutClk     => pgpTxOutClk,
         pgpTxClk        => pgpTxClk,
         pgpTxMmcmLocked => '1',
         -- Rx clocking
         pgpRxReset      => pgpRxRst,
         pgpRxOutClk     => pgpRxOutClk,
         pgpRxClk        => pgpRxClk,
         pgpRxMmcmLocked => '1',
         -- Non VC Rx Signals
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters    => pgpTxMasters,
         pgpTxSlaves     => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters    => pgpRxMasters,
         pgpRxCtrl       => pgpRxCtrl,
         -- AXI-Lite Interface 
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(GT_INDEX_C),
         axilReadSlave   => axilReadSlaves(GT_INDEX_C),
         axilWriteMaster => axilWriteMasters(GT_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(GT_INDEX_C));

   U_BUFG_TX : BUFG_GT
      port map (
         I       => pgpTxOutClk,
         CE      => '1',
         CEMASK  => '1',
         CLR     => '0',
         CLRMASK => '1',
         DIV     => "000",              -- Divide by 1
         O       => pgpTxClk);

   U_BUFG_RX : BUFG_GT
      port map (
         I       => pgpRxOutClk,
         CE      => '1',
         CEMASK  => '1',
         CLR     => '0',
         CLRMASK => '1',
         DIV     => "000",              -- Divide by 1
         O       => pgpRxClk);

   --------------         
   -- PGP Monitor
   --------------         
   U_PgpMon : entity work.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         COMMON_TX_CLK_G    => false,
         COMMON_RX_CLK_G    => false,
         WRITE_EN_G         => true,
         AXI_CLK_FREQ_G     => (SYS_CLK_FREQ_C/2),
         STATUS_CNT_WIDTH_G => 16,
         ERROR_CNT_WIDTH_G  => 16)
      port map (
         -- TX PGP Interface (pgpTxClk)
         pgpTxClk        => pgpTxClk,
         pgpTxClkRst     => pgpTxRst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         -- RX PGP Interface (pgpRxClk)
         pgpRxClk        => pgpRxClk,
         pgpRxClkRst     => pgpRxRst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(MON_INDEX_C),
         axilReadSlave   => axilReadSlaves(MON_INDEX_C),
         axilWriteMaster => axilWriteMasters(MON_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(MON_INDEX_C));

   ------------
   -- Misc Core
   ------------
   U_PgpMiscCtrl : entity work.PgpMiscCtrl
      generic map (
         TPD_G            => TPD_G)
      port map (
         -- Control/Status  (axilClk domain)
         config          => config,
         txUserRst       => pgpTxRst,
         rxUserRst       => pgpRxRst,
         -- AXI Lite interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(CTRL_INDEX_C),
         axilReadSlave   => axilReadSlaves(CTRL_INDEX_C),
         axilWriteMaster => axilWriteMasters(CTRL_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(CTRL_INDEX_C));

   --------------
   -- PGP TX Path
   --------------
   U_Tx : entity work.PgpLaneTx
      generic map (
         TPD_G => TPD_G)
      port map (
         -- DMA Interface (dmaClk domain)
         dmaClk       => dmaClk,
         dmaRst       => dmaRst,
         dmaObMaster  => dmaObMaster,
         dmaObSlave   => dmaObSlave,
         -- SRPv3 Tap Interface (dmaClk domain)
         regObMaster  => regObMaster,
         regObSlave   => regObSlave,
         -- PGP Interface
         pgpTxClk     => pgpTxClk,
         pgpTxRst     => pgpTxRst,
         pgpRxOut     => pgpRxOut,
         pgpTxOut     => pgpTxOut,
         pgpTxMasters => pgpTxMasters,
         pgpTxSlaves  => pgpTxSlaves);

   --------------
   -- PGP RX Path
   --------------
   U_Rx : entity work.PgpLaneRx
      generic map (
         TPD_G  => TPD_G,
         LANE_G => LANE_G)
      port map (
         -- DMA Interface (dmaClk domain)
         dmaClk       => dmaClk,
         dmaRst       => dmaRst,
         dmaIbMaster  => dmaIbMaster,
         dmaIbSlave   => dmaIbSlave,
         -- SRPv3 Tap Interface (dmaClk domain)
         regIbMaster  => regIbMaster,
         regIbSlave   => regIbSlave,
         -- PGP RX Interface (pgpRxClk domain)
         pgpRxClk     => pgpRxClk,
         pgpRxRst     => pgpRxRst,
         pgpRxOut     => pgpRxOut,
         pgpRxMasters => pgpRxMasters,
         pgpRxCtrl    => pgpRxCtrl);

end mapping;
