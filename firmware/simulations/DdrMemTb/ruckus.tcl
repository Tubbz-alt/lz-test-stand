# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2017.2 of Vivado
if { [VersionCheck 2017.2] < 0 } {
   exit -1
}

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules
loadRuckusTcl $::env(TOP_DIR)/common

# Load target's source code and constraints
loadSource -sim_only -dir "$::DIR_PATH/tb/"

# Remove the .DCP and use the .XCI IP core instead
remove_files [get_files {MigCore.dcp}]
loadIpCore -path "$::env(TOP_DIR)/common/ip/MigCore/MigCore.xci"

# Set the top level synth_1 and sim_1
set_property top {MigCoreWrapper} [get_filesets sources_1]
set_property top {DdrMemTb} [get_filesets sim_1]