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
import surf.axi as axi
import surf.protocols.pgp as pgp
import surf.devices.ti as ti
import surf



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
      self.add((
            axi.AxiVersion(offset=0x00000000),
            LztsPowerRegisters(name="LztsPowerRegisters",   offset=0x05000000),
            pgp.Pgp2bAxi(name='Pgp2bAxi',                   offset=0x04000000, expand=False),
            ti.Ads42Lbx9Config(name='SlowAdcConfig0',       offset=0x06000000, enabled=False, expand=False),
            ti.Ads42Lbx9Config(name='SlowAdcConfig1',       offset=0x06000200, enabled=False, expand=False),
            ti.Ads42Lbx9Config(name='SlowAdcConfig2',       offset=0x06000400, enabled=False, expand=False),
            ti.Ads42Lbx9Config(name='SlowAdcConfig3',       offset=0x06000600, enabled=False, expand=False),
            ti.Ads42Lbx9Readout(name='SlowAdcReadout0',     offset=0x07000000, enabled=False, expand=False),
            ti.Ads42Lbx9Readout(name='SlowAdcReadout1',     offset=0x08000000, enabled=False, expand=False),
            ti.Ads42Lbx9Readout(name='SlowAdcReadout2',     offset=0x09000000, enabled=False, expand=False),
            ti.Ads42Lbx9Readout(name='SlowAdcReadout3',     offset=0x0A000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter0',      offset=0x0B000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter1',      offset=0x0C000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter2',      offset=0x0D000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter3',      offset=0x0E000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter4',      offset=0x0F000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter5',      offset=0x10000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter6',      offset=0x11000000, enabled=False, expand=False),
            SadcBufferWriter(name='SadcBufferWriter7',      offset=0x12000000, enabled=False, expand=False),
            SadcBufferReader(name='SadcBufferReader',       offset=0x13000000, enabled=False, expand=False)))
      

class LztsPowerRegisters(pr.Device):
   def __init__(self, **kwargs):
      """Create the configuration device for Power Controller"""
      super().__init__(description='Power Configuration Registers', **kwargs)
      
      # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
      # contains this object. In most cases the parent and memBase are the same but they can be 
      # different in more complex bus structures. They will also be different for the top most node.
      # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
      # blocks will be updated.
      
      #############################################
      # Create block / variable combinations
      #############################################
      
      
      #Setup registers & variables
      self.add((
         pr.RemoteVariable(name='EnDcDcAm6V',   description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=0,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnDcDcAp5V4',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=1,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnDcDcAp3V7',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=2,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnDcDcAp2V3',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=3,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnDcDcAp1V6',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=4,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnLdoSlow',    description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=5,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnLdoFast',    description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=6,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='EnLdoAm5V',    description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=7,  base=pr.Bool, mode='RW')))
      
      self.add((
         pr.RemoteVariable(name='PokDcDcDp6V',     description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=0,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokDcDcAp6V',     description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=1,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokDcDcAm6V',     description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=2,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokDcDcAp5V4',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=3,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokDcDcAp3V7',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=4,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokDcDcAp2V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=5,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokDcDcAp1V6',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=6,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA0p1V8',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=7,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA0p3V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=8,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoAd1p1V2',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=9,  base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoAd2p1V2',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=10, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA1p1V9',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=11, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA2p1V9',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=12, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoAd1p1V9',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=13, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoAd2p1V9',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=14, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA1p3V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=15, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA2p3V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=16, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoAvclkp3V3', description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=17, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA0p5V0',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=18, base=pr.Bool, mode='RO'),
         pr.RemoteVariable(name='PokLdoA1p5V0',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=19, base=pr.Bool, mode='RO')))
      
      self.add((
         pr.RemoteVariable(name='Led0',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=0,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='Led1',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=1,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='Led2',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=2,  base=pr.Bool, mode='RW'),
         pr.RemoteVariable(name='Led3',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=3,  base=pr.Bool, mode='RW')))
      
      self.add((pr.RemoteVariable(name='SADCRst',     description='SADCRst',     offset=0x00000200, bitSize=4, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='SADCCtrl1',   description='SADCCtrl1',   offset=0x00000204, bitSize=4, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='SADCCtrl2',   description='SADCCtrl2',   offset=0x00000208, bitSize=4, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='SAMPEn',      description='SAMPEn',      offset=0x0000020C, bitSize=4, bitOffset=0,  base=pr.UInt, mode='RW')))
      
      #####################################
      # Create commands
      #####################################
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func

class SadcBufferWriter(pr.Device):
   def __init__(self, **kwargs):
      """Create the configuration device for Slow ADC Buffer Writer"""
      super().__init__(description='Slow ADC Buffer Writer Configuration Registers', **kwargs)
      
      # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
      # contains this object. In most cases the parent and memBase are the same but they can be 
      # different in more complex bus structures. They will also be different for the top most node.
      # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
      # blocks will be updated.
      
      #############################################
      # Create block / variable combinations
      #############################################
      
      
      #Setup registers & variables
      
      self.add((pr.RemoteVariable(name='Enable',      description='Enable',      offset=0x00000000, bitSize=1,  bitOffset=0,  base=pr.Bool, mode='RW')))
      self.add((pr.RemoteVariable(name='Overflow',    description='Overflow',    offset=0x00000004, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add((pr.RemoteVariable(name='AcqCount',    description='AcqCount',    offset=0x00000008, bitSize=32, bitOffset=0,  base=pr.UInt, mode='RO')))
      self.add((pr.RemoteVariable(name='ErrCount',    description='ErrCount',    offset=0x0000000C, bitSize=32, bitOffset=0,  base=pr.UInt, mode='RO')))
      
      self.add((pr.RemoteVariable(name='IntPreThreshold',      description='IntPreThreshold',      offset=0x00000100, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='IntPostThreshold',     description='IntPostThreshold',     offset=0x00000104, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='IntVetoThreshold',     description='IntVetoThreshold',     offset=0x00000108, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='IntPreDelay',          description='IntPreDelay',          offset=0x0000010C, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='IntPostDelay',         description='IntPostDelay',         offset=0x00000110, bitSize=16, bitOffset=0,  base=pr.UInt, mode='RW')))
      self.add((pr.RemoteVariable(name='ExtTrigSize',          description='ExtTrigSize',          offset=0x00000200, bitSize=22, bitOffset=0,  base=pr.UInt, mode='RW')))
      
      #####################################
      # Create commands
      #####################################
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func

class SadcBufferReader(pr.Device):
   def __init__(self, **kwargs):
      """Create the configuration device for Slow ADC Buffer Reader"""
      super().__init__(description='Slow ADC Buffer Reader Configuration Registers', **kwargs)
      
      # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
      # contains this object. In most cases the parent and memBase are the same but they can be 
      # different in more complex bus structures. They will also be different for the top most node.
      # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
      # blocks will be updated.
      
      #############################################
      # Create block / variable combinations
      #############################################
      
      
      #Setup registers & variables
      
      
      self.addRemoteVariables(    
            name         = "SamplesCount",
            description  = "SamplesCount",
            offset       =  0x000,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            number       =  8,
            stride       =  4,            
            mode         = "RO",
        )
      
      #####################################
      # Create commands
      #####################################
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func



class MicroblazeLog(pr.Device):
   def __init__(self, **kwargs):
      super().__init__(description='Microblaze log buffer', **kwargs)
      
      # Creation. memBase is either the register bus server (srp, rce mapped memory, etc) or the device which
      # contains this object. In most cases the parent and memBase are the same but they can be 
      # different in more complex bus structures. They will also be different for the top most node.
      # The setMemBase call can be used to update the memBase for this Device. All sub-devices and local
      # blocks will be updated.
      
      #############################################
      # Create block / variable combinations
      #############################################
      
      
      #Setup registers & variables
      
      self.add((
         pr.Variable(name='MemPointer',   description='MemInfo', offset=0x00000000, bitSize=16,  bitOffset=0,  base='hex', mode='RO'),
         pr.Variable(name='MemLength',    description='MemInfo', offset=0x00000000, bitSize=16,  bitOffset=16, base='hex', mode='RO')))
      
      self.add(pr.Variable(name='MemLow',    description='MemLow',   offset=0x01*4,    bitSize=2048*8, bitOffset=0, base='string', mode='RO'))
      self.add(pr.Variable(name='MemHigh',   description='MemHigh',  offset=0x201*4,   bitSize=2044*8, bitOffset=0, base='string', mode='RO'))
      
      #####################################
      # Create commands
      #####################################
      
      # A command has an associated function. The function can be a series of
      # python commands in a string. Function calls are executed in the command scope
      # the passed arg is available as 'arg'. Use 'dev' to get to device scope.
      # A command can also be a call to a local function with local scope.
      # The command object and the arg are passed
   
   @staticmethod   
   def frequencyConverter(self):
      def func(dev, var):         
         return '{:.3f} kHz'.format(1/(self.clkPeriod * self._count(var.dependencies)) * 1e-3)
      return func

