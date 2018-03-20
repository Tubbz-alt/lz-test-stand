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

import sys
import pyrogue as pr
import pyrogue.epics
import pyrogue.gui
import PyQt4.QtGui
import argparse
import time
import lztsFpga as fpga

#################################################################

# Set the argument parser
parser = argparse.ArgumentParser()

# Add arguments
parser.add_argument(
    "--mcs", 
    type     = str,
    required = True,
    help     = "path to mcs file",
)

parser.add_argument(
    "--l", 
    type     = int,
    required = True,
    help     = "PGP lane number [0 ~ 7]",
)

parser.add_argument(
    "--type", 
    type     = str,
    required = True,
    help     = "define the PCIe card type (either pgp-gen3 or datadev-pgp2b)",
)  

# Get the arguments
args = parser.parse_args()

#################################################################

# Set base
base = pr.Root(name='base',description='')    

# Legacy PGP GEN3 Card
if ( args.type == 'pgp-gen3' ):
    pgpVc0 = rogue.hardware.pgp.PgpCard('/dev/pgpcard_0',args.l,0) # Registers for lzts board    
# LZ's datadev PGP2B Card
elif ( args.type == 'datadev-pgp2b' ):    
    pgpVc0 = rogue.hardware.data.DataCard('/dev/datadev_0',(7*32)+args.l) # Registers for lzts board
# Undefined device type
else:
    raise ValueError("Invalid type (%s)" % (args.type) )
    
# Create and Connect SRP to VC0 to send commands
srp = rogue.protocols.srp.SrpV3()
pyrogue.streamConnectBiDir(pgpVc0,srp)    
    
# Add Base Device
base.add(fpga.Lzts(name='Lzts', memBase=srp))

# Start the system
base.start(pollEn=False)
    
# Create useful pointers
AxiVersion = base.Lzts.AxiVersion
PROM       = base.Lzts.MicronN25Q

print ( '###################################################')
print ( '#                 Old Firmware                    #')
print ( '###################################################')
AxiVersion.printStatus()

# Program the FPGA's PROM
PROM.LoadMcsFile(args.mcs)

# Check if PROM successfully programmed
if(PROM._progDone):
    print('\nReloading FPGA firmware from PROM ....')
    AxiVersion.FpgaReload()
    time.sleep(10)
    print('\nReloading FPGA done')

    print ( '###################################################')
    print ( '#                 New Firmware                    #')
    print ( '###################################################')
    AxiVersion.printStatus()
else:
    print('Failed to program FPGA')

base.stop()
exit()
