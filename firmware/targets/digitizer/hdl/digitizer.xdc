##############################################################################
## This file is part of 'LZ Test Stand Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LZ Test Stand Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

##########################
## Timing Constraints   ##
##########################

create_clock -name pgpClkP   -period 6.400 [get_ports {pgpClkP}]
create_clock -name clkInP    -period 4.000 [get_ports {clkInP}]
create_clock -name ddrClkP   -period 5.000 [get_ports {c0_sys_clk_p}]
create_clock -name sadc0ClkP -period 4.000 [get_ports {sadcClkFbP[0]}]
create_clock -name sadc1ClkP -period 4.000 [get_ports {sadcClkFbP[1]}]
create_clock -name sadc2ClkP -period 4.000 [get_ports {sadcClkFbP[2]}]
create_clock -name sadc3ClkP -period 4.000 [get_ports {sadcClkFbP[3]}]

create_generated_clock -name adcClk     [get_pins {U_Core/U_PLL/PllGen.U_Pll/CLKOUT0}]
create_generated_clock -name lmkRefClk  [get_pins {U_Core/U_PLL/PllGen.U_Pll/CLKOUT1}]

create_generated_clock -name axilClk    [get_pins {U_PGP/U_PLL/PllGen.U_Pll/CLKOUT0}]
create_generated_clock -name ddrIntClk0 [get_pins {U_Core/U_DDR/U_MigCore/inst/u_ddr4_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT0}]
create_generated_clock -name ddrIntClk1 [get_pins {U_Core/U_DDR/U_MigCore/inst/u_ddr4_infrastructure/gen_mmcme3.u_mmcme_adv_inst/CLKOUT6}]

set_clock_groups -asynchronous \
   -group [get_clocks -include_generated_clocks {pgpClkP}] \
   -group [get_clocks -include_generated_clocks {clkInP}] \
   -group [get_clocks -include_generated_clocks {ddrClkP}] \
   -group [get_clocks -include_generated_clocks {sadc0ClkP}] \
   -group [get_clocks -include_generated_clocks {sadc1ClkP}] \
   -group [get_clocks -include_generated_clocks {sadc2ClkP}] \
   -group [get_clocks -include_generated_clocks {sadc3ClkP}]

set_clock_groups -asynchronous -group [get_clocks {adcClk}]    -group [get_clocks {clkInP}]
set_clock_groups -asynchronous -group [get_clocks {lmkRefClk}] -group [get_clocks {clkInP}]

set_clock_groups -asynchronous -group [get_clocks {ddrIntClk0}] -group [get_clocks {ddrClkP}]
set_clock_groups -asynchronous -group [get_clocks {ddrIntClk1}] -group [get_clocks {ddrClkP}]

set_case_analysis 1 [get_pins {U_Core/U_LztsSynchronizer/U_BUFGMUX_1/S}]

# Lock slow ADC interfaces to clock regions to avoid timing changes that require to re-train the ADC
# Can comment out temporarily to find better placement if it causes timing closure issues
set_property CLOCK_REGION X0Y4 [get_cells U_SadcPhy/GEN_VEC[0].U_Phy/AxiAds42lb69Deser_Inst/AxiAds42lb69Pll_Inst/GEN_ULTRASCALE_NO_PLL.BUFG_1]
set_property CLOCK_REGION X2Y3 [get_cells U_SadcPhy/GEN_VEC[1].U_Phy/AxiAds42lb69Deser_Inst/AxiAds42lb69Pll_Inst/GEN_ULTRASCALE_NO_PLL.BUFG_1]
set_property CLOCK_REGION X2Y4 [get_cells U_SadcPhy/GEN_VEC[2].U_Phy/AxiAds42lb69Deser_Inst/AxiAds42lb69Pll_Inst/GEN_ULTRASCALE_NO_PLL.BUFG_1]
set_property CLOCK_REGION X2Y2 [get_cells U_SadcPhy/GEN_VEC[3].U_Phy/AxiAds42lb69Deser_Inst/AxiAds42lb69Pll_Inst/GEN_ULTRASCALE_NO_PLL.BUFG_1]

############################
## Pinout Configuration   ##
############################

set_property PACKAGE_PIN V6  [get_ports {pgpClkP}]
set_property PACKAGE_PIN V5  [get_ports {pgpClkN}]
set_property PACKAGE_PIN AA4 [get_ports pgpTxP]
set_property PACKAGE_PIN AA3 [get_ports pgpTxN]
set_property PACKAGE_PIN Y2  [get_ports pgpRxP]
set_property PACKAGE_PIN Y1  [get_ports pgpRxN]

set_property PACKAGE_PIN AA24 [get_ports {clkInP}]
set_property PACKAGE_PIN AA25 [get_ports {clkInN}]
set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {clkInP}]
set_property PACKAGE_PIN Y23  [get_ports {cmdInP}]
set_property PACKAGE_PIN AA23 [get_ports {cmdInN}]
set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {cmdInP}]

set_property PACKAGE_PIN AC22 [get_ports {clkOutP}]
set_property PACKAGE_PIN AC23 [get_ports {clkOutN}]
set_property -dict { IOSTANDARD LVDS } [get_ports {clkOutP}]
set_property PACKAGE_PIN AA22 [get_ports {cmdOutP}]
set_property PACKAGE_PIN AB22 [get_ports {cmdOutN}]
set_property -dict { IOSTANDARD LVDS } [get_ports {cmdOutP}]

set_property PACKAGE_PIN K20 [get_ports {leds[0]}]
set_property PACKAGE_PIN K21 [get_ports {leds[1]}]
set_property PACKAGE_PIN K22 [get_ports {leds[2]}]
set_property PACKAGE_PIN N21 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds*}] 

set_property PACKAGE_PIN AF9  [get_ports {pwrCtrlOut[enDcDcAm6V]}]
set_property PACKAGE_PIN AG10 [get_ports {pwrCtrlOut[enDcDcAp5V4]}]
set_property PACKAGE_PIN AF10 [get_ports {pwrCtrlOut[enDcDcAp3V7]}]
set_property PACKAGE_PIN AJ10 [get_ports {pwrCtrlOut[enDcDcAp2V3]}]
set_property PACKAGE_PIN AG9  [get_ports {pwrCtrlOut[enDcDcAp1V6]}]
set_property PACKAGE_PIN AH11 [get_ports {pwrCtrlOut[enLdoSlow]}]
set_property PACKAGE_PIN AJ11 [get_ports {pwrCtrlOut[enLdoFast]}]
set_property PACKAGE_PIN AG11 [get_ports {pwrCtrlOut[enLdoAm5V]}]
set_property PACKAGE_PIN AK12 [get_ports {pwrCtrlOut[syncDcDcDp6V]}]
set_property PACKAGE_PIN AL12 [get_ports {pwrCtrlOut[syncDcDcAp6V]}]
set_property PACKAGE_PIN AG12 [get_ports {pwrCtrlOut[syncDcDcAm6V]}]
set_property PACKAGE_PIN AE12 [get_ports {pwrCtrlOut[syncDcDcAp5V4]}]
set_property PACKAGE_PIN AE11 [get_ports {pwrCtrlOut[syncDcDcAp3V7]}]
set_property PACKAGE_PIN AD11 [get_ports {pwrCtrlOut[syncDcDcAp2V3]}]
set_property PACKAGE_PIN AH12 [get_ports {pwrCtrlOut[syncDcDcAp1V6]}]
set_property PACKAGE_PIN AL13 [get_ports {pwrCtrlOut[syncDcDcDp3V3]}]
set_property PACKAGE_PIN AK13 [get_ports {pwrCtrlOut[syncDcDcDp1V8]}]
set_property PACKAGE_PIN AF13 [get_ports {pwrCtrlOut[syncDcDcDp1V2]}]
set_property PACKAGE_PIN AF12 [get_ports {pwrCtrlOut[syncDcDcDp0V95]}]
set_property PACKAGE_PIN AH13 [get_ports {pwrCtrlOut[syncDcDcMgt1V0]}]
set_property PACKAGE_PIN AJ13 [get_ports {pwrCtrlOut[syncDcDcMgt1V2]}]
set_property PACKAGE_PIN AE13 [get_ports {pwrCtrlOut[syncDcDcMgt1V8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pwrCtrlOut[*}] 

set_property PACKAGE_PIN AM9  [get_ports {pwrCtrlIn[pokDcDcDp6V]}]
set_property PACKAGE_PIN AJ9  [get_ports {pwrCtrlIn[pokDcDcAp6V]}]
set_property PACKAGE_PIN AK8  [get_ports {pwrCtrlIn[pokDcDcAm6V]}]
set_property PACKAGE_PIN AJ8  [get_ports {pwrCtrlIn[pokDcDcAp5V4]}]
set_property PACKAGE_PIN AN8  [get_ports {pwrCtrlIn[pokDcDcAp3V7]}]
set_property PACKAGE_PIN AP8  [get_ports {pwrCtrlIn[pokDcDcAp2V3]}]
set_property PACKAGE_PIN AK10 [get_ports {pwrCtrlIn[pokDcDcAp1V6]}]
set_property PACKAGE_PIN AL9  [get_ports {pwrCtrlIn[pokLdoA0p1V8]}]
set_property PACKAGE_PIN AN9  [get_ports {pwrCtrlIn[pokLdoA0p3V3]}]
set_property PACKAGE_PIN AP9  [get_ports {pwrCtrlIn[pokLdoAd1p1V2]}]
set_property PACKAGE_PIN AL10 [get_ports {pwrCtrlIn[pokLdoAd2p1V2]}]
set_property PACKAGE_PIN AM10 [get_ports {pwrCtrlIn[pokLdoA1p1V9]}]
set_property PACKAGE_PIN AH9  [get_ports {pwrCtrlIn[pokLdoA2p1V9]}]
set_property PACKAGE_PIN AH8  [get_ports {pwrCtrlIn[pokLdoAd1p1V9]}]
set_property PACKAGE_PIN AD9  [get_ports {pwrCtrlIn[pokLdoAd2p1V9]}]
set_property PACKAGE_PIN AD8  [get_ports {pwrCtrlIn[pokLdoA1p3V3]}]
set_property PACKAGE_PIN AD10 [get_ports {pwrCtrlIn[pokLdoA2p3V3]}]
set_property PACKAGE_PIN AE10 [get_ports {pwrCtrlIn[pokLdoAvclkp3V3]}]
set_property PACKAGE_PIN AE8  [get_ports {pwrCtrlIn[pokLdoA0p5V0]}]
set_property PACKAGE_PIN AF8  [get_ports {pwrCtrlIn[pokLdoA1p5V0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pwrCtrlIn[*}] 

set_property PACKAGE_PIN B17 [get_ports {sadcCtrl1[0]}]
set_property PACKAGE_PIN B16 [get_ports {sadcCtrl1[1]}]
set_property PACKAGE_PIN C19 [get_ports {sadcCtrl1[2]}]
set_property PACKAGE_PIN B19 [get_ports {sadcCtrl1[3]}]
set_property PACKAGE_PIN B15 [get_ports {sadcCtrl2[0]}]
set_property PACKAGE_PIN A15 [get_ports {sadcCtrl2[1]}]
set_property PACKAGE_PIN A19 [get_ports {sadcCtrl2[2]}]
set_property PACKAGE_PIN A18 [get_ports {sadcCtrl2[3]}]
set_property PACKAGE_PIN AC28 [get_ports {sadcSclk}]
set_property PACKAGE_PIN AE28 [get_ports {sadcSDin}]
set_property PACKAGE_PIN AD28 [get_ports {sadcSDout}]
set_property PACKAGE_PIN AD29 [get_ports {sadcCsb[0]}]
set_property PACKAGE_PIN AE30 [get_ports {sadcCsb[1]}]
set_property PACKAGE_PIN AF29 [get_ports {sadcCsb[2]}]
set_property PACKAGE_PIN AG29 [get_ports {sadcCsb[3]}]
set_property PACKAGE_PIN D28 [get_ports {sadcRst[0]}]
set_property PACKAGE_PIN C28 [get_ports {sadcRst[1]}]
set_property PACKAGE_PIN B29 [get_ports {sadcRst[2]}]
set_property PACKAGE_PIN A29 [get_ports {sadcRst[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sadc*}] 

set_property PACKAGE_PIN AD30 [get_ports {sadcClkFbP[0]}]
set_property PACKAGE_PIN V31  [get_ports {sadcDataP[0][0]}]
set_property PACKAGE_PIN U34  [get_ports {sadcDataP[0][1]}]
set_property PACKAGE_PIN Y31  [get_ports {sadcDataP[0][2]}]
set_property PACKAGE_PIN V33  [get_ports {sadcDataP[0][3]}]
set_property PACKAGE_PIN W30  [get_ports {sadcDataP[0][4]}]
set_property PACKAGE_PIN W33  [get_ports {sadcDataP[0][5]}]
set_property PACKAGE_PIN AC33 [get_ports {sadcDataP[0][6]}]
set_property PACKAGE_PIN AA34 [get_ports {sadcDataP[0][7]}]
set_property PACKAGE_PIN AA29 [get_ports {sadcDataP[0][8]}]
set_property PACKAGE_PIN AC34 [get_ports {sadcDataP[0][9]}]
set_property PACKAGE_PIN AB30 [get_ports {sadcDataP[0][10]}]
set_property PACKAGE_PIN AE33 [get_ports {sadcDataP[0][11]}]
set_property PACKAGE_PIN AE32 [get_ports {sadcDataP[0][12]}]
set_property PACKAGE_PIN AF33 [get_ports {sadcDataP[0][13]}]
set_property PACKAGE_PIN AG31 [get_ports {sadcDataP[0][14]}]
set_property PACKAGE_PIN AF30 [get_ports {sadcDataP[0][15]}]
set_property PACKAGE_PIN AA32 [get_ports {sadcClkP[0]}]
set_property PACKAGE_PIN AC31 [get_ports {sadcSyncP[0]}]

set_property PACKAGE_PIN E25 [get_ports {sadcClkFbP[1]}]
set_property PACKAGE_PIN H21 [get_ports {sadcDataP[1][0]}]
set_property PACKAGE_PIN G22 [get_ports {sadcDataP[1][1]}]
set_property PACKAGE_PIN G20 [get_ports {sadcDataP[1][2]}]
set_property PACKAGE_PIN F23 [get_ports {sadcDataP[1][3]}]
set_property PACKAGE_PIN E20 [get_ports {sadcDataP[1][4]}]
set_property PACKAGE_PIN G24 [get_ports {sadcDataP[1][5]}]
set_property PACKAGE_PIN D20 [get_ports {sadcDataP[1][6]}]
set_property PACKAGE_PIN B20 [get_ports {sadcDataP[1][7]}]
set_property PACKAGE_PIN C21 [get_ports {sadcDataP[1][8]}]
set_property PACKAGE_PIN B21 [get_ports {sadcDataP[1][9]}]
set_property PACKAGE_PIN E22 [get_ports {sadcDataP[1][10]}]
set_property PACKAGE_PIN B24 [get_ports {sadcDataP[1][11]}]
set_property PACKAGE_PIN C26 [get_ports {sadcDataP[1][12]}]
set_property PACKAGE_PIN B25 [get_ports {sadcDataP[1][13]}]
set_property PACKAGE_PIN E26 [get_ports {sadcDataP[1][14]}]
set_property PACKAGE_PIN A27 [get_ports {sadcDataP[1][15]}]
set_property PACKAGE_PIN D23 [get_ports {sadcClkP[1]}]
set_property PACKAGE_PIN D24 [get_ports {sadcSyncP[1]}]

set_property PACKAGE_PIN E16 [get_ports {sadcClkFbP[2]}]
set_property PACKAGE_PIN L19 [get_ports {sadcDataP[2][0]}]
set_property PACKAGE_PIN K16 [get_ports {sadcDataP[2][1]}]
set_property PACKAGE_PIN J19 [get_ports {sadcDataP[2][2]}]
set_property PACKAGE_PIN L15 [get_ports {sadcDataP[2][3]}]
set_property PACKAGE_PIN K18 [get_ports {sadcDataP[2][4]}]
set_property PACKAGE_PIN J15 [get_ports {sadcDataP[2][5]}]
set_property PACKAGE_PIN H19 [get_ports {sadcDataP[2][6]}]
set_property PACKAGE_PIN H17 [get_ports {sadcDataP[2][7]}]
set_property PACKAGE_PIN G19 [get_ports {sadcDataP[2][8]}]
set_property PACKAGE_PIN G15 [get_ports {sadcDataP[2][9]}]
set_property PACKAGE_PIN F18 [get_ports {sadcDataP[2][10]}]
set_property PACKAGE_PIN D19 [get_ports {sadcDataP[2][11]}]
set_property PACKAGE_PIN F15 [get_ports {sadcDataP[2][12]}]
set_property PACKAGE_PIN E15 [get_ports {sadcDataP[2][13]}]
set_property PACKAGE_PIN D14 [get_ports {sadcDataP[2][14]}]
set_property PACKAGE_PIN C18 [get_ports {sadcDataP[2][15]}]
set_property PACKAGE_PIN G17 [get_ports {sadcClkP[2]}]
set_property PACKAGE_PIN E18 [get_ports {sadcSyncP[2]}]

set_property PACKAGE_PIN G9  [get_ports {sadcClkFbP[3]}]
set_property PACKAGE_PIN D13 [get_ports {sadcDataP[3][0]}]
set_property PACKAGE_PIN A13 [get_ports {sadcDataP[3][1]}]
set_property PACKAGE_PIN F13 [get_ports {sadcDataP[3][2]}]
set_property PACKAGE_PIN C11 [get_ports {sadcDataP[3][3]}]
set_property PACKAGE_PIN C12 [get_ports {sadcDataP[3][4]}]
set_property PACKAGE_PIN E11 [get_ports {sadcDataP[3][5]}]
set_property PACKAGE_PIN J13 [get_ports {sadcDataP[3][6]}]
set_property PACKAGE_PIN L12 [get_ports {sadcDataP[3][7]}]
set_property PACKAGE_PIN L13 [get_ports {sadcDataP[3][8]}]
set_property PACKAGE_PIN K11 [get_ports {sadcDataP[3][9]}]
set_property PACKAGE_PIN H12 [get_ports {sadcDataP[3][10]}]
set_property PACKAGE_PIN K10 [get_ports {sadcDataP[3][11]}]
set_property PACKAGE_PIN J8  [get_ports {sadcDataP[3][12]}]
set_property PACKAGE_PIN J9  [get_ports {sadcDataP[3][13]}]
set_property PACKAGE_PIN L8  [get_ports {sadcDataP[3][14]}]
set_property PACKAGE_PIN E10 [get_ports {sadcDataP[3][15]}]
set_property PACKAGE_PIN H11 [get_ports {sadcClkP[3]}]
set_property PACKAGE_PIN G10 [get_ports {sadcSyncP[3]}]

set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {sadcClkFbP[*]}]
set_property -dict { IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {sadcDataP[*][*]}]
set_property -dict { IOSTANDARD LVDS } [get_ports {sadcClkP[*]}]
set_property -dict { IOSTANDARD LVDS } [get_ports {sadcSyncP[*]}]

set_property PACKAGE_PIN L24 [get_ports {sampEn[0]}]
set_property PACKAGE_PIN L23 [get_ports {sampEn[1]}]
set_property PACKAGE_PIN K25 [get_ports {sampEn[2]}]
set_property PACKAGE_PIN L25 [get_ports {sampEn[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sampEn*}] 

set_property PACKAGE_PIN T6  [get_ports {jesdClkP}]
set_property PACKAGE_PIN T5  [get_ports {jesdClkN}]

###################################################
#                      BANK228                    #
###################################################

set_property PACKAGE_PIN D6 [get_ports jesdTxP[0]]
set_property PACKAGE_PIN D5 [get_ports jesdTxN[0]]
set_property PACKAGE_PIN D2 [get_ports jesdRxP[0]]; # JESD0_DA1P
set_property PACKAGE_PIN D1 [get_ports jesdRxN[0]]; # JESD0_DA1M

set_property PACKAGE_PIN F6 [get_ports jesdTxP[1]]
set_property PACKAGE_PIN F5 [get_ports jesdTxN[1]]
set_property PACKAGE_PIN E4 [get_ports jesdRxP[1]]; # JESD0_DA2P
set_property PACKAGE_PIN E3 [get_ports jesdRxN[1]]; # JESD0_DA2M

set_property PACKAGE_PIN B6 [get_ports jesdTxP[2]]
set_property PACKAGE_PIN B5 [get_ports jesdTxN[2]]
set_property PACKAGE_PIN A4 [get_ports jesdRxP[2]]; # JESD0_DB1P
set_property PACKAGE_PIN A3 [get_ports jesdRxN[2]]; # JESD0_DB1M

set_property PACKAGE_PIN C4 [get_ports jesdTxP[3]]
set_property PACKAGE_PIN C3 [get_ports jesdTxN[3]]
set_property PACKAGE_PIN B2 [get_ports jesdRxP[3]]; # JESD0_DB2P
set_property PACKAGE_PIN B1 [get_ports jesdRxN[3]]; # JESD0_DB2M

###################################################
#                      BANK227                    #
###################################################

set_property PACKAGE_PIN L4 [get_ports jesdTxP[4]]
set_property PACKAGE_PIN L3 [get_ports jesdTxN[4]]
set_property PACKAGE_PIN K2 [get_ports jesdRxP[4]]; # JESD1_DA1P
set_property PACKAGE_PIN K1 [get_ports jesdRxN[4]]; # JESD1_DA1M

set_property PACKAGE_PIN N4 [get_ports jesdTxP[5]]
set_property PACKAGE_PIN N3 [get_ports jesdTxN[5]]
set_property PACKAGE_PIN M2 [get_ports jesdRxP[5]]; # JESD1_DA2P
set_property PACKAGE_PIN M1 [get_ports jesdRxN[5]]; # JESD1_DA2M

set_property PACKAGE_PIN G4 [get_ports jesdTxP[6]]
set_property PACKAGE_PIN G3 [get_ports jesdTxN[6]]
set_property PACKAGE_PIN F2 [get_ports jesdRxP[6]]; # JESD1_DB1P
set_property PACKAGE_PIN F1 [get_ports jesdRxN[6]]; # JESD1_DB1M

set_property PACKAGE_PIN J4 [get_ports jesdTxP[7]]
set_property PACKAGE_PIN J3 [get_ports jesdTxN[7]]
set_property PACKAGE_PIN H2 [get_ports jesdRxP[7]]; # JESD1_DB2P
set_property PACKAGE_PIN H1 [get_ports jesdRxN[7]]; # JESD1_DB2M

###################################################
#                      BANK224                    #
###################################################

set_property PACKAGE_PIN AM6 [get_ports jesdTxP[8]]
set_property PACKAGE_PIN AM5 [get_ports jesdTxN[8]]
set_property PACKAGE_PIN AM2 [get_ports jesdRxP[8]]; # JESD2_DA1P
set_property PACKAGE_PIN AM1 [get_ports jesdRxN[8]]; # JESD2_DA1M

set_property PACKAGE_PIN AN4 [get_ports jesdTxP[9]]
set_property PACKAGE_PIN AN3 [get_ports jesdTxN[9]]
set_property PACKAGE_PIN AP2 [get_ports jesdRxP[9]]; # JESD2_DA2P
set_property PACKAGE_PIN AP1 [get_ports jesdRxN[9]]; # JESD2_DA2M

set_property PACKAGE_PIN AK6 [get_ports jesdTxP[10]]
set_property PACKAGE_PIN AK5 [get_ports jesdTxN[10]]
set_property PACKAGE_PIN AJ4 [get_ports jesdRxP[10]]; # JESD2_DB1P
set_property PACKAGE_PIN AJ3 [get_ports jesdRxN[10]]; # JESD2_DB1M

set_property PACKAGE_PIN AL4 [get_ports jesdTxP[11]]
set_property PACKAGE_PIN AL3 [get_ports jesdTxN[11]]
set_property PACKAGE_PIN AK2 [get_ports jesdRxP[11]]; # JESD2_DB2P
set_property PACKAGE_PIN AK1 [get_ports jesdRxN[11]]; # JESD2_DB2M

###################################################
#                      BANK225                    #
###################################################

set_property PACKAGE_PIN AG4 [get_ports jesdTxP[12]]
set_property PACKAGE_PIN AG3 [get_ports jesdTxN[12]]
set_property PACKAGE_PIN AF2 [get_ports jesdRxP[12]]; # JESD3_DA1P
set_property PACKAGE_PIN AF1 [get_ports jesdRxN[12]]; # JESD3_DA1M

set_property PACKAGE_PIN AH6 [get_ports jesdTxP[13]]
set_property PACKAGE_PIN AH5 [get_ports jesdTxN[13]]
set_property PACKAGE_PIN AH2 [get_ports jesdRxP[13]]; # JESD3_DA2P
set_property PACKAGE_PIN AH1 [get_ports jesdRxN[13]]; # JESD3_DA2M

set_property PACKAGE_PIN AC4 [get_ports jesdTxP[14]]
set_property PACKAGE_PIN AC3 [get_ports jesdTxN[14]]
set_property PACKAGE_PIN AB2 [get_ports jesdRxP[14]]; # JESD3_DB1P
set_property PACKAGE_PIN AB1 [get_ports jesdRxN[14]]; # JESD3_DB1M

set_property PACKAGE_PIN AE4 [get_ports jesdTxP[15]]
set_property PACKAGE_PIN AE3 [get_ports jesdTxN[15]]
set_property PACKAGE_PIN AD2 [get_ports jesdRxP[15]]; # JESD3_DB2P
set_property PACKAGE_PIN AD1 [get_ports jesdRxN[15]]; # JESD3_DB2M

###################################################

set_property -dict { PACKAGE_PIN W25 IOSTANDARD LVDS } [get_ports {lmkRefClkP}]
set_property -dict { PACKAGE_PIN Y25 IOSTANDARD LVDS } [get_ports {lmkRefClkN}]

set_property -dict { PACKAGE_PIN W23 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {jesdSysRefP}]
set_property -dict { PACKAGE_PIN W24 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100 } [get_ports {jesdSysRefN}]

set_property PACKAGE_PIN T23  [get_ports {jesdSync[0]}]
set_property PACKAGE_PIN V22  [get_ports {jesdSync[1]}]
set_property PACKAGE_PIN V23  [get_ports {jesdSync[2]}]
set_property PACKAGE_PIN U21  [get_ports {jesdSync[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {jesdSync*}] 

set_property PACKAGE_PIN V28 [get_ports {fadcPdn[0]}]
set_property PACKAGE_PIN V21 [get_ports {fadcPdn[1]}]
set_property PACKAGE_PIN W21 [get_ports {fadcPdn[2]}]
set_property PACKAGE_PIN T22 [get_ports {fadcPdn[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {fadcPdn*}] 

set_property PACKAGE_PIN V26 [get_ports {fadcSclk}]
set_property PACKAGE_PIN W26 [get_ports {fadcSdin}]
set_property PACKAGE_PIN V29 [get_ports {fadcSdout}]
set_property IOSTANDARD LVCMOS18 [get_ports {fadcSclk}] 
set_property IOSTANDARD LVCMOS18 [get_ports {fadcSdin}] 
set_property IOSTANDARD LVCMOS18 [get_ports {fadcSdout}] 

set_property PACKAGE_PIN W29 [get_ports {fadcSen[0]}]
set_property PACKAGE_PIN U26 [get_ports {fadcSen[1]}]
set_property PACKAGE_PIN U27 [get_ports {fadcSen[2]}]
set_property PACKAGE_PIN W28 [get_ports {fadcSen[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {fadcSen*}] 

set_property PACKAGE_PIN Y28 [get_ports {fadcReset[0]}]
set_property PACKAGE_PIN U24 [get_ports {fadcReset[1]}]
set_property PACKAGE_PIN U25 [get_ports {fadcReset[2]}]
set_property PACKAGE_PIN V27 [get_ports {fadcReset[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {fadcReset*}] 

set_property -dict { IOSTANDARD LVCMOS33 PULLTYPE PULLUP PACKAGE_PIN J26 } [get_ports {lmkCsL}]
set_property -dict { IOSTANDARD LVCMOS33 PULLTYPE PULLUP PACKAGE_PIN H26 } [get_ports {lmkSck}]
set_property -dict { IOSTANDARD LVCMOS33 PULLTYPE PULLUP PACKAGE_PIN J24 } [get_ports {lmkSdio}]
set_property -dict { IOSTANDARD LVCMOS33 PULLTYPE PULLUP PACKAGE_PIN J25 } [get_ports {lmkRst}]
set_property -dict { IOSTANDARD LVCMOS33 PULLTYPE PULLUP PACKAGE_PIN K26 } [get_ports {lmkSync}]

##########################
## Misc. Configurations ##
##########################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design] 
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS         {VCCO} [current_design]
set_property CONFIG_VOLTAGE {3.3} [current_design]