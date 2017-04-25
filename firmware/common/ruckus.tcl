# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir           "$::DIR_PATH/rtl"
#loadSource -sim_only -dir "$::DIR_PATH/tb"

#loadSource -path "$::DIR_PATH/ip/mig_ddr4/ddr4_1.dcp"
loadIpCore -path "$::DIR_PATH/ip/mig_ddr4/ddr4_1.xci"
loadSource -path "$::DIR_PATH/ip/gth_core/PgpGthCore.dcp"

# Check for Application Microblaze build
#if { [expr [info exists ::env(SDK_SRC_PATH)]] == 0 } {
#   ## Add the Microblaze Calibration Code
#   add_files $::DIR_PATH/ip/mig_ddr4/ddr4_1_mb_calib.elf
#   set_property SCOPED_TO_REF   {MigCore} [get_files ddr4_1_mb_calib.elf]
#   set_property SCOPED_TO_CELLS {U_AxiDdr4ControllerWrapper/u_ddr4_1/ddr4_1/inst/u_ddr4_mem_intfc/u_ddr_cal_riu/mcs0/microblaze_I} [get_files ddr4_1_mb_calib.elf]
#
#   add_files $::DIR_PATH/ip/mig_ddr4/ddr4_1_mb_calib.bmm
#   set_property SCOPED_TO_REF   {MigCore} [get_files ddr4_1_mb_calib.bmm]
#   set_property SCOPED_TO_CELLS {U_AxiDdr4ControllerWrapper/u_ddr4_1/ddr4_1/inst/u_ddr4_mem_intfc/u_ddr_cal_riu/mcs0} [get_files ddr4_1_mb_calib.bmm]
#}


# Load ruckus files
# Place an entry here for each common module
#loadRuckusTcl "$::DIR_PATH/module1"
