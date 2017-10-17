-------------------------------------------------------------------------------
-- File       : FastAdcPhy.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-13
-------------------------------------------------------------------------------
-- Description: LZ FastAdcPhy Top Level
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.jesd204bpkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity FastAdcPhy is
   generic (
      TPD_G            : time             := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C;
      AXI_BASE_ADDR_G  : slv(31 downto 0) := (others => '0'));
   port (
      -- JESD ADC Ports
      jesdClkP        : in    sl;
      jesdClkN        : in    sl;
      jesdSysRefP     : in    sl;
      jesdSysRefN     : in    sl;
      jesdRxP         : in    slv(15 downto 0);
      jesdRxN         : in    slv(15 downto 0);
      jesdTxP         : out   slv(15 downto 0);
      jesdTxN         : out   slv(15 downto 0);
      jesdSync        : out   slv(3 downto 0);
      -- Fast ADC SPI Ports
      fadcSclk        : out   sl;
      fadcSdin        : out   sl;
      fadcSdout       : in    sl;
      fadcSen         : out   slv(3 downto 0);
      fadcReset       : out   slv(3 downto 0);
      fadcPdn         : out   slv(3 downto 0);
      -- LMK Ports
      lmkRefClk       : in    sl;
      lmkRefClkP      : out   sl;
      lmkRefClkN      : out   sl;
      lmkCsL          : out   sl;
      lmkSck          : out   sl;
      lmkSdio         : inout sl;
      lmkRst          : out   sl;
      lmkSync         : out   sl;
      -- JESD ADC Interface
      adcClk          : in    sl;
      adcRst          : in    sl;
      adcValid        : out   slv(7 downto 0);
      adcData         : out   Slv64Array(7 downto 0);
      swTrigger       : in    sl;
      swArmTrig       : in    sl;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end FastAdcPhy;

architecture rtl of FastAdcPhy is

   constant NUM_AXI_MASTERS_C : natural := 8;

   constant JESD_INDEX_C : natural := 0;
   constant LMK_INDEX_C  : natural := 1;
   constant SPI0_INDEX_C : natural := 2;
   constant SPI1_INDEX_C : natural := 3;
   constant SPI2_INDEX_C : natural := 4;
   constant SPI3_INDEX_C : natural := 5;

   constant GTH_INDEX_C     : natural          := 6;
   constant GTH_BASE_ADDR_C : slv(31 downto 0) := (AXI_BASE_ADDR_G+x"0060_0000");

   constant DBG_INDEX_C     : natural          := 7;
   constant DBG_BASE_ADDR_C : slv(31 downto 0) := (AXI_BASE_ADDR_G+x"0070_0000");

   constant AXI_CONFIG_C   : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   constant GTH_CONFIG_C  : AxiLiteCrossbarMasterConfigArray(JESD_LANE_C-1 downto 0) := genAxiLiteConfig(JESD_LANE_C, GTH_BASE_ADDR_C, 20, 16);
   signal gthWriteMasters : AxiLiteWriteMasterArray(JESD_LANE_C-1 downto 0);
   signal gthWriteSlaves  : AxiLiteWriteSlaveArray(JESD_LANE_C-1 downto 0);
   signal gthReadMasters  : AxiLiteReadMasterArray(JESD_LANE_C-1 downto 0);
   signal gthReadSlaves   : AxiLiteReadSlaveArray(JESD_LANE_C-1 downto 0);

   constant DBG_CONFIG_C  : AxiLiteCrossbarMasterConfigArray(JESD_LANE_C-1 downto 0) := genAxiLiteConfig(JESD_LANE_C, DBG_BASE_ADDR_C, 20, 16);
   signal dbgWriteMasters : AxiLiteWriteMasterArray(JESD_LANE_C-1 downto 0);
   signal dbgWriteSlaves  : AxiLiteWriteSlaveArray(JESD_LANE_C-1 downto 0);
   signal dbgReadMasters  : AxiLiteReadMasterArray(JESD_LANE_C-1 downto 0);
   signal dbgReadSlaves   : AxiLiteReadSlaveArray(JESD_LANE_C-1 downto 0);

   signal drpClk  : slv(JESD_LANE_C-1 downto 0)    := (others => '0');
   signal drpRdy  : slv(JESD_LANE_C-1 downto 0)    := (others => '0');
   signal drpEn   : slv(JESD_LANE_C-1 downto 0)    := (others => '0');
   signal drpWe   : slv(JESD_LANE_C-1 downto 0)    := (others => '0');
   signal drpAddr : slv(JESD_LANE_C*9-1 downto 0)  := (others => '0');
   signal drpDi   : slv(JESD_LANE_C*16-1 downto 0) := (others => '0');
   signal drpDo   : slv(JESD_LANE_C*16-1 downto 0) := (others => '0');

   signal rawAdcValids : slv(JESD_LANE_C-1 downto 0)             := (others => '0');
   signal rawAdcValues : sampleDataArray(JESD_LANE_C-1 downto 0) := (others => (others => '0'));

   signal refClk     : sl;
   signal jesdSysRef : sl;
   signal jesdRxSync : sl;
   signal rxSyncReg  : slv(3 downto 0);
   signal adcRstL    : sl;

   signal lmkDataIn  : sl;
   signal lmkDataOut : sl;

   signal spiCsL     : slv(3 downto 0);
   signal spiSck     : slv(3 downto 0);
   signal spiMosi    : slv(3 downto 0);
   signal spiBusy    : sl;
   signal spiBusyVec : slv(3 downto 0);

   signal bufferEnable : sl := '0';

begin

   adcRstL <= not(adcRst);

   ----------------------------------         
   -- Combine the JESD lanes together
   ----------------------------------         
   process(adcClk)
      variable i : natural;
   begin
      if rising_edge(adcClk) then
         for i in 7 downto 0 loop
            adcValid(i) <= rawAdcValids(2*i+1) and rawAdcValids(2*i+0) after TPD_G;
            adcData(i)  <= rawAdcValues(2*i+1) & rawAdcValues(2*i+0)   after TPD_G;
         end loop;
         if (swArmTrig = '1') then
            bufferEnable <= '1' after TPD_G;
         elsif (swTrigger = '1') then
            bufferEnable <= '0' after TPD_G;
         end if;
      end if;
   end process;

   -----------
   -- Clocking
   -----------
   U_lmkRefClk : entity work.ClkOutBufDiff
      generic map (
         TPD_G        => TPD_G,
         XIL_DEVICE_G => "ULTRASCALE")
      port map (
         clkIn   => lmkRefClk,
         clkOutP => lmkRefClkP,
         clkOutN => lmkRefClkN);

   U_IBUFDS_GTE3 : IBUFDS_GTE3
      generic map (
         REFCLK_EN_TX_PATH  => '0',
         REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
         REFCLK_ICNTL_RX    => "00")
      port map (
         I     => jesdClkP,
         IB    => jesdClkN,
         CEB   => '0',
         ODIV2 => open,
         O     => refClk);

   IBUFDS_SysRef : IBUFDS
      port map (
         I  => jesdSysRefP,
         IB => jesdSysRefN,
         O  => jesdSysRef);

   GEN_SYNC : for i in 3 downto 0 generate
      U_ODDR : ODDRE1
         port map (
            C  => adcClk,
            Q  => rxSyncReg(i),
            D1 => jesdRxSync,
            D2 => jesdRxSync,
            SR => '0');
      U_OBUF : OBUF
         port map (
            I => rxSyncReg(i),
            O => jesdSync(i));
   end generate GEN_SYNC;

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   -------------
   -- JESD block
   -------------
   U_Jesd : entity work.FastAdcJesd204b
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- DRP Interface
         drpClk          => drpClk,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo,
         -- AXI interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(JESD_INDEX_C),
         axilReadSlave   => axilReadSlaves(JESD_INDEX_C),
         axilWriteMaster => axilWriteMasters(JESD_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(JESD_INDEX_C),
         -- Sample data output (Use if external data acquisition core is attached)
         dataValidVec_o  => rawAdcValids,
         sampleDataArr_o => rawAdcValues,
         -------
         -- JESD
         -------
         -- Clocks
         stableClk       => axilClk,
         refClk          => refClk,
         devClk_i        => adcClk,
         devClk2_i       => adcClk,
         devRst_i        => adcRst,
         devClkActive_i  => adcRstL,
         -- GTH Ports
         gtTxP           => jesdTxP,
         gtTxN           => jesdTxN,
         gtRxP           => jesdRxP,
         gtRxN           => jesdRxN,
         -- SYSREF for subclass 1 fixed latency
         sysRef_i        => jesdSysRef,
         -- Synchronization output combined from all receivers to be connected to ADC chips
         nSync_o         => jesdRxSync);

   -----------------
   -- LMK SPI Module
   -----------------   
   SPI_LMK : entity work.AxiSpiMaster
      generic map (
         TPD_G             => TPD_G,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
         ADDRESS_SIZE_G    => 15,
         DATA_SIZE_G       => 8,
         CLK_PERIOD_G      => (1.0/156.25E+6),
         SPI_SCLK_PERIOD_G => 10.0E-6)
      port map (
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMasters(LMK_INDEX_C),
         axiReadSlave   => axilReadSlaves(LMK_INDEX_C),
         axiWriteMaster => axilWriteMasters(LMK_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(LMK_INDEX_C),
         coreSclk       => lmkSck,
         coreSDin       => lmkDataIn,
         coreSDout      => lmkDataOut,
         coreCsb        => lmkCsL);

   IOBUF_Lmk : IOBUF
      port map (
         I  => '0',
         O  => lmkDataIn,
         IO => lmkSdio,
         T  => lmkDataOut);

   lmkSync <= '0';
   lmkRst  <= axilRst;

   ----------------------
   -- Fast ADC SPI Module
   ----------------------   
   GEN_ADC_SPI : for i in 3 downto 0 generate
      U_SPI : entity work.ads54j60
         generic map (
            TPD_G             => TPD_G,
            AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
            CLK_PERIOD_G      => (1.0/156.25E+6),
            SPI_SCLK_PERIOD_G => 10.0E-6)
         port map (
            -- Clock and Reset
            axiClk         => axilClk,
            axiRst         => axilRst,
            -- AXI-Lite Interface
            axiReadMaster  => axilReadMasters(SPI0_INDEX_C+i),
            axiReadSlave   => axilReadSlaves(SPI0_INDEX_C+i),
            axiWriteMaster => axilWriteMasters(SPI0_INDEX_C+i),
            axiWriteSlave  => axilWriteSlaves(SPI0_INDEX_C+i),
            -- SPI Interface
            coreBusyIn     => spiBusy,
            coreBusyOut    => spiBusyVec(i),
            coreRst        => fadcReset(i),
            coreSclk       => spiSck(i),
            coreSDin       => fadcSdout,
            coreSDout      => spiMosi(i),
            coreCsb        => spiCsL(i));
   end generate GEN_ADC_SPI;

   spiBusy <= uOr(spiBusyVec);
   fadcPdn <= (others => '0');
   fadcSen <= spiCsL;

   process(spiCsL, spiMosi, spiSck)
   begin
      if spiCsL(0) = '0' then
         fadcSclk <= spiSck(0);
         fadcSdin <= spiMosi(0);
      elsif spiCsL(1) = '0' then
         fadcSclk <= spiSck(1);
         fadcSdin <= spiMosi(1);
      elsif spiCsL(2) = '0' then
         fadcSclk <= spiSck(2);
         fadcSdin <= spiMosi(2);
      elsif spiCsL(3) = '0' then
         fadcSclk <= spiSck(3);
         fadcSdin <= spiMosi(3);
      else
         fadcSclk <= '0';
         fadcSdin <= '0';
      end if;
   end process;

   -----------------------
   -- GTH's DRP Interfaces
   -----------------------
   U_GT_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => JESD_LANE_C,
         MASTERS_CONFIG_G   => GTH_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMasters(GTH_INDEX_C),
         sAxiWriteSlaves(0)  => axilWriteSlaves(GTH_INDEX_C),
         sAxiReadMasters(0)  => axilReadMasters(GTH_INDEX_C),
         sAxiReadSlaves(0)   => axilReadSlaves(GTH_INDEX_C),
         mAxiWriteMasters    => gthWriteMasters,
         mAxiWriteSlaves     => gthWriteSlaves,
         mAxiReadMasters     => gthReadMasters,
         mAxiReadSlaves      => gthReadSlaves);

   drpClk <= (others => axilClk);

   GEN_GTH_DRP : for i in (JESD_LANE_C-1) downto 0 generate
      U_AxiLiteToDrp : entity work.AxiLiteToDrp
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
            COMMON_CLK_G     => true,
            EN_ARBITRATION_G => false,
            TIMEOUT_G        => 4096,
            ADDR_WIDTH_G     => 9,
            DATA_WIDTH_G     => 16)
         port map (
            -- AXI-Lite Port
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => gthReadMasters(i),
            axilReadSlave   => gthReadSlaves(i),
            axilWriteMaster => gthWriteMasters(i),
            axilWriteSlave  => gthWriteSlaves(i),
            -- DRP Interface
            drpClk          => axilClk,
            drpRst          => axilRst,
            drpRdy          => drpRdy(i),
            drpEn           => drpEn(i),
            drpWe           => drpWe(i),
            drpAddr         => drpAddr((i*9)+8 downto (i*9)),
            drpDi           => drpDi((i*16)+15 downto (i*16)),
            drpDo           => drpDo((i*16)+15 downto (i*16)));

   end generate GEN_GTH_DRP;


   --------------------
   -- Debug ADC Modules
   --------------------
   U_DBG_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => JESD_LANE_C,
         MASTERS_CONFIG_G   => DBG_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMasters(DBG_INDEX_C),
         sAxiWriteSlaves(0)  => axilWriteSlaves(DBG_INDEX_C),
         sAxiReadMasters(0)  => axilReadMasters(DBG_INDEX_C),
         sAxiReadSlaves(0)   => axilReadSlaves(DBG_INDEX_C),
         mAxiWriteMasters    => dbgWriteMasters,
         mAxiWriteSlaves     => dbgWriteSlaves,
         mAxiReadMasters     => dbgReadMasters,
         mAxiReadSlaves      => dbgReadSlaves);

   GEN_ADC_DEBUG :
   for i in (JESD_LANE_C-1) downto 0 generate
      RING_BUFFER : entity work.AxiLiteRingBuffer
         generic map (
            TPD_G            => TPD_G,
            BRAM_EN_G        => true,
            REG_EN_G         => true,
            DATA_WIDTH_G     => 32,
            RAM_ADDR_WIDTH_G => 10,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
         port map (
            -- Data to store in ring buffer
            dataClk         => adcClk,
            dataRst         => adcRst,
            dataValid       => rawAdcValids(i),
            dataValue       => rawAdcValues(i),
            bufferEnable    => bufferEnable,
            bufferClear     => swArmTrig,
            -- AXI-Lite interface for readout
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => dbgReadMasters(i),
            axilReadSlave   => dbgReadSlaves(i),
            axilWriteMaster => dbgWriteMasters(i),
            axilWriteSlave  => dbgWriteSlaves(i));
   end generate GEN_ADC_DEBUG;

end rtl;
