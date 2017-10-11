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
