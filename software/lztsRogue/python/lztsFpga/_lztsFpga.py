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
            LztsPowerRegisters(name="LztsPowerRegisters", offset=0x05000000),
            pgp.Pgp2bAxi(name='Pgp2bAxi', offset=0x04000000, expand=False),
            ti.Ads42Lbx9(name='SlowAdcConfig0', offset=0x06000000, enabled=False, expand=False),
            ti.Ads42Lbx9(name='SlowAdcConfig1', offset=0x06000200, enabled=False, expand=False),
            ti.Ads42Lbx9(name='SlowAdcConfig2', offset=0x06000400, enabled=False, expand=False),
            ti.Ads42Lbx9(name='SlowAdcConfig3', offset=0x06000600, enabled=False, expand=False)))
      

class LztsPowerRegisters(pr.Device):
   def __init__(self, **kwargs):
      """Create the configuration device for Tixel"""
      super().__init__(description='Tixel Configuration Registers', **kwargs)
      
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
         pr.Variable(name='EnDcDcAm6V',   description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=0,  base='bool', mode='RW'),
         pr.Variable(name='EnDcDcAp5V4',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=1,  base='bool', mode='RW'),
         pr.Variable(name='EnDcDcAp3V7',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=2,  base='bool', mode='RW'),
         pr.Variable(name='EnDcDcAp2V3',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=3,  base='bool', mode='RW'),
         pr.Variable(name='EnDcDcAp1V6',  description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=4,  base='bool', mode='RW'),
         pr.Variable(name='EnLdoSlow',    description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=5,  base='bool', mode='RW'),
         pr.Variable(name='EnLdoFast',    description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=6,  base='bool', mode='RW'),
         pr.Variable(name='EnLdoAm5V',    description='PowerEnAll', offset=0x00000000, bitSize=1, bitOffset=7,  base='bool', mode='RW')))
      
      self.add((
         pr.Variable(name='PokDcDcDp6V',     description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=0,  base='bool', mode='RO'),
         pr.Variable(name='PokDcDcAp6V',     description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=1,  base='bool', mode='RO'),
         pr.Variable(name='PokDcDcAm6V',     description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=2,  base='bool', mode='RO'),
         pr.Variable(name='PokDcDcAp5V4',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=3,  base='bool', mode='RO'),
         pr.Variable(name='PokDcDcAp3V7',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=4,  base='bool', mode='RO'),
         pr.Variable(name='PokDcDcAp2V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=5,  base='bool', mode='RO'),
         pr.Variable(name='PokDcDcAp1V6',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=6,  base='bool', mode='RO'),
         pr.Variable(name='PokLdoA0p1V8',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=7,  base='bool', mode='RO'),
         pr.Variable(name='PokLdoA0p3V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=8,  base='bool', mode='RO'),
         pr.Variable(name='PokLdoAd1p1V2',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=9,  base='bool', mode='RO'),
         pr.Variable(name='PokLdoAd2p1V2',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=10, base='bool', mode='RO'),
         pr.Variable(name='PokLdoA1p1V9',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=11, base='bool', mode='RO'),
         pr.Variable(name='PokLdoA2p1V9',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=12, base='bool', mode='RO'),
         pr.Variable(name='PokLdoAd1p1V9',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=13, base='bool', mode='RO'),
         pr.Variable(name='PokLdoAd2p1V9',   description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=14, base='bool', mode='RO'),
         pr.Variable(name='PokLdoA1p3V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=15, base='bool', mode='RO'),
         pr.Variable(name='PokLdoA2p3V3',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=16, base='bool', mode='RO'),
         pr.Variable(name='PokLdoAvclkp3V3', description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=17, base='bool', mode='RO'),
         pr.Variable(name='PokLdoA0p5V0',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=18, base='bool', mode='RO'),
         pr.Variable(name='PokLdoA1p5V0',    description='PowerOkAll', offset=0x00000004, bitSize=1, bitOffset=19, base='bool', mode='RO')))
      
      self.add((
         pr.Variable(name='Led0',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=0,  base='bool', mode='RW'),
         pr.Variable(name='Led1',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=1,  base='bool', mode='RW'),
         pr.Variable(name='Led2',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=2,  base='bool', mode='RW'),
         pr.Variable(name='Led3',   description='Leds', offset=0x00000100, bitSize=1, bitOffset=3,  base='bool', mode='RW')))
      
      self.add((pr.Variable(name='SADCRst',     description='SADCRst',     offset=0x00000200, bitSize=4, bitOffset=0,  base='hex', mode='RW')))
      self.add((pr.Variable(name='SADCCtrl1',   description='SADCCtrl1',   offset=0x00000204, bitSize=4, bitOffset=0,  base='hex', mode='RW')))
      self.add((pr.Variable(name='SADCCtrl2',   description='SADCCtrl2',   offset=0x00000208, bitSize=4, bitOffset=0,  base='hex', mode='RW')))
      self.add((pr.Variable(name='SAMPEn',      description='SAMPEn',      offset=0x0000020C, bitSize=4, bitOffset=0,  base='hex', mode='RW')))
      
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

