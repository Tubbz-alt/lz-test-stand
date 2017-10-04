-------------------------------------------------------------------------------
-- Title         : PowerController
-- Project       : LZ Test Stand Development Firmware
-------------------------------------------------------------------------------
-- File          : PowerController.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 6/9/2017
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'LZ Test Stand Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LZ Test Stand Development Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 6/9/2017: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity PowerController is 
   generic (
      TPD_G             : time            := 1 ns;
      AXIL_ERR_RESP_G   : slv(1 downto 0) := AXI_RESP_DECERR_C
   );
   port ( 
      -- AXI lite slave port for register access
      axilClk           : in  sl;
      axilRst           : in  sl;
      sAxilWriteMaster  : in  AxiLiteWriteMasterType;
      sAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMaster   : in  AxiLiteReadMasterType;
      sAxilReadSlave    : out AxiLiteReadSlaveType;
      
      -- LEDs
      leds              : out slv(3 downto 0);
      
      -- power enable outs
      enDcDcAm6V        : out sl;
      enDcDcAp5V4       : out sl;
      enDcDcAp3V7       : out sl;
      enDcDcAp2V3       : out sl;
      enDcDcAp1V6       : out sl;
      enLdoSlow         : out sl;
      enLdoFast         : out sl;
      enLdoAm5V         : out sl;
      
      -- power OK ins
      pokDcDcDp6V       : in  sl;
      pokDcDcAp6V       : in  sl;
      pokDcDcAm6V       : in  sl;
      pokDcDcAp5V4      : in  sl;
      pokDcDcAp3V7      : in  sl;
      pokDcDcAp2V3      : in  sl;
      pokDcDcAp1V6      : in  sl;
      pokLdoA0p1V8      : in  sl;
      pokLdoA0p3V3      : in  sl;
      pokLdoAd1p1V2     : in  sl;
      pokLdoAd2p1V2     : in  sl;
      pokLdoA1p1V9      : in  sl;
      pokLdoA2p1V9      : in  sl;
      pokLdoAd1p1V9     : in  sl;
      pokLdoAd2p1V9     : in  sl;
      pokLdoA1p3V3      : in  sl;
      pokLdoA2p3V3      : in  sl;
      pokLdoAvclkp3V3   : in  sl;
      pokLdoA0p5V0      : in  sl;
      pokLdoA1p5V0      : in  sl;
      
      -- DCDC sync outputs
      syncDcDcDp6V      : out sl;
      syncDcDcAp6V      : out sl;
      syncDcDcAm6V      : out sl;
      syncDcDcAp5V4     : out sl;
      syncDcDcAp3V7     : out sl;
      syncDcDcAp2V3     : out sl;
      syncDcDcAp1V6     : out sl;
      syncDcDcDp3V3     : out sl;
      syncDcDcDp1V8     : out sl;
      syncDcDcDp1V2     : out sl;
      syncDcDcDp0V95    : out sl;
      syncDcDcMgt1V0    : out sl;
      syncDcDcMgt1V2    : out sl;
      syncDcDcMgt1V8    : out sl;
      
      -- slow ADC signals
      sadcRst           : out slv(3 downto 0);
      sadcCtrl1         : out slv(3 downto 0);
      sadcCtrl2         : out slv(3 downto 0);
      sampEn            : out slv(3 downto 0);
      
      -- fast ADC signals
      fadcPdn           : out slv(3 downto 0);
      fadcReset         : out slv(3 downto 0);
      
      -- DDR aresetn
      ddrRstN           : out sl
   );
end PowerController;


-- Define architecture
architecture RTL of PowerController is
   
   type RegType is record
      powerEnAll        : slv(7 downto 0);
      powerOkAll        : slv(19 downto 0);
      leds              : slv(3 downto 0);
      sadcRst           : slv(3 downto 0);
      sadcCtrl1         : slv(3 downto 0);
      sadcCtrl2         : slv(3 downto 0);
      sampEn            : slv(3 downto 0);
      fadcPdn           : slv(3 downto 0);
      fadcReset         : slv(3 downto 0);
      sAxilWriteSlave   : AxiLiteWriteSlaveType;
      sAxilReadSlave    : AxiLiteReadSlaveType;
      syncAll           : sl;
      sync              : slv(13 downto 0);
      syncClkCnt        : Slv32Array(13 downto 0);
      syncPhaseCnt      : Slv32Array(13 downto 0);
      syncHalfClk       : Slv32Array(13 downto 0);
      syncPhase         : Slv32Array(13 downto 0);
      syncOut           : slv(13 downto 0);
      ddrRstN           : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      powerEnAll        => (others=>'0'),
      powerOkAll        => (others=>'0'),
      leds              => (others=>'0'),
      sadcRst           => (others=>'0'),
      sadcCtrl1         => (others=>'1'),
      sadcCtrl2         => (others=>'1'),
      sampEn            => (others=>'0'),
      fadcPdn           => (others=>'1'),
      fadcReset         => (others=>'1'),
      sAxilWriteSlave   => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave    => AXI_LITE_READ_SLAVE_INIT_C,
      syncAll           => '0',
      sync              => (others=>'0'),
      syncClkCnt        => (others=>(others=>'0')),
      syncPhaseCnt      => (others=>(others=>'0')),
      syncHalfClk       => (others=>(others=>'0')),
      syncPhase         => (others=>(others=>'0')),
      syncOut           => (others=>'0'),
      ddrRstN           => '1'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   signal powerOkAll : slv(19 downto 0);
   
begin
   
   syncDcDcAp6V   <= r.syncOut(0);
   syncDcDcAm6V   <= r.syncOut(1);
   syncDcDcAp5V4  <= r.syncOut(2);
   syncDcDcAp3V7  <= r.syncOut(3);
   syncDcDcAp2V3  <= r.syncOut(4);
   syncDcDcAp1V6  <= r.syncOut(5);
   syncDcDcDp6V   <= r.syncOut(6);
   syncDcDcDp3V3  <= r.syncOut(7);
   syncDcDcDp1V8  <= r.syncOut(8);
   syncDcDcDp1V2  <= r.syncOut(9);
   syncDcDcDp0V95 <= r.syncOut(10);
   syncDcDcMgt1V0 <= r.syncOut(11);
   syncDcDcMgt1V2 <= r.syncOut(12);
   syncDcDcMgt1V8 <= r.syncOut(13);
   
   powerOkAll( 0) <= pokDcDcDp6V    ;
   powerOkAll( 1) <= pokDcDcAp6V    ;
   powerOkAll( 2) <= pokDcDcAm6V    ;
   powerOkAll( 3) <= pokDcDcAp5V4   ;
   powerOkAll( 4) <= pokDcDcAp3V7   ;
   powerOkAll( 5) <= pokDcDcAp2V3   ;
   powerOkAll( 6) <= pokDcDcAp1V6   ;
   powerOkAll( 7) <= pokLdoA0p1V8   ;
   powerOkAll( 8) <= pokLdoA0p3V3   ;
   powerOkAll( 9) <= pokLdoAd1p1V2  ;
   powerOkAll(10) <= pokLdoAd2p1V2  ;
   powerOkAll(11) <= pokLdoA1p1V9   ;
   powerOkAll(12) <= pokLdoA2p1V9   ;
   powerOkAll(13) <= pokLdoAd1p1V9  ;
   powerOkAll(14) <= pokLdoAd2p1V9  ;
   powerOkAll(15) <= pokLdoA1p3V3   ;
   powerOkAll(16) <= pokLdoA2p3V3   ;
   powerOkAll(17) <= pokLdoAvclkp3V3;
   powerOkAll(18) <= pokLdoA0p5V0   ;
   powerOkAll(19) <= pokLdoA1p5V0   ;
   
   
   enDcDcAm6V  <= r.powerEnAll(0);
   enDcDcAp5V4 <= r.powerEnAll(1);
   enDcDcAp3V7 <= r.powerEnAll(2);
   enDcDcAp2V3 <= r.powerEnAll(3);
   enDcDcAp1V6 <= r.powerEnAll(4);
   enLdoSlow   <= r.powerEnAll(5);
   enLdoFast   <= r.powerEnAll(6);
   enLdoAm5V   <= r.powerEnAll(7);
   
   leds <= r.leds;
   

   --------------------------------------------------
   -- AXI Lite register logic
   --------------------------------------------------

   comb : process (axilRst, sAxilReadMaster, sAxilWriteMaster, r, powerOkAll) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
   begin
      v := r;
      
      -- reset strobes
      v.syncAll := '0';
      
      -- sync inputs
      v.powerOkAll := powerOkAll;
      
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);
      
      axiSlaveRegister (regCon, x"000", 0, v.powerEnAll);
      axiSlaveRegisterR(regCon, x"004", 0, r.powerOkAll);
      
      axiSlaveRegister (regCon, x"100", 0, v.leds);
      
      -- add FSM to reset slow ADC after power ramp (see doc)
      axiSlaveRegister (regCon, x"200", 0, v.sadcRst);
      axiSlaveRegister (regCon, x"204", 0, v.sadcCtrl1);
      axiSlaveRegister (regCon, x"208", 0, v.sadcCtrl2);
      axiSlaveRegister (regCon, x"20C", 0, v.sampEn);
      
      axiSlaveRegister (regCon, x"280", 0, v.ddrRstN);
      
      axiSlaveRegister (regCon, x"300", 0, v.fadcPdn);
      axiSlaveRegister (regCon, x"304", 0, v.fadcReset);
      
      -- DCDC sync registers
      axiSlaveRegister(regCon, x"400", 0, v.syncAll);
      for i in 13 downto 0 loop
         axiSlaveRegister(regCon, x"500"+toSlv(i*4, 12), 0, v.syncHalfClk(i));
         axiSlaveRegister(regCon, x"600"+toSlv(i*4, 12), 0, v.syncPhase(i));
      end loop;
      
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);
      
      -- DCDC sync logic
      for i in 13 downto 0 loop
         -- phase counters
         if r.syncAll = '1' then
            v.syncPhaseCnt(i) := (others=>'0');
            v.sync(i)         := '1';
         elsif r.syncPhaseCnt(i) < r.syncPhase(i) then
            v.syncPhaseCnt(i) := r.syncPhaseCnt(i) + 1;
         else
            v.sync(i)         := '0';
         end if;
         -- clock counters
         if r.sync(i) = '1' then
            v.syncClkCnt(i)   := (others=>'0');
            v.syncOut(i)      := '0';
         elsif r.syncClkCnt(i) = r.syncHalfClk(i) then
            v.syncClkCnt(i)   := (others=>'0');
            v.syncOut(i)      := not r.syncOut(i);
         else
            v.syncClkCnt(i)   := r.syncClkCnt(i) + 1;
         end if;
         -- disable sync if resister is zero
         if r.syncHalfClk(i) = 0 then
            v.syncOut(i)      := '0';
         end if;
      end loop;
      
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave   <= r.sAxilWriteSlave;
      sAxilReadSlave    <= r.sAxilReadSlave;
      
      sadcRst           <= r.sadcRst;
      sadcCtrl1         <= r.sadcCtrl1;
      sadcCtrl2         <= r.sadcCtrl2;
      sampEn            <= r.sampEn;
      fadcPdn           <= r.fadcPdn;
      fadcReset         <= r.fadcReset;
      ddrRstN           <= r.ddrRstN;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   

end RTL;

