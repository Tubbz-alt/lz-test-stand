##############################################################################
## This file is part of 'EPIX Development Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'EPIX Development Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
## User Debug Script

### Open the run
#open_run synth_1
#
#### Configure the Core
#set ilaName u_ila_0
###set ilaName1 u_ila_1
#CreateDebugCore ${ilaName}
###CreateDebugCore ${ilaName1}
##
#### Increase the record depth
##set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]
#set_property C_DATA_DEPTH 2048 [get_debug_cores ${ilaName}]
##
##############################################################################
##############################################################################
##############################################################################
##
#### Core debug signals
#SetDebugCoreClk ${ilaName} {clk250}
#
### 250MSPS ADC readout module axiLite bus
##ConfigProbe ${ilaName} {rst250}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadMaster[araddr][*]}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadMaster[arvalid]}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadMaster[rready]}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadSlave[rdata][*]}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadSlave[rresp][*]}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadSlave[rvalid]}
##ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/mAxiReadSlave[arready]}
#
### 
#ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/AxiAds42lb69Deser_Inst/GEN_CH[0].GEN_DAT[0].AxiAds42lb69DeserBit_Inst/delayOutData1[*]}
#ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/AxiAds42lb69Deser_Inst/GEN_CH[0].GEN_DAT[0].AxiAds42lb69DeserBit_Inst/delayOutData2[*]}
#ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/AxiAds42lb69Deser_Inst/GEN_CH[0].GEN_DAT[0].AxiAds42lb69DeserBit_Inst/idelayInData[*]}
#ConfigProbe ${ilaName} {GEN_250MSPS[0].U_250MspsAdc/AxiAds42lb69Deser_Inst/GEN_CH[0].GEN_DAT[0].AxiAds42lb69DeserBit_Inst/idelayInLoad}
#
#
##############################################################################
##
#### Delete the last unused port
#delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]
##
#### Write the port map file
####write_debug_probes -force ${PROJ_DIR}/debug/debug_probes.ltx
##