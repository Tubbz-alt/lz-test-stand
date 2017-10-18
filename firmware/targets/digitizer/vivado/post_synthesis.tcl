##############################################################################
## This file is part of 'DUNE Development Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'DUNE Development Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

##############################
# Get variables and procedures
##############################
source -quiet $::env(RUCKUS_DIR)/vivado_env_var.tcl
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Bypass the debug chipscope generation
return

############################
## Open the synthesis design
############################
open_run synth_1

###############################
## Set the name of the ILA core
###############################
set ilaName u_ila_0

##################
## Create the core
##################
CreateDebugCore ${ilaName}

#######################
## Set the record depth
#######################
set_property C_DATA_DEPTH 1024 [get_debug_cores ${ilaName}]

#################################
## Set the clock for the ILA core
#################################
SetDebugCoreClk ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/devClk_i}

#######################
## Set the debug Probes
#######################

ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/syncFSM_INST/r[state][*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/r[jesdGtRx][data][*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/r[jesdGtRx][dataK][*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/chariskRx_i[*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/dataRx_i[*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[position][*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[dataRxD1][*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[chariskRxD1][*]}

ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[dataAlignedD1][*]}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[charAlignedD1][*]}

ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/lmfc_i}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufRe}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufRst}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufUnf}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufWe}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_readBuff}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/sysRef_i}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/syncFSM_INST/s_kDetected}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/syncFSM_INST/s_kStable}
ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/alignFrame_i}

##########################
## Write the port map file
##########################
WriteDebugProbes ${ilaName} ${PROJ_DIR}/images/debug_probes_${PRJ_VERSION}.ltx
