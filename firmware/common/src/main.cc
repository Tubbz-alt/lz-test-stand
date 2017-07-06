//////////////////////////////////////////////////////////////////////////////
// This file is part of 'CPIX Development Firmware'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'CPIX Development Firmware', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <stdio.h>
#include <string.h>
#include "xil_types.h"
#include "xil_io.h"
#include "microblaze_sleep.h"
#include "xil_printf.h"
#include "regs.h"
#include "ssi_printf.h"


#define BUS_OFFSET         (0x80000000)

int main() { 
   
   
   //xil_printf("Version %x\n\r",     Xil_In32(BUS_OFFSET+0x00000000));
   //xil_printf("PGP Bits %x\n\r",    Xil_In32(BUS_OFFSET+0x04000020));
   //xil_printf("PGP RX CLK %d\n\r",    Xil_In32(BUS_OFFSET+0x04000064));
   //xil_printf("PGP TX CLK %d\n\r",    Xil_In32(BUS_OFFSET+0x04000068));
   //xil_printf("PGP RX cellErrorCount %d\n\r",    Xil_In32(BUS_OFFSET+0x04000028));
   //xil_printf("PGP RX linkDownCount %d\n\r",    Xil_In32(BUS_OFFSET+0x0400002C));
   //xil_printf("PGP RX linkErrorCount %d\n\r",    Xil_In32(BUS_OFFSET+0x04000030));
   //xil_printf("PGP RX remOverflow0Cnt %d\n\r",    Xil_In32(BUS_OFFSET+0x04000034));
   //xil_printf("PGP RX remOverflow1Cnt %d\n\r",    Xil_In32(BUS_OFFSET+0x04000038));
   //xil_printf("PGP RX remOverflow2Cnt %d\n\r",    Xil_In32(BUS_OFFSET+0x0400003C));
   //xil_printf("PGP RX remOverflow3Cnt %d\n\r",    Xil_In32(BUS_OFFSET+0x04000040));
   //xil_printf("PGP RX frameErrCount %d\n\r",    Xil_In32(BUS_OFFSET+0x04000044));
   //xil_printf("PGP RX frameCount %d\n\r",    Xil_In32(BUS_OFFSET+0x04000048));
   //xil_printf("MemTester rdy %x\n\r",    Xil_In32(BUS_OFFSET+0x03000100)&0x1);
   //xil_printf("MemTester err %x\n\r",    Xil_In32(BUS_OFFSET+0x03000104)&0x1);
   //xil_printf("MemTester wTimer %d\n\r",    Xil_In32(BUS_OFFSET+0x03000108));
   //xil_printf("MemTester rTimer %d\n\r",    Xil_In32(BUS_OFFSET+0x0300010C));
   
   while (1) {
      
      MB_Sleep(1000);
      Xil_Out32( BUS_OFFSET+0x05000100, 0x5);
      MB_Sleep(1000);
      Xil_Out32( BUS_OFFSET+0x05000100, 0xA);
      
   }
   
   
   return 0;
}

