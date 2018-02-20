-------------------------------------------------------------------------------
-- File       : FadcPacketizer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-14
-- Last update: 2017-07-14
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

entity FadcPacketizer is
   generic (
      TPD_G             : time                     := 1 ns;
      AXI_ERROR_RESP_G  : slv(1 downto 0)          := AXI_RESP_DECERR_C
   );
   port (
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AxiStream interface (axisClk domain)
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisRxMaster      : in  AxiStreamMasterType;
      axisRxSlave       : out AxiStreamSlaveType;
      axisTxMaster      : out AxiStreamMasterType;
      axisTxSlave       : in  AxiStreamSlaveType;
      -- Device DNA input
      dnaValue          : in slv(127 downto 0)
   );
end FadcPacketizer;

architecture rtl of FadcPacketizer is
   
   constant AXIS_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   type StateType is (
      IDLE_S,
      PACKET_S,
      WAIT_PKT_S,
      FOOTER_S
   );
   
   type StrType is record
      enable         : sl;
      dataSize       : slv(29 downto 0);
      timeout        : slv(31 downto 0);
      rxSlave        : AxiStreamSlaveType;
      txMaster       : AxiStreamMasterType;
      gTime          : slv(63 downto 0);
      gTimeMin       : slv(63 downto 0);
      gTimeMax       : slv(63 downto 0);
      hdrCnt         : slv(15 downto 0);
      dataCnt        : slv(29 downto 0);
      timeCnt        : slv(31 downto 0);
      dnaValue       : slv(127 downto 0);
      lostTrigFlag   : sl;
      emptyTrigFlag  : sl;
      extTrigFlag    : sl;
      intTrigFlag    : sl;
      vetoTrigFlag   : sl;
      badAdcFlag     : sl;
      state          : StateType;
   end record StrType;
   
   constant STR_INIT_C : StrType := (
      enable         => '0',
      dataSize       => (others=>'0'),
      timeout        => (others=>'0'),
      rxSlave        => AXI_STREAM_SLAVE_INIT_C,
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      gTime          => (others=>'0'),
      gTimeMin       => (others=>'1'),
      gTimeMax       => (others=>'0'),
      hdrCnt         => (others=>'0'),
      dataCnt        => (others=>'0'),
      timeCnt        => (others=>'0'),
      dnaValue       => (others=>'0'),
      lostTrigFlag   => '0',
      emptyTrigFlag  => '0',
      extTrigFlag    => '0',
      intTrigFlag    => '0',
      vetoTrigFlag   => '0',
      badAdcFlag     => '0',
      state          => IDLE_S
   );
   
   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      enable         : sl;
      dataSize       : slv(31 downto 0);
      timeout        : slv(31 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      enable         => '0',
      dataSize       => (others=>'0'),
      timeout        => (others=>'0')
   );

   signal str     : StrType   := STR_INIT_C;
   signal strIn   : StrType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
begin

   
   -- register logic (axilClk domain)
   -- streaming logic (axisClk domian)
   comb : process (axisRst, axilRst, str, reg, axilReadMaster, axilWriteMaster, axisRxMaster, axisTxSlave, dnaValue) is
      variable vreg     : RegType;
      variable vstr     : StrType;
      variable regCon   : AxiLiteEndPointType;
   begin
      -- Latch the current value
      vreg  := reg;
      vstr  := str;
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vstr.enable    := reg.enable;
      vstr.dataSize  := reg.dataSize(31 downto 2);
      vstr.timeout   := reg.timeout;
      vstr.dnaValue  := dnaValue;
      
      
      ------------------------------------------------
      -- register access
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      -- Map the registers
      axiSlaveRegister (regCon, x"000", 0, vreg.enable);
      axiSlaveRegister (regCon, x"004", 0, vreg.dataSize);
      axiSlaveRegister (regCon, x"008", 0, vreg.timeout);
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      ----------------------------------------------------------------------
      -- Data stream state machine
      ----------------------------------------------------------------------
      
      -- Reset strobing Signals
      if (axisTxSlave.tReady = '1') then
         vstr.txMaster.tValid := '0';
         vstr.txMaster.tLast  := '0';
         vstr.txMaster.tUser  := (others => '0');
         vstr.txMaster.tKeep  := (others => '1');
         vstr.txMaster.tStrb  := (others => '1');
      end if;
      
      vstr.rxSlave.tReady := '0';
      
      -- always count time when not idle
      vstr.timeCnt   := str.timeCnt + 1;
      
      case str.state is
      
         when IDLE_S =>
            vstr.hdrCnt          := (others => '0');
            vstr.dataCnt         := (others => '0');
            vstr.timeCnt         := (others => '0');
            vstr.gTime           := (others => '0');
            vstr.gTimeMin        := (others => '1');
            vstr.gTimeMax        := (others => '0');
            vstr.lostTrigFlag    := '0';
            vstr.badAdcFlag      := '0';
            vstr.vetoTrigFlag    := '0';
            vstr.emptyTrigFlag   := '0';
            vstr.intTrigFlag     := '0';
            vstr.extTrigFlag     := '0';
            if vstr.txMaster.tValid = '0' and  axisRxMaster.tValid = '1' then
               if ssiGetUserSof(AXIS_CONFIG_C, axisRxMaster) = '1' and str.enable = '1' then
                  -- move data
                  vstr.txMaster.tValid := '1';
                  vstr.rxSlave.tReady  := '1';
                  
                  -- pass SOF only from first rx packet
                  vstr.txMaster.tUser  := axisRxMaster.tUser;
                  
                  -- move data with no change
                  vstr.txMaster.tData  := axisRxMaster.tData;
                  
                  -- count all data
                  vstr.dataCnt         := str.dataCnt + 1;
                  
                  -- count header data (reset every rx.tLast)
                  vstr.hdrCnt          := str.hdrCnt + 1;
                  vstr.state           := PACKET_S;
               else
                  -- pass data to output
                  vstr.rxSlave.tReady  := '1';
                  vstr.txMaster        := axisRxMaster;
               end if;
            end if;
         
         when PACKET_S =>
            if vstr.txMaster.tValid = '0' and  axisRxMaster.tValid = '1' then
               vstr.txMaster.tValid := '1';
               vstr.rxSlave.tReady  := '1';
               
               -- move data
               vstr.txMaster.tData  := axisRxMaster.tData;
               
               -- change footer bit in the 2nd word
               -- to let the software that the footer will follow
               if str.hdrCnt = 1 then
                  vstr.txMaster.tData(16) := '1';
               end if;
               
               -- count all data
               if str.dataCnt < 2**str.dataCnt'length-1 then
                  vstr.dataCnt      := str.dataCnt + 1;
               end if;
               
               -- count header data (reset every rx.tLast)
               if str.hdrCnt < 2**str.hdrCnt'length-1 then
                  vstr.hdrCnt       := str.hdrCnt + 1;
               end if;
               
               -- store required header data
               if str.hdrCnt = 2 then
                  vstr.badAdcFlag            := axisRxMaster.tData(31) or str.badAdcFlag;
                  vstr.vetoTrigFlag          := axisRxMaster.tData(30) or str.vetoTrigFlag;
                  vstr.emptyTrigFlag         := axisRxMaster.tData(29) or str.emptyTrigFlag;
                  vstr.intTrigFlag           := axisRxMaster.tData(28) or str.intTrigFlag;
                  vstr.extTrigFlag           := axisRxMaster.tData(27) or str.extTrigFlag;
                  vstr.lostTrigFlag          := axisRxMaster.tData(22) or str.lostTrigFlag;
               elsif str.hdrCnt = 4 then
                  vstr.gTime(31 downto 0)    := axisRxMaster.tData(31 downto 0);
               elsif str.hdrCnt = 5 then
                  vstr.gTime(63 downto  32)  := axisRxMaster.tData(31 downto 0);
                  if vstr.gTime > str.gTimeMax then
                     vstr.gTimeMax := vstr.gTime;
                  end if;
                  if vstr.gTime < str.gTimeMin then
                     vstr.gTimeMin := vstr.gTime;
                  end if;
               end if;
               
               if axisRxMaster.tLast = '1' then
                  
                  if str.dataCnt >= str.dataSize then
                     vstr.hdrCnt := (others => '0');
                     vstr.state := FOOTER_S;
                  else
                     vstr.state := WAIT_PKT_S;
                  end if;
               
               end if;
               
            end if;
         
         when WAIT_PKT_S =>
            vstr.hdrCnt := (others => '0');
            if vstr.txMaster.tValid = '0' and str.timeCnt >= str.timeout then
               vstr.state := FOOTER_S;
            elsif vstr.txMaster.tValid = '0' and axisRxMaster.tValid = '1' then
               vstr.state := PACKET_S;
            end if;
         
         
         when FOOTER_S =>
            if vstr.txMaster.tValid = '0' then
               vstr.txMaster.tValid := '1';
               -- reuse header counter for footer
               vstr.hdrCnt := str.hdrCnt + 1;
               
               if str.hdrCnt = 0 then
                  vstr.txMaster.tData(31 downto 0)  := str.gTimeMax(31 downto 0);
               elsif str.hdrCnt = 1 then
                  vstr.txMaster.tData(31 downto 0)  := str.gTimeMax(63 downto 32);
               elsif str.hdrCnt = 2 then
                  vstr.txMaster.tData(31 downto 0)  := str.gTimeMin(31 downto 0);
               elsif str.hdrCnt = 3 then
                  vstr.txMaster.tData(31 downto 0)  := str.gTimeMin(63 downto 32);
               elsif str.hdrCnt = 4 then
                  vstr.txMaster.tData(31 downto 0)  := str.dnaValue(31 downto 0);
               elsif str.hdrCnt = 5 then
                  vstr.txMaster.tData(31 downto 0)  := str.dnaValue(63 downto 32);
               elsif str.hdrCnt = 6 then
                  vstr.txMaster.tData(31 downto 0)  := str.dnaValue(95 downto 64);
               elsif str.hdrCnt = 7 then
                  vstr.txMaster.tData(31 downto 0)  := str.dnaValue(127 downto 96);
               elsif str.hdrCnt = 8 then
                  vstr.txMaster.tData(31 downto 6)  := (others=>'0');   -- reserved
                  vstr.txMaster.tData(5)            := str.badAdcFlag;
                  vstr.txMaster.tData(4)            := str.vetoTrigFlag;
                  vstr.txMaster.tData(3)            := str.emptyTrigFlag;
                  vstr.txMaster.tData(2)            := str.intTrigFlag;
                  vstr.txMaster.tData(1)            := str.extTrigFlag;
                  vstr.txMaster.tData(0)            := str.lostTrigFlag;
               elsif str.hdrCnt = 9 then
                  vstr.txMaster.tData(31 downto 0)  := (others=>'0');   -- reserved
               elsif str.hdrCnt = 10 then
                  vstr.txMaster.tData(31 downto 0)  := (others=>'0');   -- reserved
               else
                  vstr.txMaster.tData(31 downto 0)  := (others=>'0');   -- reserved
                  vstr.txMaster.tLast  := '1';
                  vstr.hdrCnt := (others => '0');
                  vstr.dataCnt := (others => '0');
                  vstr.state := IDLE_S;
               end if;
               
            end if;
         
         when others =>
            vstr.state := IDLE_S;
         
      end case;
      
      -- Reset      
      if (axisRst = '1') then
         vstr := STR_INIT_C;
      end if;
      if (axilRst = '1') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn <= vreg;
      strIn <= vstr;

      -- Outputs
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      axisRxSlave    <= vstr.rxSlave;
      axisTxMaster   <= str.txMaster;
   end process comb;

   seqR : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seqR;
   
   seqS : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         str <= strIn after TPD_G;
      end if;
   end process seqS;
   

end rtl;
