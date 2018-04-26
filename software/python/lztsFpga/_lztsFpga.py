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
import rogue.interfaces.memory as rim
import collections
import time

from lztsFpga.LztsPowerRegisters        import *
from lztsFpga.LztsMonitoring            import *
from lztsFpga.LztsSynchronizer          import *
from lztsFpga.LztsPacketizer            import *
from lztsFpga.SadcBufferReader          import *
from lztsFpga.SadcBufferWriter          import *
from lztsFpga.SadcPatternTester         import *
from lztsFpga.FadcBufferChannel         import *
from lztsFpga.FadcDebug                 import *
from lztsFpga.TempDebug                 import *

from surf.axi._AxiMemTester             import *
from surf.axi._AxiVersion               import *
from surf.devices.micron._AxiMicronN25Q import *
from surf.devices.ti._Ads42Lbx9         import *
from surf.devices.ti._ads54J60          import *
from surf.devices.ti._Lmk04828          import *
from surf.devices.linear._Ltc2945       import *
from surf.devices.nxp._Sa56004x         import *
from surf.protocols.jesd204b            import *
from surf.protocols.pgp._pgp2baxi       import *
from surf.protocols.ssi._SsiPrbsTx      import *
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
        self.add(AxiVersion(         name='AxiVersion', offset=0x00000000, expand=False, hidden=False,))
        self.add(AxiSysMonUltraScale(name='SysMon',     offset=0x00100000, expand=False, hidden=False,))
        self.add(AxiMicronN25Q(      name='MicronN25Q', offset=0x00200000, expand=False, hidden=True, addrMode=True, ))
        self.add(AxiMemTester(       name='MemTester',  offset=0x00300000, expand=False, hidden=True,))
        self.add(LztsSynchronizer(   name='LztsSync',   offset=0x00500000, expand=False, hidden=False,))
        self.add(LztsTemperature(    name='Temp0',      offset=0x00600000, expand=False, hidden=False,))
        self.add(LztsTemperature(    name='Temp1',      offset=0x00600400, expand=False, hidden=False,))
        self.add(LztsTemperature(    name='Temp2',      offset=0x00600800, expand=False, hidden=False,))
        self.add(LztsTemperature(    name='Temp3',      offset=0x00600C00, expand=False, hidden=False,))
        self.add(Sa56004x(           name='TempMon',    offset=0x00800000, expand=False, hidden=False,))
        self.add(TempDebug(          name='TempLocMem', offset=0x00900000, expand=False, hidden=True,))
        self.add(TempDebug(          name='TempRemMem', offset=0x00900100, expand=False, hidden=True,))
        self.add(Ltc2945(            name='PwrMonDig',  offset=0x00800400, expand=False, hidden=False,))
        self.add(Ltc2945(            name='PwrMonAna',  offset=0x00800800, expand=False, hidden=False,))
        self.add(LztsPowerRegisters( name='PwrReg',     offset=0x01000000, expand=False, hidden=False,))
        self.add(LztsPacketizer(     name='Packet',     offset=0x07000000, expand=False, hidden=False,enabled=False,))
        self.add(Pgp2bAxi(           name='Pgp2bAxi',   offset=0x02000000, expand=False, hidden=False,enabled=False,))
        self.add(SsiPrbsTx(          name='SsiPrbsTx',  offset=0x00700000, expand=False, hidden=False,enabled=False,))
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
                hidden  = False,
            ))              
        self.add(SadcBufferReader(  name='SadcBufferReader',    offset=0x04800000, enabled=False, expand=False,  hidden=False,))      
        self.add(SadcPatternTester( name='SadcPatternTester',   offset=0x04900000, enabled=False, expand=False,  hidden=True,))      
        self.add(JesdRx(            name='JesdRx',              offset=0x05000000, enabled=True,  expand=False,  numRxLanes=16, hidden=False,))      
        self.add(Lmk04828(          name='LMK',                 offset=0x05100000, expand=False,                 hidden=False,))  
        self.add(FadcDebug(         name='FadcDebug',           offset=0x05700000, enabled=False, expand=False,  hidden=False,))  
        
        for i in range(4):
            self.add(Ads54J60(
                name      = ('FastAdcConfig[%d]'%i),
                offset    = (0x05200000 + i*0x100000), 
                expand    = False, 
                hidden    = False,
            ))
                        
        for i in range(8):
            self.add(FadcBufferChannel(
                name    = ('FadcBufferChannel[%d]'%i),
                offset  = (0x06000000 + i*0x100000), 
                expand  = False, 
                enabled = False,
                hidden  = False,
            ))    
        
        self.sadcDelays = [85,88,73,79,79,79,76,91,88,80,86,84,89,81,81,89,80,83,78,76,79,78,84,91,85,84,83,81,83,85,83,83,80,88,79,81,83,79,75,82,73,81,75,69,78,79,78,71,80,86,80,77,79,80,81,88,79,77,75,75,79,85,86,84]
        self.delayRegs = self.find(name="DelayAdc*")        
        
        @self.command(description="Clear temperature fault",)
        def TempFaultClear():
            self.TempMon.ConfigurationRegisterWrite.set(0x80)
            self._root.checkBlocks(recurse=True)
            self.TempMon.ConfigurationRegisterWrite.set(0x0)
            self._root.checkBlocks(recurse=True)
            self.PwrReg.LatchTempFault.set(False)
            self._root.checkBlocks(recurse=True)
            self.PwrReg.LatchTempFault.set(True)
            self._root.checkBlocks(recurse=True)
         
        @self.command(description="Set monitoring alarms",)
        def SetMonAlarms():
            # enable thermal fault latching
            # analog power will be kept off when 70C alert threshold is crossed
            # this has to be cleared in power regs and monitor (TempFaultClear command)
            # this is before critical shutdown at 85C
            self.PwrReg.LatchTempFault.set(True) 
            self._root.checkBlocks(recurse=True)
            
            # set power monitors to alarm when the 6V DCDC is shut off (ADIN below 0.5V)
            # look at Fault register to see the alarm
            self.PwrMonAna.Alert.set(0x1)
            self._root.checkBlocks(recurse=True)
            self.PwrMonAna.MinAdinThresholdMsb.set(0x3E)
            self._root.checkBlocks(recurse=True)
            self.PwrMonAna.MinAdinThresholdLsb.set(0x80)
            self._root.checkBlocks(recurse=True)
            self.PwrMonDig.Alert.set(0x1)
            self._root.checkBlocks(recurse=True)
            self.PwrMonDig.MinAdinThresholdMsb.set(0x3E)
            self._root.checkBlocks(recurse=True)
            self.PwrMonDig.MinAdinThresholdLsb.set(0x80)
            self._root.checkBlocks(recurse=True)
            
            #set temp monitor in comparator mode (clears itself when temp drops)
            self.TempMon.AlertMode.set(1)
            #set alert threshold to 90C
            self.TempMon.RemoteHighSetpointHighByteWrite.set(90)
            self._root.checkBlocks(recurse=True)
            #set critical threshold to 100C
            self.TempMon.RemoteTCritSetpoint.set(100)
            self._root.checkBlocks(recurse=True)
        
        @self.command(description="Initialization for slow ADC idelayes",)
        def SadcInit():
            for i in range(4):
                self.SlowAdcReadout[i].enable.set(True)
                self._root.checkBlocks(recurse=True)
                self.SlowAdcReadout[i].DMode.set(3)
                self._root.checkBlocks(recurse=True)
                # Invert 0 is correct setting. Analog polarity is swapped on PCB.
                # Do not invert here! The PMT pulse is negative.
                self.SlowAdcReadout[i].Invert.set(0)
                self._root.checkBlocks(recurse=True)
                self.SlowAdcReadout[i].Convert.set(3)
                self._root.checkBlocks(recurse=True)
            for i in range(64):
                self.delayRegs[i].set(self.sadcDelays[i])
            self._root.checkBlocks(recurse=True)
            if (self.PwrReg.EnDcDcAp3V7.get()==True and self.PwrReg.EnDcDcAp2V3.get()==True and self.PwrReg.EnLdoSlow.get()==True):
                for i in range(4):
                    self.SlowAdcConfig[i].enable.set(True)
                    self._root.checkBlocks(recurse=True)
                    self.SlowAdcConfig[i].AdcReg_0x0015.set(1)  #Set DDR Mode
                    self._root.checkBlocks(recurse=True)
                    self.SlowAdcConfig[i].AdcReg_0x000B.set(0x1C)  #Set channel A digital gain -2dB (2.5Vpp input)
                    self._root.checkBlocks(recurse=True)
                    self.SlowAdcConfig[i].AdcReg_0x000C.set(0x1C)  #Set channel B digital gain -2dB (2.5Vpp input)
                    self._root.checkBlocks(recurse=True)
        
        @self.command(description="Reset slow ADCs",)
        def SadcReset():
            self.PwrReg.SADCRst.set(0xF)
            self._root.checkBlocks(recurse=True)
            self.PwrReg.SADCRst.set(0x0)
            self._root.checkBlocks(recurse=True)
        
        @self.command(description="Enable slow ADC buffers (for debug)",)
        def SadcBuffersOn():
            for i in range(8):
                self.SadcBufferWriter[i].enable.set(True)
                self._root.checkBlocks(recurse=True)
                self.SadcBufferWriter[i].ExtTrigSize.set(0x1000)
                self._root.checkBlocks(recurse=True)
                self.SadcBufferWriter[i].Enable.set(True)
                self._root.checkBlocks(recurse=True)
        
        @self.command(description="Disable slow ADC buffers (for debug)",)
        def SadcBuffersOff():
            for i in range(8):
                self.SadcBufferWriter[i].enable.set(True)
                self._root.checkBlocks(recurse=True)
                self.SadcBufferWriter[i].Enable.set(False)
                self._root.checkBlocks(recurse=True)
        
        @self.command(description="Enable fast ADC buffers (for debug)",)
        def FadcBuffersOn():
            for i in range(8):
                self.FadcBufferChannel[i].enable.set(True)
                self._root.checkBlocks(recurse=True)
                self.FadcBufferChannel[i].ExtTrigSize.set(0x3FF)
                self._root.checkBlocks(recurse=True)
                self.FadcBufferChannel[i].Enable.set(True)
                self._root.checkBlocks(recurse=True)
        
        @self.command(description="Disable fast ADC buffers (for debug)",)
        def FadcBuffersOff():
            for i in range(8):
                self.FadcBufferChannel[i].enable.set(True)
                self._root.checkBlocks(recurse=True)
                self.FadcBufferChannel[i].Enable.set(False)
                self._root.checkBlocks(recurse=True)
        
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
            
    def writeBlocks(self, force=False, recurse=True, variable=None, checkEach=False):
        """
        Write all of the blocks held by this Device to memory
        """
        if not self.enable.get(): return

        # Process local blocks.
        if variable is not None:
            variable._block.startTransaction(rim.Write, check=checkEach)
        else:
            for block in self._blocks:
                if force or block.stale:
                    if block.bulkEn:
                        block.startTransaction(rim.Write, check=checkEach)

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
            self.FadcBufferChannel[i].writeBlocks(force=force, recurse=recurse, variable=variable)            
            
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
        
        # initialize slow ADC
        self.SadcReset()
        self.SadcInit()
        
        self.TempMon.writeBlocks(  force=force, recurse=recurse, variable=variable)
        self.PwrMonAna.writeBlocks(  force=force, recurse=recurse, variable=variable)
        self.PwrMonDig.writeBlocks(  force=force, recurse=recurse, variable=variable)
        
        # set alarm thresholds
        self.SetMonAlarms()
        # clear fault in case it occured before
        self.TempFaultClear()
        