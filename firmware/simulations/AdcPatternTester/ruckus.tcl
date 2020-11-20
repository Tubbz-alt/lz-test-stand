# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl


# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules
loadRuckusTcl $::env(TOP_DIR)/common

# Load target's source code and constraints
loadSource -sim_only -dir "$::DIR_PATH/tb/"

set_property top {AdcPatternTesterTb} [get_filesets sim_1]

