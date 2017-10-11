#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI Version Module
#-----------------------------------------------------------------------------
# File       : 
# Author     : Maciej Kwiatkowski
# Created    : 2016-09-29
# Last update: 2017-01-31
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue as pr
import collections
import time

from lztsFpga.LztsPowerRegisters        import *
from lztsFpga.SadcBufferReader          import *
from lztsFpga.SadcBufferWriter          import *
from lztsFpga.SadcPatternTester         import *

from surf.axi._AxiMemTester             import *
from surf.axi._AxiVersion               import *
from surf.devices.micron._AxiMicronN25Q import *
from surf.devices.ti._Ads42Lbx9         import *
from surf.devices.ti._ads54J60          import *
from surf.devices.ti._Lmk04828          import *
from surf.protocols.jesd204b            import *
from surf.protocols.pgp._pgp2baxi       import *
from surf.xilinx._AxiSysMonUltraScale   import *

################################################################################################
##
## Lzts Class definition
##
################################################################################################
class Lzts(pr.Device):
    def __init__(self, **kwargs):
        if 'description' not in kwargs:
            kwargs['description'] = "Lzts FPGA"
        super(self.__class__, self).__init__(**kwargs)
      
        #########
        # Devices
        #########
        self.add(AxiVersion(         name='AxiVersion', offset=0x00000000, expand=False, hidden=True,))      
        self.add(AxiSysMonUltraScale(name='SysMon',     offset=0x00100000, expand=False, hidden=True,))      
        self.add(AxiMicronN25Q(      name='MicronN25Q', offset=0x00200000, expand=False, hidden=True,))      
        self.add(AxiMemTester(       name='MemTester',  offset=0x00300000, expand=False, hidden=True,))      
        self.add(LztsPowerRegisters( name='PwrReg',     offset=0x01000000, expand=False, hidden=True,))      
        self.add(Pgp2bAxi(           name='Pgp2bAxi',   offset=0x02000000, expand=False, hidden=True,))      
        for i in range(4):
            self.add(Ads42Lbx9Readout(
                name    = ('SlowAdcReadout[%d]'%i),
                offset  = (0x03000000 + i*0x100000), 
                expand  = False, 
                enabled = False,
                hidden  = True,
            ))
        for i in range(4):
            self.add(Ads42Lbx9Config(
                name    = ('SlowAdcConfig[%d]'%i),
                offset  = (0x03400000 + i*0x200), 
                expand  = False, 
                enabled = False,
                hidden  = True,
            ))  
        for i in range(8):
            self.add(SadcBufferWriter(
                name    = ('SadcBufferWriter[%d]'%i),
                offset  = (0x04000000 + i*0x100000), 
                expand  = False, 
                enabled = False,
                hidden  = True,
            ))              
        self.add(SadcBufferReader(  name='SadcBufferReader',    offset=0x04800000, enabled=False, expand=False, hidden=True,))      
        self.add(SadcPatternTester( name='SadcPatternTester',   offset=0x04900000, enabled=False, expand=False, hidden=True,))      
        self.add(JesdRx(            name='JesdRx',              offset=0x05000000, expand=True,  numRxLanes=16, hidden=False,))      
        self.add(Lmk04828(          name='LMK',                 offset=0x05100000, expand=False, hidden=False,))      
        for i in range(4):
            self.add(Ads54J60(
                name      = ('FastAdcConfig[%d]'%i),
                offset    = (0x05200000 + i*0x100000), 
                expand    = False, 
            ))
        
        @self.command(description="Initialization for JESD modules",)
        def JesdInit():            
            self.checkBlocks(recurse=True)
            self.LMK.Init()
            self.LMK.PwrDwnSysRef()            
            self.checkBlocks(recurse=True)   
            for i in range(4):
                self.FastAdcConfig[i].Init()
                self.checkBlocks(recurse=True)   

        @self.command(description  = "JESD Reset") 
        def JesdReset():
            self.LMK.Init()
            self.LMK.PwrDwnSysRef()   
            self.checkBlocks(recurse=True)
            
            for i in range(4):
                self.FastAdcConfig[i].DigRst()
                self.checkBlocks(recurse=True)             
                
            for i in range(3):
                self.JesdRx.CmdResetGTs()
                time.sleep(1.0)            
                self.checkBlocks(recurse=True)             
                    
            self.checkBlocks(recurse=True)
            time.sleep(0.1)
            
            self.LMK.PwrUpSysRef()
            self.checkBlocks(recurse=True)
            time.sleep(0.1)
            
            self.JesdRx.InvertSync.set(1)
            self.checkBlocks(recurse=True)   
            time.sleep(0.1)
            
            self.JesdRx.InvertSync.set(0)
            self.JesdRx.CmdClearErrors()
            self.checkBlocks(recurse=True)   
            
    def writeBlocks(self, force=False, recurse=True, variable=None):
        """
        Write all of the blocks held by this Device to memory
        """
        if not self.enable.get(): return

        # Process local blocks.
        if variable is not None:
            variable._block.backgroundTransaction(rogue.interfaces.memory.Write)
        else:
            for block in self._blocks:
                if force or block.stale:
                    if block.bulkEn:
                        block.backgroundTransaction(rogue.interfaces.memory.Write)

        # Retire any in-flight transactions before starting next sequence
        self._root.checkBlocks(recurse=True)
        
        # Load all the register expect for JESD which have to be loaded after LMK init()
        self.AxiVersion.writeBlocks( force=force, recurse=recurse, variable=variable)
        self.SysMon.writeBlocks(     force=force, recurse=recurse, variable=variable)
        self.MicronN25Q.writeBlocks( force=force, recurse=recurse, variable=variable)
        self.MemTester.writeBlocks(  force=force, recurse=recurse, variable=variable)
        self.PwrReg.writeBlocks(     force=force, recurse=recurse, variable=variable)
        self.Pgp2bAxi.writeBlocks(   force=force, recurse=recurse, variable=variable)
        self._root.checkBlocks(recurse=True)           
        time.sleep(0.1); # wait for power supplies to boot up
        
        for i in range(4):
            self.SlowAdcReadout[i].writeBlocks(force=force, recurse=recurse, variable=variable)
            self.SlowAdcConfig[i].writeBlocks( force=force, recurse=recurse, variable=variable)
            
        for i in range(8):
            self.SadcBufferWriter[i].writeBlocks(force=force, recurse=recurse, variable=variable)
            
        self.SadcBufferReader.writeBlocks(  force=force, recurse=recurse, variable=variable)
        self.SadcPatternTester.writeBlocks( force=force, recurse=recurse, variable=variable)
        self.JesdRx.writeBlocks(            force=force, recurse=recurse, variable=variable)
        self.LMK.writeBlocks(               force=force, recurse=recurse, variable=variable)
        self._root.checkBlocks(recurse=True)           
        
        self.JesdInit()
        
        for i in range(4):
            self.FastAdcConfig[i].writeBlocks(force=force, recurse=recurse, variable=variable)        
            self._root.checkBlocks(recurse=True)    
            
        self.JesdReset()
        