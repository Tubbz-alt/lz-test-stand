-------------------------------------------------------------------------------
-- File       : PgpVcMapping.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-01-30
-- Last update: 2017-10-13
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.AxiLitePkg.all;
use work.Pgp2bPkg.all;
use work.SsiCmdMasterPkg.all;

entity PgpVcMapping is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- PGP Clock and Reset
      clk             : in  sl;
      rst             : in  sl;
      -- AXIS interface
      txMasters       : out AxiStreamMasterArray(3 downto 0);
      txSlaves        : in  AxiStreamSlaveArray(3 downto 0);
      rxMasters       : in  AxiStreamMasterArray(3 downto 0);
      rxCtrl          : out AxiStreamCtrlArray(3 downto 0);
      -- Data Interface
      dataTxMaster    : in  AxiStreamMasterType;
      dataTxSlave     : out AxiStreamSlaveType;
      -- PRBS Interface
      prbsTxMaster    : in  AxiStreamMasterType;
      prbsTxSlave     : out AxiStreamSlaveType;
      -- AXI-Lite Interface
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      -- Software trigger interface
      swClk           : in  sl;
      swRst           : in  sl;
      swTrigOut       : out sl;
      swArmOut        : out sl;
      syncCmd         : out sl;
      rstCmd          : out sl
      );
end PgpVcMapping;

architecture mapping of PgpVcMapping is

   signal ssiCmd : SsiCmdMasterType;

begin

   -- VC0 RX/TX, SRPv3 Register Module    
   U_VC0 : entity work.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => false,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk         => clk,
         sAxisRst         => rst,
         sAxisMaster      => rxMasters(0),
         sAxisCtrl        => rxCtrl(0),
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk         => clk,
         mAxisRst         => rst,
         mAxisMaster      => txMasters(0),
         mAxisSlave       => txSlaves(0),
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => clk,
         axilRst          => rst,
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave);

   -- VC1 TX, Data
   U_VC1_TX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => dataTxMaster,
         sAxisSlave  => dataTxSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => txMasters(1),
         mAxisSlave  => txSlaves(1));


   -- VC1 RX, Command processor
   U_VC1_RX : entity work.SsiCmdMaster
      generic map (
         AXI_STREAM_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Streaming Data Interface
         axisClk     => clk,
         axisRst     => rst,
         sAxisMaster => rxMasters(1),
         sAxisSlave  => open,
         sAxisCtrl   => rxCtrl(1),
         -- Command signals
         cmdClk      => swClk,
         cmdRst      => swRst,
         cmdMaster   => ssiCmd
         );
   -- Command opCode x00 - SW trigger
   U_TrigPulser : entity work.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"00",
         -- output pulse to sync module
         syncPulse   => swTrigOut,
         -- Local clock and reset
         locClk      => swClk,
         locRst      => swRst);
   -- Command opCode x01 - SW arm
   U_ArmPulser : entity work.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"01",
         -- output pulse to sync module
         syncPulse   => swArmOut,
         -- Local clock and reset
         locClk      => swClk,
         locRst      => swRst);
   -- Command opCode x02 - global rst
   U_RstPulser : entity work.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"02",
         -- output pulse to sync module
         syncPulse   => rstCmd,
         -- Local clock and reset
         locClk      => swClk,
         locRst      => swRst);
   -- Command opCode x03 - global sync
   U_SyncPulser : entity work.SsiCmdMasterPulser
      generic map (
         TPD_G          => TPD_G,
         OUT_POLARITY_G => '1',
         PULSE_WIDTH_G  => 1)
      port map (
         -- Local command signal
         cmdSlaveOut => ssiCmd,
         --addressed cmdOpCode
         opCode      => x"03",
         -- output pulse to sync module
         syncPulse   => syncCmd,
         -- Local clock and reset
         locClk      => swClk,
         locRst      => swRst);
   
   -- VC2 TX, PRBS
   rxCtrl(2) <= AXI_STREAM_CTRL_UNUSED_C;
   U_VC2 : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4, TKEEP_COMP_C),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => prbsTxMaster,
         sAxisSlave  => prbsTxSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => txMasters(2),
         mAxisSlave  => txSlaves(2));

   -- VC3 TX, Loopback
   U_VC3 : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => rxMasters(3),
         sAxisCtrl   => rxCtrl(3),
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => txMasters(3),
         mAxisSlave  => txSlaves(3));

end mapping;
