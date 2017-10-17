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

class FadcDebug(pr.Device):
    def __init__( self,       
            name        = "FadcDebug",
            description = "FadcDebug Module",
            expand      =  False,
            **kwargs):
        super().__init__(name=name, description=description, expand=expand, **kwargs)
        
        for i in range(16):      
            self.add(FadcDebugBram(  
                name    = ('BRAM[%d]'%i),   
                offset  = (i*0x10000), 
            ))
      
class FadcDebugBram(pr.Device):
    def __init__( self,       
            name        = "FadcDebugBram",
            description = "FadcDebugBram Module",
            expand      =  True,
            **kwargs):
        super().__init__(name=name, description=description, expand=expand, **kwargs)  
      
        self.addRemoteVariables(   
            name      = 'MEM',
            offset    = 0x4, # skip the header
            # bitSize   = 32,
            bitSize   = 16,
            bitOffset = 0,
            base      = pr.UInt,
            # base      = pr.Int,
            mode      = "RO",
            number    = 8, #should be 1023 but large number will be GUI slow
            stride    = 4,
        )      
