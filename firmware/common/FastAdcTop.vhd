-------------------------------------------------------------------------------
-- File       : FastAdcTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-05
-------------------------------------------------------------------------------
-- Description: LZ FastAdcTop Top Level
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

library unisim;
use unisim.vcomponents.all;

entity FastAdcTop is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C
   );
   port (
      
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
      
      gTime             : in  slv(63 downto 0);
      
      -- AXIL buf for register access
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType
   
   );
end FastAdcTop;

architecture rtl of FastAdcTop is

   
   component JesdGthFadc
   Port ( 
      gtwiz_userclk_tx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_userclk_rx_active_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_reset_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_start_user_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_error_out : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_clk_freerun_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_all_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_tx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_tx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_pll_and_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_datapath_in : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_cdr_stable_out : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_tx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_done_out : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_userdata_tx_in : in STD_LOGIC_VECTOR ( 511 downto 0 );
      gtwiz_userdata_rx_out : out STD_LOGIC_VECTOR ( 511 downto 0 );
      drpaddr_in : in STD_LOGIC_VECTOR ( 143 downto 0 );
      drpclk_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      drpdi_in : in STD_LOGIC_VECTOR ( 255 downto 0 );
      drpen_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      drpwe_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      gthrxn_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      gthrxp_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      gtrefclk0_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      loopback_in : in STD_LOGIC_VECTOR ( 47 downto 0 );
      rx8b10ben_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxcommadeten_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxmcommaalignen_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxpcommaalignen_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxpd_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
      rxpolarity_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxusrclk_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxusrclk2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      tx8b10ben_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txctrl0_in : in STD_LOGIC_VECTOR ( 255 downto 0 );
      txctrl1_in : in STD_LOGIC_VECTOR ( 255 downto 0 );
      txctrl2_in : in STD_LOGIC_VECTOR ( 127 downto 0 );
      txdiffctrl_in : in STD_LOGIC_VECTOR ( 63 downto 0 );
      txinhibit_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txpd_in : in STD_LOGIC_VECTOR ( 31 downto 0 );
      txpolarity_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txpostcursor_in : in STD_LOGIC_VECTOR ( 79 downto 0 );
      txprecursor_in : in STD_LOGIC_VECTOR ( 79 downto 0 );
      txusrclk_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txusrclk2_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
      drpdo_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
      drprdy_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      gthtxn_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      gthtxp_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxbyteisaligned_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxbyterealign_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxcommadet_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxctrl0_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
      rxctrl1_out : out STD_LOGIC_VECTOR ( 255 downto 0 );
      rxctrl2_out : out STD_LOGIC_VECTOR ( 127 downto 0 );
      rxctrl3_out : out STD_LOGIC_VECTOR ( 127 downto 0 );
      rxoutclk_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxpmaresetdone_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      txoutclk_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      txpmaresetdone_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
      txprgdivresetdone_out : out STD_LOGIC_VECTOR ( 15 downto 0 )
   );
   end component;

   constant NUM_AXI_MASTERS_C : natural := 18;
   
   constant LMK_INDEX_C       : natural := 0;
   constant FADCONF_INDEX_C   : natural := 1;
   constant GTHDRP0_INDEX_C   : natural := 2;
   constant GTHDRP1_INDEX_C   : natural := 3;
   constant GTHDRP2_INDEX_C   : natural := 4;
   constant GTHDRP3_INDEX_C   : natural := 5;
   constant GTHDRP4_INDEX_C   : natural := 6;
   constant GTHDRP5_INDEX_C   : natural := 7;
   constant GTHDRP6_INDEX_C   : natural := 8;
   constant GTHDRP7_INDEX_C   : natural := 9;
   constant GTHDRP8_INDEX_C   : natural := 10;
   constant GTHDRP9_INDEX_C   : natural := 11;
   constant GTHDRP10_INDEX_C  : natural := 12;
   constant GTHDRP11_INDEX_C  : natural := 13;
   constant GTHDRP12_INDEX_C  : natural := 14;
   constant GTHDRP13_INDEX_C  : natural := 15;
   constant GTHDRP14_INDEX_C  : natural := 16;
   constant GTHDRP15_INDEX_C  : natural := 17;
   
   function CrossbarConfigInit return AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) is
      variable temp : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0);
   begin
     forLoop: for i in 0 to NUM_AXI_MASTERS_C-1 loop
       temp(i).baseAddr := std_logic_vector(to_unsigned(i * 2**23, 32));
       temp(i).addrBits := 23;
       temp(i).connectivity := x"FFFF";
     end loop;

     return temp;
   end function CrossbarConfigInit;
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := CrossbarConfigInit;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   signal lmkDataIn     : sl;
   signal lmkDataOut    : sl;
   signal lmkRefOut     : sl;
   
   signal sysRefClk     : sl;
   signal sysRefClkVec  : slv(15 downto 0);
   
   signal drpRdy  : slv(15 downto 0)      := (others => '0');
   signal drpEn   : slv(15 downto 0)      := (others => '0');
   signal drpWe   : slv(15 downto 0)      := (others => '0');
   signal drpAddr : slv(16*9-1 downto 0)  := (others => '0');
   signal drpDi   : slv(16*16-1 downto 0) := (others => '0');
   signal drpDo   : slv(16*16-1 downto 0) := (others => '0');

begin
   
   
   U_IBUFDS_GTE3 : IBUFDS_GTE3
   generic map (
      REFCLK_EN_TX_PATH  => '0',
      REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
      REFCLK_ICNTL_RX    => "00")
   port map (
      I     => sysRefClkP,
      IB    => sysRefClkN,
      CEB   => '0',
      ODIV2 => open,
      O     => sysRefClk
   );
   
   sysRefClkVec <= (others=>sysRefClk);
   
   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR : entity work.AxiLiteCrossbar
   generic map (
      TPD_G              => TPD_G,
      DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
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
      mAxiReadSlaves      => axilReadSlaves
   );
   
   ---------------------------------------------------
   -- 1 GSPS ADC LMK SPI Module
   ---------------------------------------------------   
   U_SPI_LMK : entity work.AxiSpiMaster
   generic map (
      TPD_G             => TPD_G,
      AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
      ADDRESS_SIZE_G    => 15,
      DATA_SIZE_G       => 8,
      CLK_PERIOD_G      => (1.0/156.25E+6),
      SPI_SCLK_PERIOD_G => 1.0E-6
   )
   port map (
      axiClk         => axilClk,
      axiRst         => axilRst,
      axiReadMaster  => axilReadMasters(LMK_INDEX_C),
      axiReadSlave   => axilReadSlaves(LMK_INDEX_C),
      axiWriteMaster => axilWriteMasters(LMK_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(LMK_INDEX_C),
      coreSclk       => lmkSck,
      coreSDin       => lmkDataIn,
      coreSDout      => lmkDataOut,
      coreCsb        => lmkCs
   );
   
   lmkReset <= '0';
   lmkSync  <= '0';
   
   U_IOBUF_Lmk : IOBUF
   port map (
      I  => '0',
      O  => lmkDataIn,
      IO => lmkSdio,
      T  => lmkDataOut
   );
   
   -- LMK reference clock output
   U_LmkRefClk : entity work.ClkOutBufDiff
   generic map (
      XIL_DEVICE_G => "ULTRASCALE"
   )
   port map (
      clkIn   => lmkRefOut,
      clkOutP => lmkRefClkP,
      clkOutN => lmkRefClkN
   );
   
   ----------------------------------------------------
   -- 1 GSPS ADCs configuration SPI
   ----------------------------------------------------
   U_FADC_SPI_Conf: entity work.AxiSpiMaster
   generic map (
      ADDRESS_SIZE_G    => 15,
      DATA_SIZE_G       => 8,
      CLK_PERIOD_G      => 6.4E-9,
      SPI_SCLK_PERIOD_G => 1.0E-6,
      SPI_NUM_CHIPS_G   => 4
   )
   port map (
      axiClk         => axilClk,
      axiRst         => axilRst,
      axiReadMaster  => axilReadMasters(FADCONF_INDEX_C),
      axiReadSlave   => axilReadSlaves(FADCONF_INDEX_C),
      axiWriteMaster => axilWriteMasters(FADCONF_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(FADCONF_INDEX_C),
      coreSclk       => fadcSclk,
      coreSDin       => fadcSdout,
      coreSDout      => fadcSdin,
      coreMCsb       => fadcSen
   );
   
   ----------------------------------------------------
   -- 1 GSPS ADCs GTH core
   ----------------------------------------------------
   U_JesdGthFadc: JesdGthFadc
   port map ( 
      gtwiz_userclk_tx_active_in             : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_userclk_rx_active_in             : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_reset_in           : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_start_user_in      : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_done_out           : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_buffbypass_tx_error_out          : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_clk_freerun_in             : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_all_in                     : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_tx_pll_and_datapath_in     : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_tx_datapath_in             : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_pll_and_datapath_in     : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_datapath_in             : in STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_cdr_stable_out          : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_tx_done_out                : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_reset_rx_done_out                : out STD_LOGIC_VECTOR ( 0 to 0 );
      gtwiz_userdata_tx_in                   : in STD_LOGIC_VECTOR ( 511 downto 0 );
      gtwiz_userdata_rx_out                  : out STD_LOGIC_VECTOR ( 511 downto 0 );
      drpaddr_in                             => drpAddr,
      drpclk_in                              => axilClk,
      drpdi_in                               => drpDi,
      drpen_in                               => drpEn,
      drpwe_in                               => drpWe,
      gthrxn_in                              : in STD_LOGIC_VECTOR ( 15 downto 0 );
      gthrxp_in                              : in STD_LOGIC_VECTOR ( 15 downto 0 );
      gtrefclk0_in                           => sysRefClkVec,
      loopback_in                            : in STD_LOGIC_VECTOR ( 47 downto 0 );
      rx8b10ben_in                           : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxcommadeten_in                        : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxmcommaalignen_in                     : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxpcommaalignen_in                     : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxpd_in                                : in STD_LOGIC_VECTOR ( 31 downto 0 );
      rxpolarity_in                          : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxusrclk_in                            : in STD_LOGIC_VECTOR ( 15 downto 0 );
      rxusrclk2_in                           : in STD_LOGIC_VECTOR ( 15 downto 0 );
      tx8b10ben_in                           : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txctrl0_in                             : in STD_LOGIC_VECTOR ( 255 downto 0 );
      txctrl1_in                             : in STD_LOGIC_VECTOR ( 255 downto 0 );
      txctrl2_in                             : in STD_LOGIC_VECTOR ( 127 downto 0 );
      txdiffctrl_in                          : in STD_LOGIC_VECTOR ( 63 downto 0 );
      txinhibit_in                           : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txpd_in                                : in STD_LOGIC_VECTOR ( 31 downto 0 );
      txpolarity_in                          : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txpostcursor_in                        : in STD_LOGIC_VECTOR ( 79 downto 0 );
      txprecursor_in                         : in STD_LOGIC_VECTOR ( 79 downto 0 );
      txusrclk_in                            : in STD_LOGIC_VECTOR ( 15 downto 0 );
      txusrclk2_in                           : in STD_LOGIC_VECTOR ( 15 downto 0 );
      drpdo_out                              => drpDo,
      drprdy_out                             => drpRdy,
      gthtxn_out                             : out STD_LOGIC_VECTOR ( 15 downto 0 );
      gthtxp_out                             : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxbyteisaligned_out                    : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxbyterealign_out                      : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxcommadet_out                         : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxctrl0_out                            : out STD_LOGIC_VECTOR ( 255 downto 0 );
      rxctrl1_out                            : out STD_LOGIC_VECTOR ( 255 downto 0 );
      rxctrl2_out                            : out STD_LOGIC_VECTOR ( 127 downto 0 );
      rxctrl3_out                            : out STD_LOGIC_VECTOR ( 127 downto 0 );
      rxoutclk_out                           : out STD_LOGIC_VECTOR ( 15 downto 0 );
      rxpmaresetdone_out                     : out STD_LOGIC_VECTOR ( 15 downto 0 );
      txoutclk_out                           : out STD_LOGIC_VECTOR ( 15 downto 0 );
      txpmaresetdone_out                     : out STD_LOGIC_VECTOR ( 15 downto 0 );
      txprgdivresetdone_out                  : out STD_LOGIC_VECTOR ( 15 downto 0 )
   );
   
   ----------------------------------------------------
   -- 1 GSPS ADCs GTH core DRP interface
   ----------------------------------------------------
   
   GEN_GTH_DRP : for i in 15 downto 0 generate
      U_AxiLiteToDrp : entity work.AxiLiteToDrp
      generic map (
         TPD_G            => TPD_G,
         COMMON_CLK_G     => true,
         EN_ARBITRATION_G => false,
         TIMEOUT_G        => 4096,
         ADDR_WIDTH_G     => 9,
         DATA_WIDTH_G     => 16
      )
      port map (
         -- AXI-Lite Port
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(GTHDRP0_INDEX_C+i),
         axilReadSlave   => axilReadSlaves(GTHDRP0_INDEX_C+i),
         axilWriteMaster => axilWriteMasters(GTHDRP0_INDEX_C+i),
         axilWriteSlave  => axilWriteSlaves(GTHDRP0_INDEX_C+i),
         -- DRP Interface
         drpClk          => axilClk,
         drpRst          => axilRst,
         drpRdy          => drpRdy(i),
         drpEn           => drpEn(i),
         drpWe           => drpWe(i),
         drpAddr         => drpAddr((i*9)+8 downto (i*9)),
         drpDi           => drpDi((i*16)+15 downto (i*16)),
         drpDo           => drpDo((i*16)+15 downto (i*16))
      );

   end generate GEN_GTH_DRP;
   

end rtl;
