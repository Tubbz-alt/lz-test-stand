-------------------------------------------------------------------------------
-- File       : PowerController.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-06-09
-- Last update: 2018-03-13
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'LZ Test Stand Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LZ Test Stand Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AppPkg.all;

entity PowerController is
   generic (
      TPD_G           : time            := 1 ns;
      USE_DCDC_SYNC_G : boolean         := false;
      AXIL_ERR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (
      -- AXI lite slave port for register access
      axilClk          : in  sl;
      axilRst          : in  sl;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType;
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      -- System Ports
      sysRst           : out sl;
      pwrCtrlIn        : in  PwrCtrlInType;
      pwrCtrlOut       : out PwrCtrlOutType;
      -- slow ADC signals
      sadcRst          : out slv(3 downto 0);
      sadcCtrl1        : out slv(3 downto 0);
      sadcCtrl2        : out slv(3 downto 0);
      sampEn           : out slv(3 downto 0);
      -- fast ADC signals
      fadcPdn          : out slv(3 downto 0);
      fadcReset        : out slv(3 downto 0);
      -- DDR aresetn
      ddrRstN          : out sl);
end PowerController;


-- Define architecture
architecture RTL of PowerController is

   type RegType is record
      tempFault       : slv(1 downto 0);
      latchTempFault  : sl;
      ignTempAlert    : slv(1 downto 0);
      powerEnAll      : slv(7 downto 0);
      powerOkAll      : slv(19 downto 0);
      sadcRst         : slv(3 downto 0);
      sadcCtrl1       : slv(3 downto 0);
      sadcCtrl2       : slv(3 downto 0);
      sampEn          : slv(3 downto 0);
      fadcPdn         : slv(3 downto 0);
      fadcReset       : slv(3 downto 0);
      sAxilWriteSlave : AxiLiteWriteSlaveType;
      sAxilReadSlave  : AxiLiteReadSlaveType;
      syncAll         : sl;
      sync            : slv(13 downto 0);
      syncClkCnt      : Slv32Array(13 downto 0);
      syncPhaseCnt    : Slv32Array(13 downto 0);
      syncHalfClk     : Slv32Array(13 downto 0);
      syncPhase       : Slv32Array(13 downto 0);
      syncOut         : slv(13 downto 0);
      ddrRstN         : sl;
      sysRstShift     : slv(7 downto 0);
      sysRst          : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      tempFault       => "00",
      latchTempFault  => '0',
      ignTempAlert    => (others => '0'),
      powerEnAll      => (others => '0'),
      powerOkAll      => (others => '0'),
      sadcRst         => (others => '0'),
      sadcCtrl1       => (others => '1'),
      sadcCtrl2       => (others => '1'),
      sampEn          => (others => '0'),
      fadcPdn         => (others => '1'),
      fadcReset       => (others => '1'),
      sAxilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      syncAll         => '0',
      sync            => (others => '0'),
      syncClkCnt      => (others => (others => '0')),
      syncPhaseCnt    => (others => (others => '0')),
      syncHalfClk     => (others => (others => '0')),
      syncPhase       => (others => (others => '0')),
      syncOut         => (others => '0'),
      ddrRstN         => '1',
      sysRstShift     => (others => '0'),
      sysRst          => '0'
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal powerOkAll : slv(19 downto 0);
   signal tempAlert  : slv(1 downto 0);

begin

   pwrCtrlOut.syncDcDcAp6V   <= r.syncOut(0);
   pwrCtrlOut.syncDcDcAm6V   <= r.syncOut(1);
   pwrCtrlOut.syncDcDcAp5V4  <= r.syncOut(2);
   pwrCtrlOut.syncDcDcAp3V7  <= r.syncOut(3);
   pwrCtrlOut.syncDcDcAp2V3  <= r.syncOut(4);
   pwrCtrlOut.syncDcDcAp1V6  <= r.syncOut(5);
   pwrCtrlOut.syncDcDcDp6V   <= r.syncOut(6);
   pwrCtrlOut.syncDcDcDp3V3  <= r.syncOut(7);
   pwrCtrlOut.syncDcDcDp1V8  <= r.syncOut(8);
   pwrCtrlOut.syncDcDcDp1V2  <= r.syncOut(9);
   pwrCtrlOut.syncDcDcDp0V95 <= r.syncOut(10);
   pwrCtrlOut.syncDcDcMgt1V0 <= r.syncOut(11);
   pwrCtrlOut.syncDcDcMgt1V2 <= r.syncOut(12);
   pwrCtrlOut.syncDcDcMgt1V8 <= r.syncOut(13);

   powerOkAll(0)  <= pwrCtrlIn.pokDcDcDp6V;
   powerOkAll(1)  <= pwrCtrlIn.pokDcDcAp6V;
   powerOkAll(2)  <= pwrCtrlIn.pokDcDcAm6V;
   powerOkAll(3)  <= pwrCtrlIn.pokDcDcAp5V4;
   powerOkAll(4)  <= pwrCtrlIn.pokDcDcAp3V7;
   powerOkAll(5)  <= pwrCtrlIn.pokDcDcAp2V3;
   powerOkAll(6)  <= pwrCtrlIn.pokDcDcAp1V6;
   powerOkAll(7)  <= pwrCtrlIn.pokLdoA0p1V8;
   powerOkAll(8)  <= pwrCtrlIn.pokLdoA0p3V3;
   powerOkAll(9)  <= pwrCtrlIn.pokLdoAd1p1V2;
   powerOkAll(10) <= pwrCtrlIn.pokLdoAd2p1V2;
   powerOkAll(11) <= pwrCtrlIn.pokLdoA1p1V9;
   powerOkAll(12) <= pwrCtrlIn.pokLdoA2p1V9;
   powerOkAll(13) <= pwrCtrlIn.pokLdoAd1p1V9;
   powerOkAll(14) <= pwrCtrlIn.pokLdoAd2p1V9;
   powerOkAll(15) <= pwrCtrlIn.pokLdoA1p3V3;
   powerOkAll(16) <= pwrCtrlIn.pokLdoA2p3V3;
   powerOkAll(17) <= pwrCtrlIn.pokLdoAvclkp3V3;
   powerOkAll(18) <= pwrCtrlIn.pokLdoA0p5V0;
   powerOkAll(19) <= pwrCtrlIn.pokLdoA1p5V0;

   pwrCtrlOut.enDcDcAm6V  <= '1' when r.powerEnAll(0) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enDcDcAp5V4 <= '1' when r.powerEnAll(1) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enDcDcAp3V7 <= '1' when r.powerEnAll(2) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enDcDcAp2V3 <= '1' when r.powerEnAll(3) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enDcDcAp1V6 <= '1' when r.powerEnAll(4) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enLdoSlow   <= '1' when r.powerEnAll(5) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enLdoFast   <= '1' when r.powerEnAll(6) = '1' and r.tempFault = 0 else '0';
   pwrCtrlOut.enLdoAm5V   <= '1' when r.powerEnAll(7) = '1' and r.tempFault = 0 else '0';

   GEN_VEC :
   for i in 1 downto 0 generate
      U_Debouncer : entity work.Debouncer
         generic map(
            TPD_G             => TPD_G,
            INPUT_POLARITY_G  => '0',   -- active LOW
            OUTPUT_POLARITY_G => '1',   -- active HIGH
            FILTER_SIZE_G     => 16,
            SYNCHRONIZE_G     => true)  -- Run input through 2 FFs before filtering
         port map(
            clk => axilClk,
            i   => pwrCtrlIn.tempAlertL(i),
            o   => tempAlert(i));
   end generate GEN_VEC;

   --------------------------------------------------
   -- AXI Lite register logic
   --------------------------------------------------

   comb : process (axilRst, powerOkAll, r, sAxilReadMaster, sAxilWriteMaster,
                   tempAlert) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      v := r;

      -- reset strobes
      v.syncAll := '0';

      -- sync inputs
      v.powerOkAll := powerOkAll;

      -- Generate the tempFault
      if (r.latchTempFault = '0') then
         v.tempFault := "00";
      end if;
      for i in 1 downto 0 loop
         if (r.ignTempAlert(i) = '0') and (tempAlert(i) = '1') then
            v.tempFault(i) := '1';
         end if;
      end loop;

      -- Determine the AXI-Lite transaction
      v.sAxilReadSlave.rdata := (others => '0');
      axiSlaveWaitTxn(regCon, sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave);

      axiSlaveRegister (regCon, x"000", 0, v.powerEnAll);
      axiSlaveRegisterR(regCon, x"004", 0, r.powerOkAll);
      axiSlaveRegister (regCon, x"008", 0, v.sysRstShift(0));

      axiSlaveRegisterR(regCon, x"010", 0, tempAlert);
      axiSlaveRegisterR(regCon, x"014", 0, r.tempFault);
      axiSlaveRegister (regCon, x"018", 0, v.ignTempAlert);
      axiSlaveRegister (regCon, x"01C", 0, v.latchTempFault);

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

      -- Close out the AXI-Lite transaction
      axiSlaveDefault(regCon, v.sAxilWriteSlave, v.sAxilReadSlave, AXIL_ERR_RESP_G);

      -- DCDC sync logic
      for i in 13 downto 0 loop
         if USE_DCDC_SYNC_G = true then
            -- phase counters
            if r.syncAll = '1' then
               v.syncPhaseCnt(i) := (others => '0');
               v.sync(i)         := '1';
            elsif r.syncPhaseCnt(i) < r.syncPhase(i) then
               v.syncPhaseCnt(i) := r.syncPhaseCnt(i) + 1;
            else
               v.sync(i) := '0';
            end if;
            -- clock counters
            if r.sync(i) = '1' then
               v.syncClkCnt(i) := (others => '0');
               v.syncOut(i)    := '0';
            elsif r.syncClkCnt(i) = r.syncHalfClk(i) then
               v.syncClkCnt(i) := (others => '0');
               v.syncOut(i)    := not r.syncOut(i);
            else
               v.syncClkCnt(i) := r.syncClkCnt(i) + 1;
            end if;
            -- disable sync if resister is zero
            if r.syncHalfClk(i) = 0 then
               v.syncOut(i) := '0';
            end if;
         else
            -- remove sync functionality if not required
            v.syncPhaseCnt(i) := (others => '0');
            v.syncClkCnt(i)   := (others => '0');
            v.sync(i)         := '0';
            v.syncOut(i)      := '0';
         end if;
      end loop;

      -- software reset logic
      v.sysRstShift := r.sysRstShift(6 downto 0) & '0';
      if r.sysRstShift /= 0 then
         v.sysRst := '1';
      else
         v.sysRst := '0';
      end if;

      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      sAxilWriteSlave <= r.sAxilWriteSlave;
      sAxilReadSlave  <= r.sAxilReadSlave;

      sadcRst   <= r.sadcRst;
      sadcCtrl1 <= r.sadcCtrl1;
      sadcCtrl2 <= r.sadcCtrl2;
      sampEn    <= r.sampEn;
      fadcPdn   <= r.fadcPdn;
      fadcReset <= r.fadcReset;
      ddrRstN   <= r.ddrRstN;
      sysRst    <= r.sysRst;

   end process comb;

   seq : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


end RTL;

