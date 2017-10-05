-------------------------------------------------------------------------------
-- File       : SystemCore.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-10-05
-------------------------------------------------------------------------------
-- Description: LZ Digitizer Target's Top Level
-------------------------------------------------------------------------------
-- This file is part of 'firmware-template'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'firmware-template', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.AppPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SystemCore is
   generic (
      TPD_G             : time            := 1 ns;
      BUILD_INFO_G      : BuildInfoType;
      NUM_AXI_MASTERS_G : positive;
      AXI_CONFIG_G      : AxiLiteCrossbarMasterConfigArray;
      AXI_ERROR_RESP_G  : slv(1 downto 0) := AXI_RESP_SLVERR_C);
   port (
      -- Clock and Reset
      axilClk           : in  sl;
      axilRst           : in  sl;
      clk250            : in  sl;
      rst250            : in  sl;
      ddrRstN           : in  sl;
      clk250ddr         : out  sl;
      writerRstL        : out  sl;
      -- ADC AXI Interface (clk250 domain)
      axiAdcWriteMasters  : in AxiWriteMasterArray(7 downto 0);
      axiAdcWriteSlaves   : out  AxiWriteSlaveArray(7 downto 0);      
      axiDoutReadMaster   : in AxiReadMasterType;
      axiDoutReadSlave    : out AxiReadSlaveType;     
      -- MB Streaming Interface (axilClk domain)
      mbTxMaster   : out AxiStreamMasterType;
      mbTxSlave    : in  AxiStreamSlaveType;      
      -- AXI-Lite Register Interface (axilClk domain)
      mAxilReadMaster   : in  AxiLiteReadMasterType;
      mAxilReadSlave    : out AxiLiteReadSlaveType;
      mAxilWriteMaster  : in  AxiLiteWriteMasterType;
      mAxilWriteSlave   : out AxiLiteWriteSlaveType;
      sAxilReadMasters  : in  AxiLiteReadMasterArray(NUM_AXI_MASTERS_G-1 downto 1);
      sAxilReadSlaves   : out AxiLiteReadSlaveArray(NUM_AXI_MASTERS_G-1 downto 1);
      sAxilWriteMasters : in  AxiLiteWriteMasterArray(NUM_AXI_MASTERS_G-1 downto 1);
      sAxilWriteSlaves  : out AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_G-1 downto 1);
      -- SYSMON Ports
      vPIn              : in  sl;
      vNIn              : in  sl);
end SystemCore;

architecture top_level of SystemCore is

   constant NUM_AXI_MASTERS_C : natural := 4;

   constant VERSION_INDEX_C  : natural := 0;
   constant SYSMON_INDEX_C   : natural := 1;
   constant BOOT_MEM_INDEX_C : natural := 2;
   constant DDR_MEM_INDEX_C  : natural := 3;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS1_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS1_C, AXI_BASE_ADDR_G, 24, 16);

   signal regWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_G-1 downto 0);
   signal regWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_G-1 downto 0);
   signal regReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_G-1 downto 0);
   signal regReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_G-1 downto 0);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
   signal axiClk         : sl;
   signal axiRst         : sl;
   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;
   signal axiWriteMaster : AxiWriteMasterType;
   signal axiWriteSlave  : AxiWriteSlaveType;   
   
   signal axiBistReadMaster    : AxiReadMasterType;
   signal axiBistReadSlave     : AxiReadSlaveType;
   signal axiBistWriteMaster   : AxiWriteMasterType;
   signal axiBistWriteSlave    : AxiWriteSlaveType;   
   
   signal bootCsL  : sl;
   signal bootSck  : sl;
   signal bootMosi : sl;
   signal bootMiso : sl;
   signal di       : slv(3 downto 0);
   signal do       : slv(3 downto 0);   
   
   signal calibComplete  : sl;   
   signal memReady   : sl;
   signal memFailed  : sl;   
   signal writerRst  : sl;   
   
   signal mbIrq      : slv(7 downto 0) := (others => '0');   -- unused 

begin

   --------------------------------
   -- Microblaze Embedded Processor
   --------------------------------
   U_CPU : entity work.MicroblazeBasicCoreWrapper
      generic map (
         TPD_G           => TPD_G,
         AXIL_ADDR_MSB_C => false)      -- false = [0x00000000:0xFFFFFFFF]
      port map (
         -- Master AXI-Lite Interface: [0x00000000:0xFFFFFFFF]
         mAxilWriteMaster => mbWriteMaster,
         mAxilWriteSlave  => mbWriteSlave,
         mAxilReadMaster  => mbReadMaster,
         mAxilReadSlave   => mbReadSlave,
         -- Streaming
         mAxisMaster      => mbTxMaster,
         mAxisSlave       => mbTxSlave,
         -- IRQ
         interrupt        => mbIrq,
         -- Clock and Reset
         clk              => axilClk,
         rst              => axilRst);

   ---------------------
   -- AXI-Lite: Crossbar
   ---------------------
   U_XBAR0 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_G,
         MASTERS_CONFIG_G   => AXI_CONFIG_G)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => mAxilWriteMaster,
         sAxiWriteMasters(1) => mbWriteMaster,
         sAxiWriteSlaves(0)  => mAxilWriteSlave,
         sAxiWriteSlaves(1)  => mbWriteSlave,
         sAxiReadMasters(0)  => mAxilReadMaster,
         sAxiReadMasters(1)  => mbReadMaster,
         sAxiReadSlaves(0)   => mAxilReadSlave,
         sAxiReadSlaves(1)   => mbReadSlave,
         mAxiWriteMasters    => regWriteMasters,
         mAxiWriteSlaves     => regWriteSlaves,
         mAxiReadMasters     => regReadMasters,
         mAxiReadSlaves      => regReadSlaves);

   sAxilWriteMasters(NUM_AXI_MASTERS_G-1 downto 1) <= regWriteMasters(NUM_AXI_MASTERS_G-1 downto 1);
   regWriteSlaves(NUM_AXI_MASTERS_G-1 downto 1)    <= sAxilWriteSlaves(NUM_AXI_MASTERS_G-1 downto 1);

   sAxilReadMasters                            <= regReadMasters(NUM_AXI_MASTERS_G-1 downto 1);
   regReadSlaves(NUM_AXI_MASTERS_G-1 downto 1) <= sAxilReadSlaves(NUM_AXI_MASTERS_G-1 downto 1);

   U_XBAR1 : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => regWriteMasters(0),
         sAxiWriteSlaves(0)  => regWriteSlaves(0),
         sAxiReadMasters(0)  => regReadMasters(0),
         sAxiReadSlaves(0)   => regReadSlaves(0),

         mAxiWriteMasters => axilWriteMasters,
         mAxiWriteSlaves  => axilWriteSlaves,
         mAxiReadMasters  => axilReadMasters,
         mAxiReadSlaves   => axilReadSlaves);

   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   U_AxiVersion : entity work.AxiVersion
      generic map (
         TPD_G           => TPD_G,
         BUILD_INFO_G    => BUILD_INFO_G,
         XIL_DEVICE_G    => "ULTRASCALE",
         EN_DEVICE_DNA_G => true)
      port map (
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
         axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C),
         -- Clocks and Resets
         axiClk         => axilClk,
         axiRst         => axilRst);

   --------------------------
   -- AXI-Lite: SYSMON Module
   --------------------------
   U_SysMon : entity work.LzDigitizerSysMon
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
      port map (
         -- SYSMON Ports
         vPIn            => vPIn,
         vNIn            => vNIn,
         -- AXI-Lite Register Interface
         axilReadMaster  => axilReadMasters(SYSMON_INDEX_C),
         axilReadSlave   => axilReadSlaves(SYSMON_INDEX_C),
         axilWriteMaster => axilWriteMasters(SYSMON_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(SYSMON_INDEX_C),
         -- Clocks and Resets
         axilClk         => axilClk,
         axilRst         => axilRst);

   ------------------------------
   -- AXI-Lite: Boot Flash Module
   ------------------------------
   U_BootProm : entity work.AxiMicronN25QCore
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         MEM_ADDR_MASK_G  => x"00000000",  -- Using hardware write protection
         AXI_CLK_FREQ_G   => 156.25E+6,    -- units of Hz
         SPI_CLK_FREQ_G   => (156.25E+6/4.0))  -- units of Hz
      port map (
         -- FLASH Memory Ports
         csL            => bootCsL,
         sck            => bootSck,
         mosi           => bootMosi,
         miso           => bootMiso,
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMasters(BOOT_MEM_INDEX_C),
         axiReadSlave   => axilReadSlaves(BOOT_MEM_INDEX_C),
         axiWriteMaster => axilWriteMasters(BOOT_MEM_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(BOOT_MEM_INDEX_C),
         -- Clocks and Resets
         axiClk         => axilClk,
         axiRst         => axilRst);

   U_STARTUPE3 : STARTUPE3
      generic map (
         PROG_USR      => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
         SIM_CCLK_FREQ => 0.0)  -- Set the Configuration Clock Frequency(ns) for simulation
      port map (
         CFGCLK    => open,  -- 1-bit output: Configuration main clock output
         CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
         DI        => di,  -- 4-bit output: Allow receiving on the D[3:0] input pins
         EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
         PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
         DO        => do,  -- 4-bit input: Allows control of the D[3:0] pin outputs
         DTS       => "1110",  -- 4-bit input: Allows tristate of the D[3:0] pins
         FCSBO     => bootCsL,  -- 1-bit input: Contols the FCS_B pin for flash access
         FCSBTS    => '0',              -- 1-bit input: Tristate the FCS_B pin
         GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
         GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
         KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
         PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
         USRCCLKO  => bootSck,          -- 1-bit input: User CCLK input
         USRCCLKTS => '0',  -- 1-bit input: User CCLK 3-state enable input
         USRDONEO  => '1',  -- 1-bit input: User DONE pin output control
         USRDONETS => '0'  -- 1-bit input: User DONE 3-state enable output
         );

   do       <= "111" & bootMosi;
   bootMiso <= di(1);

   --------------------
   -- DDR memory tester
   --------------------
   U_AxiMemTester : entity work.AxiMemTester
      generic map (
         TPD_G        => TPD_G,
         START_ADDR_G => START_ADDR_C,
         STOP_ADDR_G  => STOP_ADDR_C,
         AXI_CONFIG_G => DDR_AXI_CONFIG_C)
      port map (
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(DDR_MEM_INDEX_C),
         axilReadSlave   => axilReadSlaves(DDR_MEM_INDEX_C),
         axilWriteMaster => axilWriteMasters(DDR_MEM_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(DDR_MEM_INDEX_C),
         memReady        => memReady,
         memError        => memFailed,
         -- DDR Memory Interface
         axiClk          => axiClk,
         axiRst          => axiRst,
         start           => calibComplete,
         axiWriteMaster  => axiBistWriteMaster,
         axiWriteSlave   => axiBistWriteSlave,
         axiReadMaster   => axiBistReadMaster,
         axiReadSlave    => axiBistReadSlave);

   ------------------------------------------------
   -- DDR memory controller
   ------------------------------------------------
   U_DDR : entity work.MigCoreWrapper
      generic map (
         TPD_G => TPD_G)
      port map (
         -- AXI Slave
         axiClk           => axiClk,
         axiRst           => axiRst,
         axiReadMaster    => axiReadMaster,
         axiReadSlave     => axiReadSlave,
         axiWriteMaster   => axiWriteMaster,
         axiWriteSlave    => axiWriteSlave,
         -- DDR PHY Ref clk
         c0_sys_clk_p     => c0_sys_clk_p,
         c0_sys_clk_n     => c0_sys_clk_n,
         -- DRR Memory interface ports
         c0_ddr4_adr      => c0_ddr4_adr,
         c0_ddr4_ba       => c0_ddr4_ba,
         c0_ddr4_cke      => c0_ddr4_cke,
         c0_ddr4_cs_n     => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n,
         c0_ddr4_dq       => c0_ddr4_dq,
         c0_ddr4_dqs_c    => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t    => c0_ddr4_dqs_t,
         c0_ddr4_odt      => c0_ddr4_odt,
         c0_ddr4_bg       => c0_ddr4_bg,
         c0_ddr4_reset_n  => c0_ddr4_reset_n,
         c0_ddr4_act_n    => c0_ddr4_act_n,
         c0_ddr4_ck_c     => c0_ddr4_ck_c,
         c0_ddr4_ck_t     => c0_ddr4_ck_t,
         calibComplete    => calibComplete,
         c0_ddr4_aresetn  => ddrRstN,
         clk250out        => clk250ddr);

   ------------------------------------------------
   -- DDR memory AXI interconnect
   ------------------------------------------------
   U_AxiIcWrapper : entity work.AxiIcWrapper
      port map (
         -- AXI Slaves for ADC channels
         -- 128 Bit Data Bus
         -- 1 burst packet FIFOs
         axiAdcClk          => clk250,
         axiAdcWriteMasters => axiAdcWriteMasters,
         axiAdcWriteSlaves  => axiAdcWriteSlaves,
         -- AXI Slave for data readout
         -- 32 Bit Data Bus
         axiDoutClk         => clk250,
         axiDoutReadMaster  => axiDoutReadMaster,
         axiDoutReadSlave   => axiDoutReadSlave,
         -- AXI Slave for memory tester (aximClk domain)
         -- 512 Bit Data Bus
         axiBistReadMaster  => axiBistReadMaster,
         axiBistReadSlave   => axiBistReadSlave,
         axiBistWriteMaster => axiBistWriteMaster,
         axiBistWriteSlave  => axiBistWriteSlave,
         -- AXI Master
         -- 512 Bit Data Bus
         aximClk            => axiClk,
         aximRst            => axiRst,
         aximReadMaster     => axiReadMaster,
         aximReadSlave      => axiReadSlave,
         aximWriteMaster    => axiWriteMaster,
         aximWriteSlave     => axiWriteSlave);

   -- keep memory writers in reset during memory test
   memRst : process (clk250) is
   begin
      if rising_edge(clk250) then
         if rst250 = '1' then
            writerRst <= '1' after TPD_G;
         elsif memReady = '1' and memFailed = '0' then
            writerRst <= '0' after TPD_G;
         end if;
      end if;
   end process memRst;

   writerRstL <= not(writerRst);

end top_level;
