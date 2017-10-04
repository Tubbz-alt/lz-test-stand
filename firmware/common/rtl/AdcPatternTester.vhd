-------------------------------------------------------------------------------
-- File       : AdcPatternTester.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 05/27/2016
-- Last update: 05/27/2016
-------------------------------------------------------------------------------
-- Description:   Test which compares the data stream to selected pattern
--                Designed for the automated delay alignment of the fast LVDS lines  
--                of ADCs with single or multiple serial data lanes
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity AdcPatternTester is 
   generic (
      TPD_G             : time                  := 1 ns;
      ADC_BITS_G        : integer range 8 to 32 := 16;
      NUM_CHANNELS_G    : integer range 1 to 31 := 8
   );
   port ( 
      -- ADC Interface
      adcClk            : in  sl;
      adcRst            : in  sl;
      adcData           : in  Slv32Array(NUM_CHANNELS_G-1 downto 0);
      
      -- Axi Interface
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      
      -- Direct status bits
      testDone          : out sl;
      testFailed        : out sl
   );
end AdcPatternTester;


-- Define architecture
architecture RTL of AdcPatternTester is

   -------------------------------------------------------------------------------------------------
   -- AXIL Registers
   -------------------------------------------------------------------------------------------------
   type AxilRegType is record
      axilWriteSlave : AxiLiteWriteSlaveType;
      axilReadSlave  : AxiLiteReadSlaveType;
      testChannel    : slv(31 downto 0);
      testPattern    : slv(31 downto 0);
      testDataMask   : slv(31 downto 0);
      testSamples    : slv(31 downto 0);
      testCnt        : slv(31 downto 0);
      testRequest    : sl;
      testDone       : sl;
      testFailed     : sl;
   end record;

   constant AXIL_REG_INIT_C : AxilRegType := (
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      testChannel    => (others=>'0'),
      testPattern    => (others=>'0'),
      testDataMask   => (others=>'1'),
      testSamples    => (others=>'0'),
      testCnt        => (others=>'0'),
      testRequest    => '0',
      testDone       => '0',
      testFailed     => '0'
   );
   
   type StateType is (
      IDLE_S,
      TEST_S
   );
   
   type AdcRegType is record
      testChannel    : natural;
      testPattern    : slv(31 downto 0);
      testDataMask   : slv(31 downto 0);
      testSamples    : slv(31 downto 0);
      testRequest    : slv(1 downto 0);
      testDone       : sl;
      testFailed     : sl;
      state          : StateType;
      testCnt        : slv(31 downto 0);
   end record;
   
   constant ADC_REG_INIT_C : AdcRegType := (
      testChannel    => 0,
      testPattern    => (others=>'0'),
      testDataMask   => (others=>'1'),
      testSamples    => (others=>'0'),
      testRequest    => "00",
      testDone       => '0',
      testFailed     => '0',
      state          => IDLE_S,
      testCnt        => (others=>'0')
   );

   signal axilR   : AxilRegType := AXIL_REG_INIT_C;
   signal axilRin : AxilRegType;
   
   signal adcR    : AdcRegType  := ADC_REG_INIT_C;
   signal adcRin  : AdcRegType;
   
begin

   -------------------------------------------------------------------------------------------------
   -- AXIL Interface (axilClk)
   -- ADC Test Logic (adcClk)
   -------------------------------------------------------------------------------------------------
   combProc : process (axilR, axilRst, axilReadMaster, axilWriteMaster, adcR, adcRst, adcData) is
      variable vAxi     : AxilRegType;
      variable axilEp   : AxiLiteEndpointType;
      variable vAdc     : AdcRegType;
      variable dataMux  : slv(31 downto 0);
   begin
      vAxi := axilR;
      vAdc := adcR;
      
      ------------------------------------------
      -- Cross clock domain
      ------------------------------------------
      if adcR.state = IDLE_S then
         vAdc.testChannel     := conv_integer(axilR.testChannel);
         vAdc.testDataMask    := axilR.testDataMask;
         vAdc.testPattern     := axilR.testPattern;
         vAdc.testSamples     := axilR.testSamples;
         vAdc.testRequest(0)  := axilR.testRequest;
      end if;
      vAxi.testDone        := adcR.testDone;
      vAxi.testFailed      := adcR.testFailed;
      vAxi.testCnt         := adcR.testCnt;
      
      ------------------------------------------
      -- Register interface
      ------------------------------------------
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, vAxi.axilWriteSlave, vAxi.axilReadSlave);

      axiSlaveRegister (axilEp, X"000", 0, vAxi.testChannel);
      axiSlaveRegister (axilEp, X"004", 0, vAxi.testDataMask);
      axiSlaveRegister (axilEp, X"008", 0, vAxi.testPattern);
      axiSlaveRegister (axilEp, X"00C", 0, vAxi.testSamples);
      axiSlaveRegister (axilEp, X"010", 0, vAxi.testRequest);
      axiSlaveRegisterR(axilEp, X"014", 0, axilR.testDone);
      axiSlaveRegisterR(axilEp, X"018", 0, axilR.testFailed);
      axiSlaveRegisterR(axilEp, X"01C", 0, axilR.testCnt);

      axiSlaveDefault(axilEp, vAxi.axilWriteSlave, vAxi.axilReadSlave, AXI_RESP_DECERR_C);
      
      ------------------------------------------
      -- ADC Pattern Tester Logic
      ------------------------------------------
      
      -- delayed ADC test request
      vAdc.testRequest(1) := adcR.testRequest(0);
      
      -- data mux and mask
      dataMux := adcData(adcR.testChannel);
      for i in 0 to 31 loop
         dataMux(i) := dataMux(i) and adcR.testDataMask(i);
      end loop;
      
      -- Test FSM
      case adcR.state is
         
         when IDLE_S =>
            if (adcR.testRequest(0) = '1' and adcR.testRequest(1) = '0') then
               -- clear previous results
               vAdc.testDone     := '0';
               vAdc.testFailed   := '0';
               vAdc.testCnt      := (others=>'0');
               -- start testing
               vAdc.state        := TEST_S;
            end if;
         
         when TEST_S =>
            -- count requested samples
            -- when all done and no mismatch then success
            if adcR.testCnt < adcR.testSamples then
               vAdc.testCnt := adcR.testCnt + 1;
            else
               vAdc.testDone     := '1';
               vAdc.testFailed   := '0';
               vAdc.state        := IDLE_S;
            end if;
            
            -- compare with requested pattern
            -- fail test when mismatch
            if dataMux(ADC_BITS_G-1 downto 0) /= adcR.testPattern(ADC_BITS_G-1 downto 0) then
               vAdc.testCnt      := adcR.testCnt;
               vAdc.testDone     := '1';
               vAdc.testFailed   := '1';
               vAdc.state        := IDLE_S;
            end if;
         
         when others =>
            vAdc.state := IDLE_S;
         
      end case;
      
      ------------------------------------------
      -- Reset logic
      ------------------------------------------
      if (axilRst = '1') then
         vAxi := AXIL_REG_INIT_C;
      end if;
      if (adcRst = '1') then
         vAdc := ADC_REG_INIT_C;
      end if;

      axilRin        <= vAxi;
      adcRin         <= vAdc;
      axilWriteSlave <= axilR.axilWriteSlave;
      axilReadSlave  <= axilR.axilReadSlave;
      testDone       <= vAxi.testDone;
      testFailed     <= vAxi.testFailed;

   end process;

   axilSeq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         axilR <= axilRin after TPD_G;
      end if;
   end process axilSeq;
   
   adcSeq : process (adcClk) is
   begin
      if (rising_edge(adcClk)) then
         adcR <= adcRin after TPD_G;
      end if;
   end process adcSeq;
   
end RTL;

