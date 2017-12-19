-------------------------------------------------------------------------------
-- File       : LzDigitizerPgpCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-05
-------------------------------------------------------------------------------
-- Description: LZ LzDigitizerPgpCore Target's Top Level
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity LzDigitizerPgpCore is
   generic (
      TPD_G            : time            := 1 ns;
      SIM_SPEEDUP_G    : boolean         := false;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- Clock and Reset
      axilClk          : out sl;
      axilRst          : out sl;
      -- Data Streaming Interface
      dataTxMaster     : in  AxiStreamMasterType;
      dataTxSlave      : out AxiStreamSlaveType;
      -- Microblaze Streaming Interface
      mbTxMaster       : in  AxiStreamMasterType;
      mbTxSlave        : out AxiStreamSlaveType;
      -- AXI-Lite Register Interface
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- Debug AXI-Lite Interface
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Software trigger interface
      swClk            : in  sl;
      swRst            : in  sl;
      swTrigOut        : out sl;
      swArmOut         : out sl;
      syncCmd          : out sl;
      rstCmd           : out sl;
      -- PGP Ports
      pgpClkP          : in  sl;
      pgpClkN          : in  sl;
      pgpRxP           : in  sl;
      pgpRxN           : in  sl;
      pgpTxP           : out sl;
      pgpTxN           : out sl);
end LzDigitizerPgpCore;

architecture top_level of LzDigitizerPgpCore is

   signal txMasters : AxiStreamMasterArray(3 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(3 downto 0);
   signal rxMasters : AxiStreamMasterArray(3 downto 0);
   signal rxCtrl    : AxiStreamCtrlArray(3 downto 0);

   signal pgpTxIn  : Pgp2bTxInType;
   signal pgpTxOut : Pgp2bTxOutType;
   signal pgpRxIn  : Pgp2bRxInType;
   signal pgpRxOut : Pgp2bRxOutType;

   signal pgpRefClk     : sl;
   signal pgpRefClkDiv2 : sl;
   signal fabClk        : sl;
   signal fabRst        : sl;
   signal clk           : sl;
   signal rst           : sl;
   signal reset         : sl;

begin

   axilClk <= clk;

   U_rst : entity work.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => clk,
         rstIn  => rst,
         rstOut => axilRst);

   U_IBUFDS_GTE3 : IBUFDS_GTE3
      generic map (
         REFCLK_EN_TX_PATH  => '0',
         REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
         REFCLK_ICNTL_RX    => "00")
      port map (
         I     => pgpClkP,
         IB    => pgpClkN,
         CEB   => '0',
         ODIV2 => pgpRefClkDiv2,        -- 156.25MHz (Divide by 1)
         O     => pgpRefClk);           -- 156.25MHz

   U_BUFG_GT : BUFG_GT
      port map (
         I       => pgpRefClkDiv2,
         CE      => '1',
         CLR     => '0',
         CEMASK  => '1',
         CLRMASK => '1',
         DIV     => "000",              -- Divide by 1
         O       => fabClk);            -- 156.25MHz (Divide by 1)

   U_PwrUpRst : entity work.PwrUpRst
      generic map (
         TPD_G          => TPD_G,
         SIM_SPEEDUP_G  => SIM_SPEEDUP_G,
         IN_POLARITY_G  => '1',
         OUT_POLARITY_G => '1')
      port map (
         clk    => fabClk,
         rstOut => fabRst);

   -- clkOut(0) - 156.25 MHz
   U_PLL : entity work.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "PLL",
         INPUT_BUFG_G      => true,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 1,
         -- MMCM attributes
         BANDWIDTH_G       => "OPTIMIZED",
         CLKIN_PERIOD_G    => 6.4,
         DIVCLK_DIVIDE_G   => 1,
         CLKFBOUT_MULT_G   => 4,
         CLKOUT0_DIVIDE_G  => 4)
      port map(
         -- Clock Input
         clkIn     => fabClk,
         rstIn     => fabRst,
         -- Clock Outputs
         clkOut(0) => clk,
         -- Reset Outputs
         rstOut(0) => reset);

   U_RstPipeline : entity work.RstPipeline
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => clk,
         rstIn  => reset,
         rstOut => rst);

   U_PGP : entity work.Pgp2bGthUltra
      generic map (
         TPD_G             => TPD_G,
         PAYLOAD_CNT_TOP_G => 7,
         VC_INTERLEAVE_G   => 1,
         NUM_VC_EN_G       => 4)
      port map (
         stableClk       => clk,
         stableRst       => rst,
         gtRefClk        => pgpRefClk,
         pgpGtTxP        => pgpTxP,
         pgpGtTxN        => pgpTxN,
         pgpGtRxP        => pgpRxP,
         pgpGtRxN        => pgpRxN,
         pgpTxReset      => rst,
         pgpTxOutClk     => open,
         pgpTxClk        => clk,
         pgpTxMmcmLocked => '1',
         pgpRxReset      => rst,
         pgpRxOutClk     => open,
         pgpRxClk        => clk,
         pgpRxMmcmLocked => '1',
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         pgpTxMasters    => txMasters,
         pgpTxSlaves     => txSlaves,
         pgpRxMasters    => rxMasters,
         pgpRxCtrl       => rxCtrl,
         axilClk         => '0',
         axilRst         => '0',
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open);

   U_VcMapping : entity work.PgpVcMapping
      generic map (
         TPD_G => TPD_G)
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
         dataTxMaster    => dataTxMaster,
         dataTxSlave     => dataTxSlave,
         -- MB Interface
         mbTxMaster      => mbTxMaster,
         mbTxSlave       => mbTxSlave,
         -- AXI-Lite Interface
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave,
         -- Software trigger interface
         swClk           => swClk,
         swRst           => swRst,
         swTrigOut       => swTrigOut,
         swArmOut        => swArmOut,
         syncCmd         => syncCmd,
         rstCmd          => rstCmd
         );

   U_PgpMon : entity work.Pgp2bAxi
      generic map (
         TPD_G              => TPD_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         COMMON_TX_CLK_G    => true,
         COMMON_RX_CLK_G    => true,
         WRITE_EN_G         => false,
         AXI_CLK_FREQ_G     => 156.25E+6,
         STATUS_CNT_WIDTH_G => 32,
         ERROR_CNT_WIDTH_G  => 16)
      port map (
         -- TX PGP Interface (pgpTxClk)
         pgpTxClk        => clk,
         pgpTxClkRst     => rst,
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         -- RX PGP Interface (pgpRxClk)
         pgpRxClk        => clk,
         pgpRxClkRst     => rst,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         -- AXI-Lite Register Interface (axilClk domain)
         axilClk         => clk,
         axilRst         => rst,
         axilReadMaster  => sAxilReadMaster,
         axilReadSlave   => sAxilReadSlave,
         axilWriteMaster => sAxilWriteMaster,
         axilWriteSlave  => sAxilWriteSlave);

end top_level;
