#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : ePix 100a board instance
#-----------------------------------------------------------------------------
# File       : epix100aDAQ.py evolved from evalBoard.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Modified by: Dionisio Doering
# Created    : 2016-09-29
# Last update: 2017-02-01
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to ePix 100a board
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import rogue.hardware.pgp
import pyrogue.utilities.prbs
import pyrogue.utilities.fileio
import pyrogue.gui
import surf
import threading
import signal
import atexit
import yaml
import time
import sys
import argparse
import PyQt4.QtGui
import PyQt4.QtCore
import lztsFpga as fpga
import lztsViewer as vi
from AdmPcieKu3Pgp2b import *


#memBase = rogue.hardware.data.DataMap('/dev/datadev_0')
memBase = rogue.hardware.axi.AxiMemMap('/dev/datadev_0')


##############################
# Set base
##############################
class LztsBoard(pyrogue.Root):
    def __init__(self, **kwargs):
        
        pyrogue.Root.__init__(self, name='lztsBoard', description='LZTS Board')
        
        self.add(AdmPcieKu3Pgp2b(name='PCIE',memBase=memBase))        
        
        # Export remote objects
        self.start(pyroGroup='lztsGui', pollEn=False)
        
# Create board
LztsBoard = LztsBoard()

# Create GUI
appTop = PyQt4.QtGui.QApplication(sys.argv)
guiTop = pyrogue.gui.GuiTop(group='pcieMon')
guiTop.resize(800, 800)
guiTop.addTree(LztsBoard)


# Run gui
appTop.exec_()

# Close window and stop polling
def stop():
    LztsBoard.stop()
    exit()
