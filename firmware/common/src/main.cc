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
#define TEMP_MON_CFGWR_OFFSET (BUS_OFFSET+0x00800024)
#define PWR_REG_LOC_OFFSET    (BUS_OFFSET+0x01000020)
#define PWR_REG_REM_OFFSET    (BUS_OFFSET+0x01000024)
#define PWR_REG_INTS_OFFSET   (BUS_OFFSET+0x01000028)

#define LOC_TEMP_MEM_OFFSET   (BUS_OFFSET+0x00900000)
#define REM_TEMP_MEM_OFFSET   (BUS_OFFSET+0x00900100)

static XIntc intc;

void tempAlertIntHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 0);
}

void tempAlertClrHandler(void * data) {
   uint32_t * request = (uint32_t *)data;
 
   (*request) = 1; 
   
   XIntc_Acknowledge(&intc, 1);
}

void timerIntHandler(void * data, unsigned char num ) {
   uint32_t * timer = (uint32_t *)data;
   
   (*timer) ++; 
   
   XIntc_Acknowledge(&intc, 8);
   
}

int main() { 
   
   volatile uint32_t tempAlertInt = 0;
   volatile uint32_t tempAlertClr = 0;
   volatile uint32_t timer = 0;
   uint32_t tempAlertNum = 0;
   uint32_t tempLoc = 0;
   uint32_t tempRem = 0;
   uint32_t samples = 0;
   
   
   XTmrCtr  tmrctr;
   
   XTmrCtr_Initialize(&tmrctr,0);   
   
   XIntc_Initialize(&intc,XPAR_U_CORE_U_CPU_U_MICROBLAZE_AXI_INTC_0_DEVICE_ID);
   microblaze_enable_interrupts();
   XIntc_Connect(&intc,0,(XInterruptHandler)tempAlertIntHandler,(void*)&tempAlertInt);
   XIntc_Connect(&intc,1,(XInterruptHandler)tempAlertClrHandler,(void*)&tempAlertClr);
   XIntc_Connect(&intc,8,XTmrCtr_InterruptHandler,&tmrctr);
   XIntc_Start(&intc,XIN_REAL_MODE);
   XIntc_Enable(&intc,0);
   XIntc_Enable(&intc,1);
   XIntc_Enable(&intc,8);
   
   
   XTmrCtr_SetHandler(&tmrctr,timerIntHandler,(void*)&timer);
   XTmrCtr_SetOptions(&tmrctr,0,XTC_DOWN_COUNT_OPTION | XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);
   XTmrCtr_SetResetValue(&tmrctr,0,19531250);   // 31250000 - 125ms at 156.25MHz
   
   
   while (1) {
      
      // poll temp alert interrupt flag
      if (tempAlertInt) {
         // clear interrupt flag
         tempAlertInt = 0;
         // count interrupts up to 255
         if (tempAlertNum < 255)
            tempAlertNum++;
         // read temperatures
         tempLoc = Xil_In32(TEMP_MON_LOC_OFFSET);
         tempRem = Xil_In32(TEMP_MON_REM_OFFSET);
         // store data in power registers
         Xil_Out32(PWR_REG_LOC_OFFSET, tempLoc);
         Xil_Out32(PWR_REG_REM_OFFSET, tempRem);
         Xil_Out32(PWR_REG_INTS_OFFSET, tempAlertNum);
         
         // use timer to collect several samples at 125ms intervals
         samples = 0;
         timer = 0;
         while(samples < 256) {
            
            // start timer and wait for interrupt
            XTmrCtr_Start(&tmrctr,0);
            while(timer == 0);
            timer = 0;
            XTmrCtr_Stop(&tmrctr,0);
            
            //read temperature and store to memory
            if ((samples&0x3) == 0) {
               tempLoc = (Xil_In32(TEMP_MON_LOC_OFFSET)&0xFF);
               tempRem = (Xil_In32(TEMP_MON_REM_OFFSET)&0xFF);
            } 
            else if ((samples&0x3) == 1) {
               tempLoc |= ((Xil_In32(TEMP_MON_LOC_OFFSET)&0xFF)<<8);
               tempRem |= ((Xil_In32(TEMP_MON_REM_OFFSET)&0xFF)<<8);
            }
            else if ((samples&0x3) == 2) {
               tempLoc |= ((Xil_In32(TEMP_MON_LOC_OFFSET)&0xFF)<<16);
               tempRem |= ((Xil_In32(TEMP_MON_REM_OFFSET)&0xFF)<<16);
            }
            else if ((samples&0x3) == 3) {
               tempLoc |= ((Xil_In32(TEMP_MON_LOC_OFFSET)&0xFF)<<24);
               tempRem |= ((Xil_In32(TEMP_MON_REM_OFFSET)&0xFF)<<24);
               //write to memory after every 4 samples are combined
               Xil_Out32(LOC_TEMP_MEM_OFFSET+samples-3, tempLoc);
               Xil_Out32(REM_TEMP_MEM_OFFSET+samples-3, tempRem);
            }
            
            samples++;
         }
         
         
      }
      
      // poll temp alert clear interrupt flag
      if (tempAlertClr) {
         // clear interrupt flag
         tempAlertClr = 0;
         //clear interrupt in the SA56004
         Xil_Out32(TEMP_MON_CFGWR_OFFSET, 0x00000000);
      }
      
   }
   
   
   return 0;
}

