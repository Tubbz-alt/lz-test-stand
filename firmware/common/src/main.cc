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
   
   int i;   
   
   // enable slow ADC power required for deskew procedure
   Xil_Out32(POWER_ENABLE, DCDCA_P3V7 | DCDCA_P2V3 | LDO_SLOW);
   MB_Sleep(500);
   // power up ADCs
   Xil_Out32(POWER_SADC_CTRL1, 0);
   Xil_Out32(POWER_SADC_CTRL2, 0);
   MB_Sleep(500);
   // reset ADCs
   Xil_Out32(POWER_SADC_RST, 0xf);
   MB_Sleep(500);
   Xil_Out32(POWER_SADC_RST, 0x0);
   MB_Sleep(500);
   
   for (i=0; i<4; i++) {
      // configure ADC
      //Xil_Out32(adcAddrOffset[i]+0x20, 0x10);   //ADC reg8 - data format
      Xil_Out32(adcAddrOffset[i]+0x54, 0x1);    //ADC reg 15 - DDR mode
      Xil_Out32(adcAddrOffset[i]+0x3C, 0x0);    //ADC reg F - real data
      
      //configure ADC deserializer
      Xil_Out32(adcDmodeRegs[i], 3);
      Xil_Out32(adcInvertRegs[i], 1);
      Xil_Out32(adcConvertRegs[i], 3);
   }
   
   
   //set SADC delays
   for (i=0; i<64; i++)
      Xil_Out32(adcLaneDelayRegs[i], adcLaneDelayInit[i]);
   
   while (1) {
      
      MB_Sleep(1000);
      Xil_Out32( BUS_OFFSET+0x01000100, 0x5);
      MB_Sleep(1000);
      Xil_Out32( BUS_OFFSET+0x01000100, 0xA);
      
   }
   
   
   return 0;
}

