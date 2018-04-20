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
#include "xintc.h"
#include "xparameters.h"
#include "regs.h"
#include "microblaze_sleep.h"
#include "xil_printf.h"
#include "ssi_printf.h"


#define BUS_OFFSET            (0x80000000)
#define TEMP_MON_LOC_OFFSET   (BUS_OFFSET+0x00800000)
#define TEMP_MON_REM_OFFSET   (BUS_OFFSET+0x00800004)
#define TEMP_MON_CFGWR_OFFSET (BUS_OFFSET+0x00800024)
#define PWR_REG_LOC_OFFSET    (BUS_OFFSET+0x01000020)
#define PWR_REG_REM_OFFSET    (BUS_OFFSET+0x01000024)
#define PWR_REG_INTS_OFFSET   (BUS_OFFSET+0x01000028)

static XIntc intc;

void tempAlertIntHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
   
   //clear interrupt in the SA56004
   Xil_Out32(TEMP_MON_CFGWR_OFFSET, 0x00000000);
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 0);
}

int main() { 
   
   volatile uint32_t tempAlert = 0;
   uint32_t tempAlertNum = 0;
   uint32_t tempLoc = 0;
   uint32_t tempRem = 0;
   
   Xil_Out32(EPIX_ADC_ALIGN_REG, 0x00000000);
   XIntc_Initialize(&intc,XPAR_AXI_INTC_0_DEVICE_ID);
   microblaze_enable_interrupts();
   XIntc_Connect(&intc,0,(XInterruptHandler)tempAlertIntHandler,(void*)&tempAlert);
   XIntc_Start(&intc,XIN_REAL_MODE);
   XIntc_Enable(&intc,0);
   
   while (1) {
      
      // poll interrupt flag
      if (tempAlert) {
         // clear interrupt flag
         tempAlert = 0;
         // count interrupts up to 255
         if tempAlertNum < 255
            tempAlertNum++;
         // read temperatures
         tempLoc = Xil_In32(TEMP_MON_LOC_OFFSET);
         tempRem = Xil_In32(TEMP_MON_REM_OFFSET);
         // store data in power registers
         Xil_Out32(PWR_REG_LOC_OFFSET, tempLoc);
         Xil_Out32(PWR_REG_REM_OFFSET, tempRem);
         Xil_Out32(PWR_REG_INTS_OFFSET, tempAlertNum);
      }
      
   }
   
   
   return 0;
}

