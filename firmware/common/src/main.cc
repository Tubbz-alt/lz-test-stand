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
#include "microblaze_sleep.h"
#include "xil_printf.h"
#include "ssi_printf.h"
#include "xtmrctr.h"


#define BUS_OFFSET            (0x80000000)
#define TEMP_MON_LOC_OFFSET   (BUS_OFFSET+0x00800000)
#define TEMP_MON_REM_OFFSET   (BUS_OFFSET+0x00800004)
#define PWR_REG_LOC_OFFSET    (BUS_OFFSET+0x01000020)
#define PWR_REG_REM_OFFSET    (BUS_OFFSET+0x01000024)
#define PWR_REG_MPTR_OFFSET   (BUS_OFFSET+0x01000028)
#define PWR_REG_FAULT_OFFSET  (BUS_OFFSET+0x01000014)

#define LOC_TEMP_MEM_OFFSET   (BUS_OFFSET+0x00900000)
#define REM_TEMP_MEM_OFFSET   (BUS_OFFSET+0x00900100)

static XIntc intc;



typedef struct timerStruct {
   uint32_t counter;
   uint32_t flag;
} timerStructType;


void tempAlertIntHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 0);
}

void timerIntHandler(void * data, unsigned char num ) {
   timerStructType * timer = (timerStructType *)data;
   
   timer->counter++; 
   timer->flag = 1; 
   
   XIntc_Acknowledge(&intc, 8);
   
}

int main() { 
   
   volatile uint32_t tempAlertInt = 0;
   volatile timerStructType timer = {0, 0};
   uint32_t tempAlertNum = 0;
   uint32_t tempLoc = 0;
   uint32_t tempRem = 0;
   uint32_t samples = 0;
   uint32_t postSamples = 0;
   uint32_t wasTempAlert = 0;
   uint32_t shift = 0;
   
   
   XTmrCtr  tmrctr;
   
   XTmrCtr_Initialize(&tmrctr,0);   
   
   XIntc_Initialize(&intc,XPAR_U_CORE_U_CPU_U_MICROBLAZE_AXI_INTC_0_DEVICE_ID);
   microblaze_enable_interrupts();
   XIntc_Connect(&intc,0,(XInterruptHandler)tempAlertIntHandler,(void*)&tempAlertInt);
   XIntc_Connect(&intc,8,XTmrCtr_InterruptHandler,&tmrctr);
   XIntc_Start(&intc,XIN_REAL_MODE);
   XIntc_Enable(&intc,0);
   XIntc_Enable(&intc,8);
   
   
   XTmrCtr_SetHandler(&tmrctr,timerIntHandler,(void*)&timer);
   XTmrCtr_SetOptions(&tmrctr,0,XTC_DOWN_COUNT_OPTION | XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);
   XTmrCtr_SetResetValue(&tmrctr,0,39062500);   // 250ms at 156.25MHz
   XTmrCtr_Start(&tmrctr,0);
   
   while (1) {
      
      // poll temp alert interrupt flag
      if (tempAlertInt and tempAlertNum==0) {
         // clear interrupt flag
         tempAlertInt = 0;
         // save event flag
         wasTempAlert = 1;
         // count interrupts up to 255
         if (tempAlertNum < 255)
            tempAlertNum++;
         // read temperatures
         tempLoc = Xil_In32(TEMP_MON_LOC_OFFSET);
         tempRem = Xil_In32(TEMP_MON_REM_OFFSET);
         // store data in power registers
         Xil_Out32(PWR_REG_LOC_OFFSET, tempLoc);
         Xil_Out32(PWR_REG_REM_OFFSET, tempRem);
      }
      
      // use timer to collect before and after samples at 250ms intervals
      if(timer.flag and postSamples<128) {
         
         // clear interrupt flag
         timer.flag = 0;
         
         //read temperature and store to memory         
         shift = samples&0x3;
         
         //read 32 bit mem
         tempLoc = Xil_In32(LOC_TEMP_MEM_OFFSET+(samples&0xFC));
         tempRem = Xil_In32(REM_TEMP_MEM_OFFSET+(samples&0xFC));
         //modify 8 bit from sensor
         tempLoc &= ~((0xFF)<<(shift*8));
         tempRem &= ~((0xFF)<<(shift*8));
         tempLoc |= ((Xil_In32(TEMP_MON_LOC_OFFSET)&0xFF)<<(shift*8));
         tempRem |= ((Xil_In32(TEMP_MON_REM_OFFSET)&0xFF)<<(shift*8));
         //write 32 bit mem
         Xil_Out32(LOC_TEMP_MEM_OFFSET+(samples&0xFC), tempLoc);
         Xil_Out32(REM_TEMP_MEM_OFFSET+(samples&0xFC), tempRem);
         
         
         //save last post sample address
         if(postSamples==127)
            Xil_Out32(PWR_REG_MPTR_OFFSET, samples);
         
         samples++;
         if(samples > 255)
            samples = 0;
         if(wasTempAlert)
            postSamples++;
      }
      
      
      // poll tepmFault register at 250ms intervals
      if(timer.flag and postSamples>=128) {
         
         // clear interrupt flag
         timer.flag = 0;
         
         // clear variables when alert was cleared
         if(Xil_In32(PWR_REG_FAULT_OFFSET)==0) {
            postSamples=0;
            wasTempAlert=0;
            tempAlertNum=0;
            Xil_Out32(PWR_REG_MPTR_OFFSET, 0);
         }
      }
      
      
   }
   
   
   return 0;
}

