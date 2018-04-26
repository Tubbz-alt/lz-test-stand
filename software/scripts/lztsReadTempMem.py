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
import operator
#################


# Set the argument parser
parser = argparse.ArgumentParser()

parser.add_argument(
    "--l", 
    type     = int,
    required = False,
    default  = 0,
    help     = "PGP lane number",
)

parser.add_argument(
    "--type", 
    type     = str,
    required = True,
    help     = "define the PCIe card type (either pgp-gen3 or datadev-pgp2b)",
)  

# Get the arguments
args = parser.parse_args()

if ( args.type == 'pgp-gen3' ):
    pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',args.l,0) # Registers for lzts board
    pgpVc1 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',args.l,1) # Data for lzts board
    print("")
    print("PGP Card Version: %x" % (pgpVc0.getInfo().version))
    
elif ( args.type == 'datadev-pgp2b' ):
    
    #pgpVc0 = rogue.hardware.data.DataCard('/dev/datadev_0',(args.l*32)+0) # Registers for lzts board
    pgpVc0 = rogue.hardware.data.DataCard('/dev/datadev_0',(7*32)+args.l) # Registers for lzts board
    pgpVc1 = rogue.hardware.data.DataCard('/dev/datadev_0',(args.l*32)+1) # Data for lzts board
    pgpVc2 = rogue.hardware.data.DataCard('/dev/datadev_0',(args.l*32)+2) # PRBS stream
    
    #memBase = rogue.hardware.data.DataMap('/dev/datadev_0')
else:
    raise ValueError("Invalid type (%s)" % (args.type) )



# Add data stream to file as channel 1
# File writer
dataWriter = pyrogue.utilities.fileio.StreamWriter(name='dataWriter')

pyrogue.streamConnect(pgpVc1, dataWriter.getChannel(0x1))
## Add pseudoscope to file writer
#pyrogue.streamConnect(pgpVc2, dataWriter.getChannel(0x2))
#pyrogue.streamConnect(pgpVc3, dataWriter.getChannel(0x3))

cmd = rogue.protocols.srp.Cmd()
pyrogue.streamConnect(cmd, pgpVc1)

# Create and Connect SRP to VC1 to send commands
srp = rogue.protocols.srp.SrpV3()
pyrogue.streamConnectBiDir(pgpVc0,srp)


#############################################
# Microblaze console printout
#############################################
class MbDebug(rogue.interfaces.stream.Slave):

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        self.enable = False

    def _acceptFrame(self,frame):
        if self.enable:
            p = bytearray(frame.getPayload())
            frame.read(p,0)
            print('-------- Microblaze Console --------')
            print(p.decode('utf-8'))

#######################################
# Custom run control
#######################################

class MyRunControl(pyrogue.RunControl):
    def __init__(self,name):
        pyrogue.RunControl.__init__(self,name=name,description='Run Controller LZTS', rates={1:'1 Hz', 10:'10 Hz', 30:'30 Hz'})
        self._thread = None

    def _setRunState(self,dev,var,value,changed):
        if changed: 
            if self.runState.get(read=False) == 'Running': 
                self._thread = threading.Thread(target=self._run) 
                self._thread.start() 
            else: 
                self._thread.join() 
                self._thread = None 

    def _run(self):
        self.runCount.set(0) 
        self._last = int(time.time()) 
 
 
        while (self.runState.value() == 'Running'): 
            delay = 1.0 / ({value: key for key,value in self.runRate.enum.items()}[self._runRate]) 
            time.sleep(delay) 
            self.root.Trigger() 
  
            self._runCount += 1 
            if self._last != int(time.time()): 
                self._last = int(time.time()) 
                self.runCount._updated() 
            
##############################
# Set base
##############################
class LztsBoard(pyrogue.Root):
    def __init__(self, cmd, dataWriter, srp, **kwargs):
        
        pyrogue.Root.__init__(self, name='lztsBoard', description='LZTS Board')
        
        self.add(dataWriter)

        # Add Devices
        self.add(fpga.Lzts(name='Lzts', offset=0, memBase=srp, hidden=False, enabled=True))

        @self.command()
        def Trigger():
            cmd.sendCmd(0, 0)
        
        self.add(MyRunControl('runControl'))
        #self.add(pyrogue.RunControl(name='runControl', rates={1:'1 Hz', 10:'10 Hz',30:'30 Hz'}, cmd=cmd.sendCmd(0, 0)))
        
        # Export remote objects
        self.start(pyroGroup='lztsGui')





# Create board
LztsBoard = LztsBoard(cmd, dataWriter, srp)

#enable all needed devices
LztsBoard.Lzts.PwrReg.enable.set(True)
LztsBoard.Lzts.TempLocMem.enable.set(True)
LztsBoard.Lzts.TempRemMem.enable.set(True)

#locTemp = 256*[0]
#remTemp = 256*[0]
memPtr = LztsBoard.Lzts.PwrReg.FaultTempPtr.get()
memPtr = memPtr + 1

remFile = 'remTemp.csv'
locFile = 'locTemp.csv'
rf = open(remFile, 'w')
lf = open(locFile, 'w')

for i in range(256):
   if (memPtr + i) < 256:
      j = memPtr + i
   else:
      j = memPtr + i - 256
   #locTemp[i] = LztsBoard.Lzts.TempLocMem.MEM[j].get()
   #remTemp[i] = LztsBoard.Lzts.TempRemMem.MEM[j].get()
   lf.write('%d,' %(LztsBoard.Lzts.TempLocMem.MEM[j].get()))
   rf.write('%d,' %(LztsBoard.Lzts.TempRemMem.MEM[j].get()))

rf.write('\n')
lf.write('\n')
rf.close()
lf.close()

LztsBoard.stop()
exit()