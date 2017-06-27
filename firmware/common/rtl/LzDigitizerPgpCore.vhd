-------------------------------------------------------------------------------
-- File       : LzDigitizerPgpCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-04-26
-------------------------------------------------------------------------------
-- Description: LZ LzDigitizerPgpCore Target's Top Level
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
      clk250           : out sl;
      rst250           : out sl;
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
   signal reset         : slv(1 downto 0);

begin

   axilClk <= clk;
   axilRst <= rst;

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
   -- clkOut(1) - 250.00 MHz
   U_PLL : entity work.ClockManagerUltraScale
      generic map(
         TPD_G             => TPD_G,
         TYPE_G            => "MMCM",
         INPUT_BUFG_G      => true,
         FB_BUFG_G         => true,
         RST_IN_POLARITY_G => '1',
         NUM_CLOCKS_G      => 2,
         -- MMCM attributes
         BANDWIDTH_G          => "OPTIMIZED",
         CLKIN_PERIOD_G       => 6.4,
         DIVCLK_DIVIDE_G      => 10,
         CLKFBOUT_MULT_G      => 64,
         CLKOUT0_DIVIDE_F_G   => 6.4,
         CLKOUT1_DIVIDE_G     => 4
      )
      port map(
         -- Clock Input
         clkIn     => fabClk,
         rstIn     => fabRst,
         -- Clock Outputs
         clkOut(0) => clk,
         clkOut(1) => clk250,
         -- Reset Outputs
         rstOut(0) => reset(0),
         rstOut(1) => rst250
      );

   process(clk)
   begin
      if rising_edge(clk) then
         rst      <= reset(1) after TPD_G;  -- Register to help with timing
         reset(1) <= reset(0) after TPD_G;  -- Register to help with timing
      end if;
   end process;

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
         pgpTxRecClk     => open,
         pgpTxClk        => clk,
         pgpTxMmcmLocked => '1',
         pgpRxReset      => rst,
         pgpRxRecClk     => open,
         pgpRxClk        => clk,
         pgpRxMmcmLocked => '1',
         pgpTxIn         => pgpTxIn,
         pgpTxOut        => pgpTxOut,
         pgpRxIn         => pgpRxIn,
         pgpRxOut        => pgpRxOut,
         pgpTxMasters    => txMasters,
         pgpTxSlaves     => txSlaves,
         pgpRxMasters    => rxMasters,
         pgpRxCtrl       => rxCtrl);

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
         axilReadSlave   => mAxilReadSlave);

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
