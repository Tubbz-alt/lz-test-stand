# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

## Check for version 2016.4 of Vivado
if { [VersionCheck 2016.4] < 0 } {
   close_project
   exit -1
}

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules
loadRuckusTcl $::env(TOP_DIR)/common

# Load target's source code and constraints
loadSource -sim_only -dir "$::DIR_PATH/tb/"

# Set the top level synth_1 and sim_1
set_property top {MigCoreWrapper} [get_filesets sources_1]
set_property top {DdrBufferTb} [get_filesets sim_1]