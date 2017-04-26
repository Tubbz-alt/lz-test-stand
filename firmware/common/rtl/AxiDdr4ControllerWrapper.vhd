-------------------------------------------------------------------------------
-- Title         : Wrapper of the DDR Controller IP core
-- Project       : 
-------------------------------------------------------------------------------
-- File          : AxiDdr4ControllerWrapper.vhd
-- Author        : Maciej Kwiatkowski, mkwiatko@slac.stanford.edu
-- Created       : 04/24/2017
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

use work.all;
use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiDdr4ControllerWrapper is 
   port (

      -- AXI Slave
      axiClk            : out   sl;
      axiRst            : out   sl;
      axiReadMaster     : in    AxiReadMasterType;
      axiReadSlave      : out   AxiReadSlaveType;
      axiWriteMaster    : in    AxiWriteMasterType;
      axiWriteSlave     : out   AxiWriteSlaveType;
      
      -- DDR PHY Ref clk
      c0_sys_clk_p      : in    sl;
      c0_sys_clk_n      : in    sl;

      -- DRR Memory interface ports
      c0_ddr4_dq        : inout slv(63 downto 0);
      c0_ddr4_dqs_c     : inout slv(7 downto 0);
      c0_ddr4_dqs_t     : inout slv(7 downto 0);
      c0_ddr4_adr       : out   slv(16 downto 0);
      c0_ddr4_ba        : out   slv(1 downto 0);
      c0_ddr4_bg        : out   slv(0 to 0);
      c0_ddr4_reset_n   : out   sl;
      c0_ddr4_act_n     : out   sl;
      c0_ddr4_ck_t      : out   slv(0 to 0);
      c0_ddr4_ck_c      : out   slv(0 to 0);
      c0_ddr4_cke       : out   slv(0 to 0);
      c0_ddr4_cs_n      : out   slv(0 to 0);
      c0_ddr4_dm_dbi_n  : inout slv(7 downto 0);
      c0_ddr4_odt       : out   slv(0 to 0);
      calibComplete     : out   sl
      
   );
end AxiDdr4ControllerWrapper;


-- Define architecture
architecture RTL of AxiDdr4ControllerWrapper is


   component ddr4_1
   PORT (
      c0_init_calib_complete : OUT STD_LOGIC;
      dbg_clk : OUT STD_LOGIC;
      c0_sys_clk_p : IN STD_LOGIC;
      c0_sys_clk_n : IN STD_LOGIC;
      dbg_bus : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
      c0_ddr4_adr : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
      c0_ddr4_ba : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_cke : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_cs_n : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_dm_dbi_n : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_dq : INOUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      c0_ddr4_dqs_c : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_dqs_t : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_odt : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_bg : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_reset_n : OUT STD_LOGIC;
      c0_ddr4_act_n : OUT STD_LOGIC;
      c0_ddr4_ck_c : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_ck_t : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_ui_clk : OUT STD_LOGIC;
      c0_ddr4_ui_clk_sync_rst : OUT STD_LOGIC;
      c0_ddr4_aresetn : IN STD_LOGIC;
      c0_ddr4_s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_awaddr : IN STD_LOGIC_VECTOR(30 DOWNTO 0);
      c0_ddr4_s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_awlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_awvalid : IN STD_LOGIC;
      c0_ddr4_s_axi_awready : OUT STD_LOGIC;
      c0_ddr4_s_axi_wdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
      c0_ddr4_s_axi_wstrb : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      c0_ddr4_s_axi_wlast : IN STD_LOGIC;
      c0_ddr4_s_axi_wvalid : IN STD_LOGIC;
      c0_ddr4_s_axi_wready : OUT STD_LOGIC;
      c0_ddr4_s_axi_bready : IN STD_LOGIC;
      c0_ddr4_s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_bvalid : OUT STD_LOGIC;
      c0_ddr4_s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_araddr : IN STD_LOGIC_VECTOR(30 DOWNTO 0);
      c0_ddr4_s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      c0_ddr4_s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_arlock : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      c0_ddr4_s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
      c0_ddr4_s_axi_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_arvalid : IN STD_LOGIC;
      c0_ddr4_s_axi_arready : OUT STD_LOGIC;
      c0_ddr4_s_axi_rready : IN STD_LOGIC;
      c0_ddr4_s_axi_rlast : OUT STD_LOGIC;
      c0_ddr4_s_axi_rvalid : OUT STD_LOGIC;
      c0_ddr4_s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
      c0_ddr4_s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      c0_ddr4_s_axi_rdata : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
      sys_rst : IN STD_LOGIC
   );
   end component;
   
   signal sysClkRst : sl;

begin


   u_ddr4_1 : ddr4_1
   port map (
      -- general signals
      c0_init_calib_complete     => calibComplete,
      dbg_clk                    => open,
      c0_sys_clk_p               => c0_sys_clk_p,
      c0_sys_clk_n               => c0_sys_clk_n,
      dbg_bus                    => open,
      sys_rst                    => '0',
      c0_ddr4_ui_clk             => open,
      c0_ddr4_ui_clk_sync_rst    => open,
      c0_ddr4_aresetn            => '1',
      -- DDR4 signals
      c0_ddr4_adr                => c0_ddr4_adr      ,
      c0_ddr4_ba                 => c0_ddr4_ba       ,
      c0_ddr4_cke                => c0_ddr4_cke      ,
      c0_ddr4_cs_n               => c0_ddr4_cs_n     ,
      c0_ddr4_dm_dbi_n           => c0_ddr4_dm_dbi_n ,
      c0_ddr4_dq                 => c0_ddr4_dq       ,
      c0_ddr4_dqs_c              => c0_ddr4_dqs_c    ,
      c0_ddr4_dqs_t              => c0_ddr4_dqs_t    ,
      c0_ddr4_odt                => c0_ddr4_odt      ,
      c0_ddr4_bg                 => c0_ddr4_bg       ,
      c0_ddr4_reset_n            => c0_ddr4_reset_n  ,
      c0_ddr4_act_n              => c0_ddr4_act_n    ,
      c0_ddr4_ck_c               => c0_ddr4_ck_c     ,
      c0_ddr4_ck_t               => c0_ddr4_ck_t     ,
      -- Slave Interface Write Address Ports
      c0_ddr4_s_axi_awid         => axiWriteMaster.awid(3 downto 0),
      c0_ddr4_s_axi_awaddr       => axiWriteMaster.awaddr(30 downto 0),
      c0_ddr4_s_axi_awlen        => axiWriteMaster.awlen,
      c0_ddr4_s_axi_awsize       => axiWriteMaster.awsize,
      c0_ddr4_s_axi_awburst      => axiWriteMaster.awburst,
      c0_ddr4_s_axi_awlock       => axiWriteMaster.awlock(0 downto 0),
      c0_ddr4_s_axi_awcache      => axiWriteMaster.awcache,
      c0_ddr4_s_axi_awprot       => axiWriteMaster.awprot,
      c0_ddr4_s_axi_awqos        => axiWriteMaster.awqos,
      c0_ddr4_s_axi_awvalid      => axiWriteMaster.awvalid,
      c0_ddr4_s_axi_awready      => axiWriteSlave.awready,
      -- Slave Interface Write Data Ports
      c0_ddr4_s_axi_wdata        => axiWriteMaster.wdata(511 downto 0),
      c0_ddr4_s_axi_wstrb        => axiWriteMaster.wstrb(63 downto 0),
      c0_ddr4_s_axi_wlast        => axiWriteMaster.wlast,
      c0_ddr4_s_axi_wvalid       => axiWriteMaster.wvalid,
      c0_ddr4_s_axi_wready       => axiWriteSlave.wready,
      -- Slave Interface Write Response Ports
      c0_ddr4_s_axi_bid          => axiWriteSlave.bid(3 downto 0),
      c0_ddr4_s_axi_bresp        => axiWriteSlave.bresp,
      c0_ddr4_s_axi_bvalid       => axiWriteSlave.bvalid,
      c0_ddr4_s_axi_bready       => axiWriteMaster.bready,
      -- Slave Interface Read Address Ports
      c0_ddr4_s_axi_arid         => axiReadMaster.arid(3 downto 0),
      c0_ddr4_s_axi_araddr       => axiReadMaster.araddr(30 downto 0),
      c0_ddr4_s_axi_arlen        => axiReadMaster.arlen,
      c0_ddr4_s_axi_arsize       => axiReadMaster.arsize,
      c0_ddr4_s_axi_arburst      => axiReadMaster.arburst,
      c0_ddr4_s_axi_arlock       => axiReadMaster.arlock(0 downto 0),
      c0_ddr4_s_axi_arcache      => axiReadMaster.arcache,
      c0_ddr4_s_axi_arprot       => axiReadMaster.arprot,
      c0_ddr4_s_axi_arqos        => axiReadMaster.arqos,
      c0_ddr4_s_axi_arvalid      => axiReadMaster.arvalid,
      c0_ddr4_s_axi_arready      => axiReadSlave.arready,
      -- Slave Interface Read Data Ports
      c0_ddr4_s_axi_rid          => axiReadSlave.rid(3 downto 0),
      c0_ddr4_s_axi_rdata        => axiReadSlave.rdata(511 downto 0),
      c0_ddr4_s_axi_rresp        => axiReadSlave.rresp,
      c0_ddr4_s_axi_rlast        => axiReadSlave.rlast,
      c0_ddr4_s_axi_rvalid       => axiReadSlave.rvalid,
      c0_ddr4_s_axi_rready       => axiReadMaster.rready
   );
   
   

end RTL;

