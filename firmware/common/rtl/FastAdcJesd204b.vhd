-------------------------------------------------------------------------------
-- File       : FastAdcJesd204b.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-09
-- Last update: 2017-10-09
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Common Carrier Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Common Carrier Core', including this file, 
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
use work.Jesd204bPkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity FastAdcJesd204b is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- DRP Interface
      drpClk          : in  slv(JESD_LANE_C-1 downto 0);
      drpRdy          : out slv(JESD_LANE_C-1 downto 0);
      drpEn           : in  slv(JESD_LANE_C-1 downto 0);
      drpWe           : in  slv(JESD_LANE_C-1 downto 0);
      drpAddr         : in  slv(JESD_LANE_C*9-1 downto 0);
      drpDi           : in  slv(JESD_LANE_C*16-1 downto 0);
      drpDo           : out slv(JESD_LANE_C*16-1 downto 0);
      -- AXI interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Sample data output
      sampleDataArr_o : out sampleDataArray(JESD_LANE_C-1 downto 0);
      dataValidVec_o  : out slv(JESD_LANE_C-1 downto 0);
      -------
      -- JESD
      -------
      -- Clocks
      stableClk       : in  sl;  -- GT needs a stable clock to "boot up"(buffered refClkDiv2) 
      refClk          : in  sl;  -- GT Reference clock directly from GT GTH diff. input buffer   
      devClk_i        : in  sl;         -- Device clock also rxUsrClkIn for MGT
      devClk2_i       : in  sl;  -- Device clock divided by 2 also rxUsrClk2In for MGT       
      devRst_i        : in  sl;         -- 
      devClkActive_i  : in  sl := '1';  -- devClk_i MCMM locked      
      -- GTH Ports
      gtTxP           : out slv(JESD_LANE_C-1 downto 0);  -- GT Serial Transmit Positive
      gtTxN           : out slv(JESD_LANE_C-1 downto 0);  -- GT Serial Transmit Negative
      gtRxP           : in  slv(JESD_LANE_C-1 downto 0);  -- GT Serial Receive Positive
      gtRxN           : in  slv(JESD_LANE_C-1 downto 0);  -- GT Serial Receive Negative      
      -- SYSREF for subclass 1 fixed latency
      sysRef_i        : in  sl;
      -- Synchronization output combined from all receivers to be connected to ADC/DAC chips
      nSync_o         : out sl);        -- Active HIGH
end FastAdcJesd204b;

architecture mapping of FastAdcJesd204b is

   component JesdGthFadc
      port (
         gtwiz_userclk_tx_active_in         : in  std_logic_vector(0 downto 0);
         gtwiz_userclk_rx_active_in         : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_reset_in       : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_start_user_in  : in  std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_done_out       : out std_logic_vector(0 downto 0);
         gtwiz_buffbypass_tx_error_out      : out std_logic_vector(0 downto 0);
         gtwiz_reset_clk_freerun_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_all_in                 : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_tx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_pll_and_datapath_in : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_datapath_in         : in  std_logic_vector(0 downto 0);
         gtwiz_reset_rx_cdr_stable_out      : out std_logic_vector(0 downto 0);
         gtwiz_reset_tx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_reset_rx_done_out            : out std_logic_vector(0 downto 0);
         gtwiz_userdata_tx_in               : in  std_logic_vector(511 downto 0);
         gtwiz_userdata_rx_out              : out std_logic_vector(511 downto 0);
         drpaddr_in                         : in  std_logic_vector(143 downto 0);
         drpclk_in                          : in  std_logic_vector(15 downto 0);
         drpdi_in                           : in  std_logic_vector(255 downto 0);
         drpen_in                           : in  std_logic_vector(15 downto 0);
         drpwe_in                           : in  std_logic_vector(15 downto 0);
         gthrxn_in                          : in  std_logic_vector(15 downto 0);
         gthrxp_in                          : in  std_logic_vector(15 downto 0);
         gtrefclk0_in                       : in  std_logic_vector(15 downto 0);
         rx8b10ben_in                       : in  std_logic_vector(15 downto 0);
         rxcommadeten_in                    : in  std_logic_vector(15 downto 0);
         rxmcommaalignen_in                 : in  std_logic_vector(15 downto 0);
         rxpcommaalignen_in                 : in  std_logic_vector(15 downto 0);
         rxpolarity_in                      : in  std_logic_vector(15 downto 0);
         rxusrclk_in                        : in  std_logic_vector(15 downto 0);
         rxusrclk2_in                       : in  std_logic_vector(15 downto 0);
         tx8b10ben_in                       : in  std_logic_vector(15 downto 0);
         txctrl0_in                         : in  std_logic_vector(255 downto 0);
         txctrl1_in                         : in  std_logic_vector(255 downto 0);
         txctrl2_in                         : in  std_logic_vector(127 downto 0);
         txinhibit_in                       : in  std_logic_vector(15 downto 0);
         txusrclk_in                        : in  std_logic_vector(15 downto 0);
         txusrclk2_in                       : in  std_logic_vector(15 downto 0);
         drpdo_out                          : out std_logic_vector(255 downto 0);
         drprdy_out                         : out std_logic_vector(15 downto 0);
         gthtxn_out                         : out std_logic_vector(15 downto 0);
         gthtxp_out                         : out std_logic_vector(15 downto 0);
         gtpowergood_out                    : out std_logic_vector(15 downto 0);
         rxbyteisaligned_out                : out std_logic_vector(15 downto 0);
         rxbyterealign_out                  : out std_logic_vector(15 downto 0);
         rxcommadet_out                     : out std_logic_vector(15 downto 0);
         rxctrl0_out                        : out std_logic_vector(255 downto 0);
         rxctrl1_out                        : out std_logic_vector(255 downto 0);
         rxctrl2_out                        : out std_logic_vector(127 downto 0);
         rxctrl3_out                        : out std_logic_vector(127 downto 0);
         rxoutclk_out                       : out std_logic_vector(15 downto 0);
         rxpmaresetdone_out                 : out std_logic_vector(15 downto 0);
         txoutclk_out                       : out std_logic_vector(15 downto 0);
         txpmaresetdone_out                 : out std_logic_vector(15 downto 0);
         txprgdivresetdone_out              : out std_logic_vector(15 downto 0)
         );
   end component;

   signal r_jesdGtRxArr : jesdGtRxLaneTypeArray(JESD_LANE_C-1 downto 0) := (others => JESD_GT_RX_LANE_INIT_C);

   signal s_allignEnVec   : slv(JESD_LANE_C-1 downto 0)             := (others => '0');
   signal s_dataValidVec  : slv(JESD_LANE_C-1 downto 0)             := (others => '0');
   signal s_sampleDataArr : sampleDataArray(JESD_LANE_C-1 downto 0) := (others => (others => '0'));

   signal s_gtRxUserReset : slv(JESD_LANE_C-1 downto 0) := (others => '0');
   signal s_gtRxReset     : sl                          := '0';
   signal s_gtTxReset     : sl                          := '0';
   signal s_gtResetAll    : sl                          := '0';
   signal s_cdrStable     : sl                          := '0';
   signal s_rxDone        : sl                          := '0';

   signal s_rxctrl0 : slv(JESD_LANE_C*16-1 downto 0) := (others => '0');
   signal s_rxctrl1 : slv(JESD_LANE_C*16-1 downto 0) := (others => '0');
   signal s_rxctrl2 : slv(JESD_LANE_C*8-1 downto 0)  := (others => '0');
   signal s_rxctrl3 : slv(JESD_LANE_C*8-1 downto 0)  := (others => '0');
   signal s_rxData  : slv(JESD_LANE_C*32-1 downto 0) := (others => '0');

   signal s_devClkVec    : slv(JESD_LANE_C-1 downto 0) := (others => '0');
   signal s_devClk2Vec   : slv(JESD_LANE_C-1 downto 0) := (others => '0');
   signal s_stableClkVec : slv(JESD_LANE_C-1 downto 0) := (others => '0');
   signal s_gtRefClkVec  : slv(JESD_LANE_C-1 downto 0) := (others => '0');

   signal dummyVec : slv(146 downto 0) := (others => '0');

begin

   dataValidVec_o  <= s_dataValidVec;
   sampleDataArr_o <= s_sampleDataArr;

   ---------------
   -- JESD RX core
   ---------------
   U_Jesd204bRx : entity work.Jesd204bRx
      generic map (
         TPD_G            => TPD_G,
         TEST_G           => false,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         F_G              => 2,
         K_G              => 32,
         L_G              => JESD_LANE_C)
      port map (
         axiClk          => axilClk,
         axiRst          => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         devClk_i        => devClk_i,
         devRst_i        => devRst_i,
         sysRef_i        => sysRef_i,
         r_jesdGtRxArr   => r_jesdGtRxArr,
         gtRxReset_o     => s_gtRxUserReset,
         sampleDataArr_o => s_sampleDataArr,
         dataValidVec_o  => s_dataValidVec,
         nSync_o         => nSync_o);

   s_gtRxReset  <= devRst_i or uOr(s_gtRxUserReset);
   s_gtTxReset  <= devRst_i;
   s_gtResetAll <= s_gtTxReset or s_gtRxReset;

   RX_LANES_GEN : for i in JESD_LANE_C-1 downto 0 generate
      r_jesdGtRxArr(i).data      <= s_rxData(i*(GT_WORD_SIZE_C*8)+31 downto i*(GT_WORD_SIZE_C*8));
      r_jesdGtRxArr(i).dataK     <= s_rxctrl0(i*16+GT_WORD_SIZE_C-1 downto i*16);
      r_jesdGtRxArr(i).dispErr   <= s_rxctrl1(i*16+GT_WORD_SIZE_C-1 downto i*16);
      r_jesdGtRxArr(i).decErr    <= s_rxctrl3(i*8+GT_WORD_SIZE_C-1 downto i*8);
      r_jesdGtRxArr(i).rstDone   <= s_rxDone;
      r_jesdGtRxArr(i).cdrStable <= s_cdrStable;
      s_devClkVec(i)             <= devClk_i;
      s_devClk2Vec(i)            <= devClk2_i;
      s_stableClkVec(i)          <= stableClk;
      s_gtRefClkVec(i)           <= refClk;
      s_allignEnVec(i)           <= not(s_dataValidVec(i));
   end generate RX_LANES_GEN;

   U_Coregen : JesdGthFadc
      port map (
         gtwiz_userclk_tx_active_in(0)         => devClkActive_i,
         gtwiz_userclk_rx_active_in(0)         => devClkActive_i,
         gtwiz_buffbypass_tx_reset_in(0)       => s_gtTxReset,
         gtwiz_buffbypass_tx_start_user_in(0)  => s_gtTxReset,
         gtwiz_buffbypass_tx_done_out(0)       => dummyVec(146),
         gtwiz_buffbypass_tx_error_out(0)      => dummyVec(145),
         gtwiz_reset_clk_freerun_in(0)         => stableClk,
         gtwiz_reset_all_in(0)                 => s_gtResetAll,
         gtwiz_reset_tx_pll_and_datapath_in(0) => s_gtTxReset,
         gtwiz_reset_tx_datapath_in(0)         => s_gtTxReset,
         gtwiz_reset_rx_pll_and_datapath_in(0) => s_gtRxReset,
         gtwiz_reset_rx_datapath_in(0)         => s_gtRxReset,
         gtwiz_reset_rx_cdr_stable_out(0)      => s_cdrStable,
         gtwiz_reset_tx_done_out(0)            => dummyVec(144),
         gtwiz_reset_rx_done_out(0)            => s_rxDone,
         gtwiz_userdata_tx_in                  => (others => '0'),
         gtwiz_userdata_rx_out                 => s_rxData,
         drpaddr_in                            => drpAddr,
         drpclk_in                             => drpClk,
         drpdi_in                              => drpDi,
         drpen_in                              => drpEn,
         drpwe_in                              => drpWe,
         gthrxn_in                             => gtRxN,
         gthrxp_in                             => gtRxP,
         gtrefclk0_in                          => s_gtRefClkVec,
         rx8b10ben_in                          => (others => '1'),
         rxcommadeten_in                       => (others => '1'),
         rxmcommaalignen_in                    => s_allignEnVec,
         rxpcommaalignen_in                    => s_allignEnVec,
         rxpolarity_in                         => (others => '0'),
         rxusrclk_in                           => s_devClkVec,
         rxusrclk2_in                          => s_devClk2Vec,
         tx8b10ben_in                          => (others => '1'),
         txctrl0_in                            => (others => '0'),
         txctrl1_in                            => (others => '0'),
         txctrl2_in                            => (others => '0'),
         txinhibit_in                          => (others => '1'),  -- Inhibit the TX output from switching
         txusrclk_in                           => s_devClkVec,
         txusrclk2_in                          => s_devClk2Vec,
         drpdo_out                             => drpDo,
         drprdy_out                            => drpRdy,
         gthtxn_out                            => gtTxN,
         gthtxp_out                            => gtTxP,
         gtpowergood_out                       => dummyVec(15 downto 0),
         rxbyteisaligned_out                   => dummyVec(31 downto 16),
         rxbyterealign_out                     => dummyVec(47 downto 32),
         rxcommadet_out                        => dummyVec(63 downto 48),
         rxctrl0_out                           => s_rxctrl0,
         rxctrl1_out                           => s_rxctrl1,
         rxctrl2_out                           => s_rxctrl2,
         rxctrl3_out                           => s_rxctrl3,
         rxoutclk_out                          => dummyVec(79 downto 64),
         rxpmaresetdone_out                    => dummyVec(95 downto 80),
         txoutclk_out                          => dummyVec(111 downto 96),
         txpmaresetdone_out                    => dummyVec(127 downto 112),
         txprgdivresetdone_out                 => dummyVec(143 downto 128));

end mapping;
