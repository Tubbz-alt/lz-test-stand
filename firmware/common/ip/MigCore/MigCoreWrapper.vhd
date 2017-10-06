-------------------------------------------------------------------------------
-- File       : MigCoreWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-21
-- Last update: 2017-10-05
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;
use work.AppPkg.all;

entity MigCoreWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI Slave
      axiClk           : out   sl;
      axiRst           : out   sl;
      axiReadMaster    : in    AxiReadMasterType;
      axiReadSlave     : out   AxiReadSlaveType;
      axiWriteMaster   : in    AxiWriteMasterType;
      axiWriteSlave    : out   AxiWriteSlaveType;
      -- Out clock 250 MHz 
      clk250out        : out   sl;
      -- DDR PHY Ref clk
      c0_sys_clk_p     : in    sl;
      c0_sys_clk_n     : in    sl;
      -- DRR Memory interface ports
      sys_rst          : in    sl := '0';
      c0_ddr4_aresetn  : in    sl := '1';
      c0_ddr4_dq       : inout slv(DDR_WIDTH_C-1 downto 0);
      c0_ddr4_dqs_c    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_dqs_t    : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_adr      : out   slv(16 downto 0);
      c0_ddr4_ba       : out   slv(1 downto 0);
      c0_ddr4_bg       : out   slv(0 to 0);
      c0_ddr4_reset_n  : out   sl;
      c0_ddr4_act_n    : out   sl;
      c0_ddr4_ck_t     : out   slv(0 to 0);
      c0_ddr4_ck_c     : out   slv(0 to 0);
      c0_ddr4_cke      : out   slv(0 to 0);
      c0_ddr4_cs_n     : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n : inout slv((DDR_WIDTH_C/8)-1 downto 0);
      c0_ddr4_odt      : out   slv(0 to 0);
      calibComplete    : out   sl);
end MigCoreWrapper;

architecture mapping of MigCoreWrapper is

   component MigCore
      port (
         c0_init_calib_complete  : out   std_logic;
         dbg_clk                 : out   std_logic;
         c0_sys_clk_p            : in    std_logic;
         c0_sys_clk_n            : in    std_logic;
         dbg_bus                 : out   std_logic_vector(511 downto 0);
         c0_ddr4_adr             : out   std_logic_vector(16 downto 0);
         c0_ddr4_ba              : out   std_logic_vector(1 downto 0);
         c0_ddr4_cke             : out   std_logic_vector(0 downto 0);
         c0_ddr4_cs_n            : out   std_logic_vector(0 downto 0);
         c0_ddr4_dm_dbi_n        : inout std_logic_vector(3 downto 0);
         c0_ddr4_dq              : inout std_logic_vector(31 downto 0);
         c0_ddr4_dqs_c           : inout std_logic_vector(3 downto 0);
         c0_ddr4_dqs_t           : inout std_logic_vector(3 downto 0);
         c0_ddr4_odt             : out   std_logic_vector(0 downto 0);
         c0_ddr4_bg              : out   std_logic_vector(0 downto 0);
         c0_ddr4_reset_n         : out   std_logic;
         c0_ddr4_act_n           : out   std_logic;
         c0_ddr4_ck_c            : out   std_logic_vector(0 downto 0);
         c0_ddr4_ck_t            : out   std_logic_vector(0 downto 0);
         c0_ddr4_ui_clk          : out   std_logic;
         c0_ddr4_ui_clk_sync_rst : out   std_logic;
         c0_ddr4_aresetn         : in    std_logic;
         c0_ddr4_s_axi_awid      : in    std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_awaddr    : in    std_logic_vector(29 downto 0);
         c0_ddr4_s_axi_awlen     : in    std_logic_vector(7 downto 0);
         c0_ddr4_s_axi_awsize    : in    std_logic_vector(2 downto 0);
         c0_ddr4_s_axi_awburst   : in    std_logic_vector(1 downto 0);
         c0_ddr4_s_axi_awlock    : in    std_logic_vector(0 downto 0);
         c0_ddr4_s_axi_awcache   : in    std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_awprot    : in    std_logic_vector(2 downto 0);
         c0_ddr4_s_axi_awqos     : in    std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_awvalid   : in    std_logic;
         c0_ddr4_s_axi_awready   : out   std_logic;
         c0_ddr4_s_axi_wdata     : in    std_logic_vector(255 downto 0);
         c0_ddr4_s_axi_wstrb     : in    std_logic_vector(31 downto 0);
         c0_ddr4_s_axi_wlast     : in    std_logic;
         c0_ddr4_s_axi_wvalid    : in    std_logic;
         c0_ddr4_s_axi_wready    : out   std_logic;
         c0_ddr4_s_axi_bready    : in    std_logic;
         c0_ddr4_s_axi_bid       : out   std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_bresp     : out   std_logic_vector(1 downto 0);
         c0_ddr4_s_axi_bvalid    : out   std_logic;
         c0_ddr4_s_axi_arid      : in    std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_araddr    : in    std_logic_vector(29 downto 0);
         c0_ddr4_s_axi_arlen     : in    std_logic_vector(7 downto 0);
         c0_ddr4_s_axi_arsize    : in    std_logic_vector(2 downto 0);
         c0_ddr4_s_axi_arburst   : in    std_logic_vector(1 downto 0);
         c0_ddr4_s_axi_arlock    : in    std_logic_vector(0 downto 0);
         c0_ddr4_s_axi_arcache   : in    std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_arprot    : in    std_logic_vector(2 downto 0);
         c0_ddr4_s_axi_arqos     : in    std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_arvalid   : in    std_logic;
         c0_ddr4_s_axi_arready   : out   std_logic;
         c0_ddr4_s_axi_rready    : in    std_logic;
         c0_ddr4_s_axi_rlast     : out   std_logic;
         c0_ddr4_s_axi_rvalid    : out   std_logic;
         c0_ddr4_s_axi_rresp     : out   std_logic_vector(1 downto 0);
         c0_ddr4_s_axi_rid       : out   std_logic_vector(3 downto 0);
         c0_ddr4_s_axi_rdata     : out   std_logic_vector(255 downto 0);
         addn_ui_clkout1         : out   std_logic;
         sys_rst                 : in    std_logic
         );
   end component;

   signal ddrClk  : sl              := '0';
   signal ddrRst  : sl              := '1';
   signal coreRst : slv(1 downto 0) := "11";

   signal ddrWriteMaster : AxiWriteMasterType := AXI_WRITE_MASTER_INIT_C;
   signal ddrWriteSlave  : AxiWriteSlaveType  := AXI_WRITE_SLAVE_INIT_C;
   signal ddrReadMaster  : AxiReadMasterType  := AXI_READ_MASTER_INIT_C;
   signal ddrReadSlave   : AxiReadSlaveType   := AXI_READ_SLAVE_INIT_C;

begin

   axiClk <= ddrClk;
   axiRst <= ddrRst;

   ddrWriteMaster <= axiWriteMaster;
   axiWriteSlave  <= ddrWriteSlave;

   ddrReadMaster <= axiReadMaster;
   axiReadSlave  <= ddrReadSlave;

   process(ddrClk)
   begin
      if rising_edge(ddrClk) then
         ddrRst     <= coreRst(1) after TPD_G;  -- Register to help with timing
         coreRst(1) <= coreRst(0) after TPD_G;  -- Register to help with timing
      end if;
   end process;

   U_MigCore : MigCore
      port map (
         -- general signals
         c0_init_calib_complete  => calibComplete,
         dbg_clk                 => open,
         c0_sys_clk_p            => c0_sys_clk_p,
         c0_sys_clk_n            => c0_sys_clk_n,
         dbg_bus                 => open,
         sys_rst                 => sys_rst,
         c0_ddr4_ui_clk          => ddrClk,
         c0_ddr4_ui_clk_sync_rst => coreRst(0),
         c0_ddr4_aresetn         => c0_ddr4_aresetn,
         -- DDR4 signals
         c0_ddr4_adr             => c0_ddr4_adr,
         c0_ddr4_ba              => c0_ddr4_ba,
         c0_ddr4_cke             => c0_ddr4_cke,
         c0_ddr4_cs_n            => c0_ddr4_cs_n,
         c0_ddr4_dm_dbi_n        => c0_ddr4_dm_dbi_n,
         c0_ddr4_dq              => c0_ddr4_dq,
         c0_ddr4_dqs_c           => c0_ddr4_dqs_c,
         c0_ddr4_dqs_t           => c0_ddr4_dqs_t,
         c0_ddr4_odt             => c0_ddr4_odt,
         c0_ddr4_bg              => c0_ddr4_bg,
         c0_ddr4_reset_n         => c0_ddr4_reset_n,
         c0_ddr4_act_n           => c0_ddr4_act_n,
         c0_ddr4_ck_c            => c0_ddr4_ck_c,
         c0_ddr4_ck_t            => c0_ddr4_ck_t,
         -- Slave Interface Write Address Ports
         c0_ddr4_s_axi_awid      => ddrWriteMaster.awid(3 downto 0),
         c0_ddr4_s_axi_awaddr    => ddrWriteMaster.awaddr(29 downto 0),
         c0_ddr4_s_axi_awlen     => ddrWriteMaster.awlen,
         c0_ddr4_s_axi_awsize    => ddrWriteMaster.awsize,
         c0_ddr4_s_axi_awburst   => ddrWriteMaster.awburst,
         c0_ddr4_s_axi_awlock    => ddrWriteMaster.awlock(0 downto 0),
         c0_ddr4_s_axi_awcache   => ddrWriteMaster.awcache,
         c0_ddr4_s_axi_awprot    => ddrWriteMaster.awprot,
         c0_ddr4_s_axi_awqos     => ddrWriteMaster.awqos,
         c0_ddr4_s_axi_awvalid   => ddrWriteMaster.awvalid,
         c0_ddr4_s_axi_awready   => ddrWriteSlave.awready,
         -- Slave Interface Write Data Ports
         c0_ddr4_s_axi_wdata     => ddrWriteMaster.wdata(255 downto 0),
         c0_ddr4_s_axi_wstrb     => ddrWriteMaster.wstrb(31 downto 0),
         c0_ddr4_s_axi_wlast     => ddrWriteMaster.wlast,
         c0_ddr4_s_axi_wvalid    => ddrWriteMaster.wvalid,
         c0_ddr4_s_axi_wready    => ddrWriteSlave.wready,
         -- Slave Interface Write Response Ports
         c0_ddr4_s_axi_bid       => ddrWriteSlave.bid(3 downto 0),
         c0_ddr4_s_axi_bresp     => ddrWriteSlave.bresp,
         c0_ddr4_s_axi_bvalid    => ddrWriteSlave.bvalid,
         c0_ddr4_s_axi_bready    => ddrWriteMaster.bready,
         -- Slave Interface Read Address Ports
         c0_ddr4_s_axi_arid      => ddrReadMaster.arid(3 downto 0),
         c0_ddr4_s_axi_araddr    => ddrReadMaster.araddr(29 downto 0),
         c0_ddr4_s_axi_arlen     => ddrReadMaster.arlen,
         c0_ddr4_s_axi_arsize    => ddrReadMaster.arsize,
         c0_ddr4_s_axi_arburst   => ddrReadMaster.arburst,
         c0_ddr4_s_axi_arlock    => ddrReadMaster.arlock(0 downto 0),
         c0_ddr4_s_axi_arcache   => ddrReadMaster.arcache,
         c0_ddr4_s_axi_arprot    => ddrReadMaster.arprot,
         c0_ddr4_s_axi_arqos     => ddrReadMaster.arqos,
         c0_ddr4_s_axi_arvalid   => ddrReadMaster.arvalid,
         c0_ddr4_s_axi_arready   => ddrReadSlave.arready,
         -- Slave Interface Read Data Ports
         c0_ddr4_s_axi_rid       => ddrReadSlave.rid(3 downto 0),
         c0_ddr4_s_axi_rdata     => ddrReadSlave.rdata(255 downto 0),
         c0_ddr4_s_axi_rresp     => ddrReadSlave.rresp,
         c0_ddr4_s_axi_rlast     => ddrReadSlave.rlast,
         c0_ddr4_s_axi_rvalid    => ddrReadSlave.rvalid,
         c0_ddr4_s_axi_rready    => ddrReadMaster.rready,
         -- out clock
         addn_ui_clkout1         => clk250out
         );

end mapping;
