-------------------------------------------------------------------------------
-- File       : PgpLaneTx.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-26
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
use work.AxiStreamPkg.all;
use work.AxiPciePkg.all;
use work.Pgp2bPkg.all;

entity PgpLaneTx is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- DMA Interface (dmaClk domain)
      dmaClk       : in  sl;
      dmaRst       : in  sl;
      dmaObMaster  : in  AxiStreamMasterType;
      dmaObSlave   : out AxiStreamSlaveType;
      -- SRPv3 Tap Interface (dmaClk domain)
      regObMaster  : in  AxiStreamMasterType;
      regObSlave   : out AxiStreamSlaveType;
      -- PGP Interface (pgpTxClk domain)
      pgpTxClk     : in  sl;
      pgpTxRst     : in  sl;
      pgpRxOut     : in  Pgp2bRxOutType;
      pgpTxOut     : in  Pgp2bTxOutType;
      pgpTxMasters : out AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves  : in  AxiStreamSlaveArray(3 downto 0));
end PgpLaneTx;

architecture mapping of PgpLaneTx is

   signal obMaster : AxiStreamMasterType;
   signal obSlave  : AxiStreamSlaveType;

   signal dmaMaster : AxiStreamMasterType;
   signal dmaCtrl   : AxiStreamCtrlType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   signal txMasterSof : AxiStreamMasterType;
   signal txSlaveSof  : AxiStreamSlaveType;

   signal linkReady : sl;
   signal flushEn   : sl;

begin

   U_Mux : entity work.AxiStreamMux
      generic map (
         TPD_G          => TPD_G,
         NUM_SLAVES_G   => 2,
         MODE_G         => "ROUTED",
         TDEST_ROUTES_G => (
            0           => "00000000",  -- Force reg to VC0
            1           => "--------"),  -- Pass the tdest through
         PIPE_STAGES_G  => 1)
      port map (
         -- Clock and reset
         axisClk         => dmaClk,
         axisRst         => dmaRst,
         -- Slaves
         sAxisMasters(0) => regObMaster,
         sAxisMasters(1) => dmaObMaster,
         sAxisSlaves(0)  => regObSlave,
         sAxisSlaves(1)  => dmaObSlave,
         -- Master
         mAxisMaster     => obMaster,
         mAxisSlave      => obSlave);

   linkReady <= pgpTxOut.linkReady and pgpRxOut.linkReady;

   U_FlushSync : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '0')
      port map (
         clk     => dmaClk,
         rst     => dmaRst,
         dataIn  => linkReady,
         dataOut => flushEn);

   U_Flush : entity work.AxiStreamFlush
      generic map (
         TPD_G         => TPD_G,
         AXIS_CONFIG_G => DMA_AXIS_CONFIG_C,
         SSI_EN_G      => true)
      port map (
         axisClk     => dmaClk,
         axisRst     => dmaRst,
         flushEn     => flushEn,
         sAxisMaster => obMaster,
         sAxisSlave  => obSlave,
         mAxisMaster => dmaMaster,
         mAxisCtrl   => dmaCtrl);

   U_RESIZE : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         GEN_SYNC_FIFO_G     => false,
         FIFO_ADDR_WIDTH_G   => 5,
         FIFO_PAUSE_THRESH_G => 20,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => DMA_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => dmaClk,
         sAxisRst    => dmaRst,
         sAxisMaster => dmaMaster,
         sAxisCtrl   => dmaCtrl,
         -- Master Port
         mAxisClk    => pgpTxClk,
         mAxisRst    => pgpTxRst,
         mAxisMaster => txMaster,
         mAxisSlave  => txSlave);

   U_SOF : entity work.SsiInsertSof
      generic map (
         TPD_G               => TPD_G,
         COMMON_CLK_G        => true,
         SLAVE_FIFO_G        => false,
         MASTER_FIFO_G       => false,
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpTxClk,
         sAxisRst    => pgpTxRst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => pgpTxClk,
         mAxisRst    => pgpTxRst,
         mAxisMaster => txMasterSof,
         mAxisSlave  => txSlaveSof);

   U_DeMux : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4,
         MODE_G        => "INDEXED",
         PIPE_STAGES_G => 1,
         TDEST_HIGH_G  => 3,
         TDEST_LOW_G   => 0)
      port map (
         -- Clock and reset
         axisClk      => pgpTxClk,
         axisRst      => pgpTxRst,
         -- Slave         
         sAxisMaster  => txMasterSof,
         sAxisSlave   => txSlaveSof,
         -- Masters
         mAxisMasters => pgpTxMasters,
         mAxisSlaves  => pgpTxSlaves);

end mapping;
