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
set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]

#################################
## Set the clock for the ILA core
#################################
#SetDebugCoreClk ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/devClk_i}
SetDebugCoreClk ${ilaName} {adcClk}
#SetDebugCoreClk ${ilaName} {U_Core/U_LztsSynchronizer/muxClk}

#######################
## Set the debug Probes
#######################

#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[serIn][*]}
#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[syncDet]}
#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[rstDet]}
#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[syncCmd]}
#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[rstCmd]}
#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[syncPending]}
#ConfigProbe ${ilaName} {U_Core/U_LztsSynchronizer/mux[rstPending]}



ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[trigState][*]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[buffSel][*]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[buffCnt][*]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[buffAddr][*]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[samplesBuff][*]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[actPreDelay][*]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[buffSwitch]}
ConfigProbe ${ilaName} {U_FadcBuffer/GEN_VEC[0].U_FadcChannel/trig[buffRdDone]}


#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/trig[trigState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/trig[trigType][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/adcDataSig[*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/preThr}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/postThr}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/vetoThr}


##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/trig[trigState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/trig[buffState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[0].U_Writer/trig[hdrState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[1].U_Writer/trig[trigState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[1].U_Writer/trig[buffState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[1].U_Writer/trig[hdrState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[6].U_Writer/trig[trigState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[6].U_Writer/trig[buffState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[6].U_Writer/trig[hdrState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[memFull]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[hdrFifoCnt][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[wrAddress][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[trigState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[buffState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[hdrState][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[trigLength][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[trigOffset][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[hdrFifoDin][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/trig[hdrFifoWr]}
##ConfigProbe ${ilaName} {U_SadcBuffer/GEN_VEC[7].U_Writer/hdrFifoFull}
#ConfigProbe ${ilaName} {U_SadcBuffer/hdrDout[*][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/hdrValid[*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/hdrRd[*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/addrDout[7][*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/addrValid[*]}
##ConfigProbe ${ilaName} {U_SadcBuffer/addrRd[7]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[emptyCnt][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[channelSel][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[hdrCnt][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[buffState][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[rMaster][arlen][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[rdSize][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[trigSize][*]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[txMaster][tLast]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/trig[txMaster][tValid]}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/rValid}
#ConfigProbe ${ilaName} {U_SadcBuffer/U_Reader/txSlave[tReady]}


#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/syncFSM_INST/r[state][*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/r[jesdGtRx][data][*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/r[jesdGtRx][dataK][*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/chariskRx_i[*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/dataRx_i[*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[position][*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[dataRxD1][*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[chariskRxD1][*]}
#
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[dataAlignedD1][*]}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/r[charAlignedD1][*]}
#
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/lmfc_i}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufRe}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufRst}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufUnf}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_bufWe}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/s_readBuff}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/sysRef_i}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/syncFSM_INST/s_kDetected}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/syncFSM_INST/s_kStable}
#ConfigProbe ${ilaName} {U_FadcPhy/U_Jesd/U_Jesd204bRx/generateRxLanes[0].JesdRx_INST/alignFrRepCh_INST/alignFrame_i}

##########################
## Write the port map file
##########################
WriteDebugProbes ${ilaName} ${PROJ_DIR}/images/debug_probes_${PRJ_VERSION}.ltx
