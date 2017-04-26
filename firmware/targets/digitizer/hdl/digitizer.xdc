##############################################################################
## This file is part of 'firmware-template'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'firmware-template', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_property PACKAGE_PIN V6  [get_ports {pgpClkP}]
set_property PACKAGE_PIN V5  [get_ports {pgpClkN}]
set_property PACKAGE_PIN AA4 [get_ports pgpTxP]
set_property PACKAGE_PIN AA3 [get_ports pgpTxN]
set_property PACKAGE_PIN Y2  [get_ports pgpRxP]
set_property PACKAGE_PIN Y1  [get_ports pgpRxN]

##########################
## Timing Constraints   ##
##########################

create_clock -name pgpClkP -period  6.400 [get_ports {pgpClkP}]
create_clock -name ddrClkP -period  5.000 [get_ports {c0_sys_clk_p}]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks {pgpClkP}] -group [get_clocks -include_generated_clocks {ddrClkP}]

##########################
## Misc. Configurations ##
##########################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design] 
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE No [current_design]

set_property CFGBVS         {VCCO} [current_design]
set_property CONFIG_VOLTAGE {3.3} [current_design]