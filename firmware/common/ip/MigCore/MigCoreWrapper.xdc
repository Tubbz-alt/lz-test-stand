##############################################################################
## This file is part of 'LZ Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LZ Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_property IOSTANDARD    DIFF_SSTL12 [get_ports {c0_sys_clk_p c0_sys_clk_n}]
set_property IBUF_LOW_PWR  FALSE       [get_ports {c0_sys_clk_p c0_sys_clk_n}]
set_property PULLTYPE      KEEPER      [get_ports {c0_sys_clk_p c0_sys_clk_n}]

set_property -dict { IOSTANDARD SSTL12_DCI SLEW FAST }      [get_ports {c0_ddr4_bg[*]}] 
set_property -dict { IOSTANDARD DIFF_SSTL12_DCI SLEW FAST } [get_ports {c0_ddr4_ck_t[*]}] 
set_property -dict { IOSTANDARD DIFF_SSTL12_DCI SLEW FAST } [get_ports {c0_ddr4_ck_c[*]}] 
set_property -dict { IOSTANDARD SSTL12_DCI SLEW FAST }      [get_ports {c0_ddr4_cke[*]}] 
set_property -dict { IOSTANDARD SSTL12_DCI SLEW FAST }      [get_ports {c0_ddr4_cs_n[*]}] 
set_property -dict { IOSTANDARD SSTL12_DCI SLEW FAST }      [get_ports {c0_ddr4_odt[*]}] 
set_property -dict { IOSTANDARD SSTL12_DCI SLEW FAST }      [get_ports {c0_ddr4_act_n}] 
set_property -dict { IOSTANDARD SSTL12 OUTPUT_IMPEDANCE RDRV_48_48 SLEW SLOW } [get_ports {c0_ddr4_reset_n}]

set_property IOSTANDARD SSTL12_DCI     [get_ports {c0_ddr4_adr[*]}]
set_property SLEW FAST                 [get_ports {c0_ddr4_adr[*]}]

set_property IOSTANDARD SSTL12_DCI     [get_ports {c0_ddr4_ba[*]}]
set_property SLEW FAST                 [get_ports {c0_ddr4_ba[*]}]

set_property IOSTANDARD POD12_DCI      [get_ports {c0_ddr4_dm_dbi_n[*]}]
set_property SLEW FAST                 [get_ports {c0_ddr4_dm_dbi_n[*]}]

set_property IOSTANDARD POD12_DCI      [get_ports {c0_ddr4_dq[*]}]
set_property SLEW       FAST           [get_ports {c0_ddr4_dq[*]}]

set_property IOSTANDARD DIFF_POD12_DCI [get_ports {c0_ddr4_dqs_t[*] c0_ddr4_dqs_c[*]}]
set_property SLEW       FAST           [get_ports {c0_ddr4_dqs_t[*] c0_ddr4_dqs_c[*]}]
