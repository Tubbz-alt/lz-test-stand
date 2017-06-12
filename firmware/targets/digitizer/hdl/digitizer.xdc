##############################################################################
## This file is part of 'firmware-template'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'firmware-template', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################


##########################
## Timing Constraints   ##
##########################

create_clock -name pgpClkP -period  6.400 [get_ports {pgpClkP}]
create_clock -name ddrClkP -period  5.000 [get_ports {c0_sys_clk_p}]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {pgpClkP}] -group [get_clocks -include_generated_clocks {ddrClkP}]

############################
## Pinout Configuration   ##
############################

set_property PACKAGE_PIN V6  [get_ports {pgpClkP}]
set_property PACKAGE_PIN V5  [get_ports {pgpClkN}]
set_property PACKAGE_PIN AA4 [get_ports pgpTxP]
set_property PACKAGE_PIN AA3 [get_ports pgpTxN]
set_property PACKAGE_PIN Y2  [get_ports pgpRxP]
set_property PACKAGE_PIN Y1  [get_ports pgpRxN]

set_property PACKAGE_PIN K20 [get_ports {led[0]}]
set_property PACKAGE_PIN K21 [get_ports {led[1]}]
set_property PACKAGE_PIN K22 [get_ports {led[2]}]
set_property PACKAGE_PIN N21 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led*}] 

set_property PACKAGE_PIN AF9  [get_ports {enDcDcAm6V}]
set_property PACKAGE_PIN AG10 [get_ports {enDcDcAp5V4}]
set_property PACKAGE_PIN AF10 [get_ports {enDcDcAp3V7}]
set_property PACKAGE_PIN AJ10 [get_ports {enDcDcAp2V3}]
set_property PACKAGE_PIN AG9  [get_ports {enDcDcAp1V6}]
set_property PACKAGE_PIN AH11 [get_ports {enLdoSlow}]
set_property PACKAGE_PIN AJ11 [get_ports {enLdoFast}]
set_property PACKAGE_PIN AG11 [get_ports {enLdoAm5V}]
set_property IOSTANDARD LVCMOS33 [get_ports {enDcDc*}] 
set_property IOSTANDARD LVCMOS33 [get_ports {enLdo*}] 

set_property PACKAGE_PIN AM9  [get_ports {pokDcDcDp6V}]
set_property PACKAGE_PIN AJ9  [get_ports {pokDcDcAp6V}]
set_property PACKAGE_PIN AK8  [get_ports {pokDcDcAm6V}]
set_property PACKAGE_PIN AJ8  [get_ports {pokDcDcAp5V4}]
set_property PACKAGE_PIN AN8  [get_ports {pokDcDcAp3V7}]
set_property PACKAGE_PIN AP8  [get_ports {pokDcDcAp2V3}]
set_property PACKAGE_PIN AK10 [get_ports {pokDcDcAp1V6}]
set_property PACKAGE_PIN AL9  [get_ports {pokLdoA0p1V8}]
set_property PACKAGE_PIN AN9  [get_ports {pokLdoA0p3V3}]
set_property PACKAGE_PIN AP9  [get_ports {pokLdoAd1p1V2}]
set_property PACKAGE_PIN AL10 [get_ports {pokLdoAd2p1V2}]
set_property PACKAGE_PIN AM10 [get_ports {pokLdoA1p1V9}]
set_property PACKAGE_PIN AH9  [get_ports {pokLdoA2p1V9}]
set_property PACKAGE_PIN AH8  [get_ports {pokLdoAd1p1V9}]
set_property PACKAGE_PIN AD9  [get_ports {pokLdoAd2p1V9}]
set_property PACKAGE_PIN AD8  [get_ports {pokLdoA1p3V3}]
set_property PACKAGE_PIN AD10 [get_ports {pokLdoA2p3V3}]
set_property PACKAGE_PIN AE10 [get_ports {pokLdoAvclkp3V3}]
set_property PACKAGE_PIN AE8  [get_ports {pokLdoA0p5V0}]
set_property PACKAGE_PIN AF8  [get_ports {pokLdoA1p5V0}]
set_property IOSTANDARD LVCMOS33 [get_ports {pokDcDc*}] 
set_property IOSTANDARD LVCMOS33 [get_ports {pokLdo*}] 

set_property PACKAGE_PIN V28 [get_ports {fadcPdn[0]}]
set_property PACKAGE_PIN V21 [get_ports {fadcPdn[1]}]
set_property PACKAGE_PIN W21 [get_ports {fadcPdn[2]}]
set_property PACKAGE_PIN T22 [get_ports {fadcPdn[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {fadcPdn*}] 

set_property PACKAGE_PIN B17 [get_ports {sadcCtrl1[0]}]
set_property PACKAGE_PIN B16 [get_ports {sadcCtrl1[1]}]
set_property PACKAGE_PIN C19 [get_ports {sadcCtrl1[2]}]
set_property PACKAGE_PIN B19 [get_ports {sadcCtrl1[3]}]
set_property PACKAGE_PIN B15 [get_ports {sadcCtrl2[0]}]
set_property PACKAGE_PIN A15 [get_ports {sadcCtrl2[1]}]
set_property PACKAGE_PIN A19 [get_ports {sadcCtrl2[2]}]
set_property PACKAGE_PIN A18 [get_ports {sadcCtrl2[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sadcCtrl*}] 

set_property PACKAGE_PIN L24 [get_ports {sampEn[0]}]
set_property PACKAGE_PIN L23 [get_ports {sampEn[1]}]
set_property PACKAGE_PIN K25 [get_ports {sampEn[2]}]
set_property PACKAGE_PIN L25 [get_ports {sampEn[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sampEn*}] 

##########################
## Misc. Configurations ##
##########################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design] 
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS         {VCCO} [current_design]
set_property CONFIG_VOLTAGE {3.3} [current_design]