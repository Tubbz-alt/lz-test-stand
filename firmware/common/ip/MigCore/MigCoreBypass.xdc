##############################################################################
## This file is part of 'LZ Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LZ Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_property IOSTANDARD LVCMOS12 [get_ports {c0_sys_clk_p}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_sys_clk_n}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_bg[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_ck_t[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_ck_c[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_cke[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_cs_n[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_odt[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_act_n}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_reset_n}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_adr[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_ba[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_dm_dbi_n[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_dq[*]}]
set_property IOSTANDARD LVCMOS12 [get_ports {c0_ddr4_dqs_t[*] c0_ddr4_dqs_c[*]}]
