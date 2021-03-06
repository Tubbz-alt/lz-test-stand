# Setup environment
# source /afs/slac/g/reseng/rogue/master/setup_env.sh
source /afs/slac/g/reseng/rogue/v2.2.0/setup_env.sh

# Submodule Python Package directories
export SURF_DIR=${PWD}/../firmware/submodules/surf/python
export AXI_DIR=${PWD}/../firmware/submodules/axi-pcie-core/python

# Setup python path
export PYTHONPATH=${PWD}/python:${SURF_DIR}:${AXI_DIR}:${PYTHONPATH}
