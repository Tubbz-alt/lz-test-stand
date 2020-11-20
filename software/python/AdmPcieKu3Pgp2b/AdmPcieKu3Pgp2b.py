#!/usr/bin/env python
##############################################################################
## This file is part of 'camera-link-gen1'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'camera-link-gen1', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import pyrogue as pr
#import rogue.hardware.data
import rogue.hardware.axi

#from DataLib.DataDev import *
from surf.xilinx import *
from surf.protocols.pgp import *

class AdmPcieKu3Pgp2b(pr.Device):
    def __init__(   self,       
            name        = "AdmPcieKu3Pgp2b",
            description = "Container for application registers",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        ## Add axi-pcie-core 
        #self.add(DataDev(            
        #    offset       = 0x00000000, 
        #    expand       = False,
        #))  

        # Add PGP Core 
        for i in range(7):
            self.add(Pgp2bAxi(            
                name         = ('Lane[%i]' % i), 
                offset       = (0x00801000 + i*0x00010000), 
                expand       = False,
            ))
            