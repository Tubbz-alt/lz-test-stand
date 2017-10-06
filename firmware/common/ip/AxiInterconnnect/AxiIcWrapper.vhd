-------------------------------------------------------------------------------
-- File       : AxiIcWrapper.vhd
-- Author     : Maciej Kwiatkowski <mkwiatko@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-21
-- Last update: 2017-07-05
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

entity AxiIcWrapper is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- AXI Slaves for ADC channels
      -- 128 Bit Data Bus
      -- 1 burst packet FIFOs
      axiAdcClk            : in  sl;
      axiAdcWriteMasters   : in  AxiWriteMasterArray(7 downto 0);
      axiAdcWriteSlaves    : out AxiWriteSlaveArray(7 downto 0);
      
      -- AXI Slave for data readout
      -- 32 Bit Data Bus
      axiDoutClk           : in  sl;
      axiDoutReadMaster    : in  AxiReadMasterType;
      axiDoutReadSlave     : out AxiReadSlaveType;
      
      -- AXI Slave for memory tester (aximClk domain)
      -- 512 Bit Data Bus
      axiBistReadMaster    : in  AxiReadMasterType;
      axiBistReadSlave     : out AxiReadSlaveType;
      axiBistWriteMaster   : in  AxiWriteMasterType;
      axiBistWriteSlave    : out AxiWriteSlaveType;
      
      -- AXI Master
      -- 512 Bit Data Bus
      aximClk              : in  sl;
      aximRst              : in  sl;
      aximReadMaster       : out AxiReadMasterType;
      aximReadSlave        : in  AxiReadSlaveType;
      aximWriteMaster      : out AxiWriteMasterType;
      aximWriteSlave       : in  AxiWriteSlaveType
   );
end AxiIcWrapper;

architecture mapping of AxiIcWrapper is
   
   
   COMPONENT AxiInterconnect
      PORT (
         INTERCONNECT_ACLK : IN STD_LOGIC;
         INTERCONNECT_ARESETN : IN STD_LOGIC;
         S00_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S00_AXI_ACLK : IN STD_LOGIC;
         S00_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S00_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S00_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_AWLOCK : IN STD_LOGIC;
         S00_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_AWVALID : IN STD_LOGIC;
         S00_AXI_AWREADY : OUT STD_LOGIC;
         S00_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S00_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S00_AXI_WLAST : IN STD_LOGIC;
         S00_AXI_WVALID : IN STD_LOGIC;
         S00_AXI_WREADY : OUT STD_LOGIC;
         S00_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_BVALID : OUT STD_LOGIC;
         S00_AXI_BREADY : IN STD_LOGIC;
         S00_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S00_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S00_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_ARLOCK : IN STD_LOGIC;
         S00_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S00_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S00_AXI_ARVALID : IN STD_LOGIC;
         S00_AXI_ARREADY : OUT STD_LOGIC;
         S00_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S00_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S00_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S00_AXI_RLAST : OUT STD_LOGIC;
         S00_AXI_RVALID : OUT STD_LOGIC;
         S00_AXI_RREADY : IN STD_LOGIC;
         S01_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S01_AXI_ACLK : IN STD_LOGIC;
         S01_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S01_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S01_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_AWLOCK : IN STD_LOGIC;
         S01_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_AWVALID : IN STD_LOGIC;
         S01_AXI_AWREADY : OUT STD_LOGIC;
         S01_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S01_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S01_AXI_WLAST : IN STD_LOGIC;
         S01_AXI_WVALID : IN STD_LOGIC;
         S01_AXI_WREADY : OUT STD_LOGIC;
         S01_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_BVALID : OUT STD_LOGIC;
         S01_AXI_BREADY : IN STD_LOGIC;
         S01_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S01_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S01_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_ARLOCK : IN STD_LOGIC;
         S01_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S01_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S01_AXI_ARVALID : IN STD_LOGIC;
         S01_AXI_ARREADY : OUT STD_LOGIC;
         S01_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S01_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S01_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S01_AXI_RLAST : OUT STD_LOGIC;
         S01_AXI_RVALID : OUT STD_LOGIC;
         S01_AXI_RREADY : IN STD_LOGIC;
         S02_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S02_AXI_ACLK : IN STD_LOGIC;
         S02_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S02_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S02_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_AWLOCK : IN STD_LOGIC;
         S02_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_AWVALID : IN STD_LOGIC;
         S02_AXI_AWREADY : OUT STD_LOGIC;
         S02_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S02_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S02_AXI_WLAST : IN STD_LOGIC;
         S02_AXI_WVALID : IN STD_LOGIC;
         S02_AXI_WREADY : OUT STD_LOGIC;
         S02_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_BVALID : OUT STD_LOGIC;
         S02_AXI_BREADY : IN STD_LOGIC;
         S02_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S02_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S02_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_ARLOCK : IN STD_LOGIC;
         S02_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S02_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S02_AXI_ARVALID : IN STD_LOGIC;
         S02_AXI_ARREADY : OUT STD_LOGIC;
         S02_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S02_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S02_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S02_AXI_RLAST : OUT STD_LOGIC;
         S02_AXI_RVALID : OUT STD_LOGIC;
         S02_AXI_RREADY : IN STD_LOGIC;
         S03_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S03_AXI_ACLK : IN STD_LOGIC;
         S03_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S03_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S03_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_AWLOCK : IN STD_LOGIC;
         S03_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_AWVALID : IN STD_LOGIC;
         S03_AXI_AWREADY : OUT STD_LOGIC;
         S03_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S03_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S03_AXI_WLAST : IN STD_LOGIC;
         S03_AXI_WVALID : IN STD_LOGIC;
         S03_AXI_WREADY : OUT STD_LOGIC;
         S03_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_BVALID : OUT STD_LOGIC;
         S03_AXI_BREADY : IN STD_LOGIC;
         S03_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S03_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S03_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_ARLOCK : IN STD_LOGIC;
         S03_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S03_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S03_AXI_ARVALID : IN STD_LOGIC;
         S03_AXI_ARREADY : OUT STD_LOGIC;
         S03_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S03_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S03_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S03_AXI_RLAST : OUT STD_LOGIC;
         S03_AXI_RVALID : OUT STD_LOGIC;
         S03_AXI_RREADY : IN STD_LOGIC;
         S04_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S04_AXI_ACLK : IN STD_LOGIC;
         S04_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S04_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S04_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_AWLOCK : IN STD_LOGIC;
         S04_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_AWVALID : IN STD_LOGIC;
         S04_AXI_AWREADY : OUT STD_LOGIC;
         S04_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S04_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S04_AXI_WLAST : IN STD_LOGIC;
         S04_AXI_WVALID : IN STD_LOGIC;
         S04_AXI_WREADY : OUT STD_LOGIC;
         S04_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_BVALID : OUT STD_LOGIC;
         S04_AXI_BREADY : IN STD_LOGIC;
         S04_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S04_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S04_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_ARLOCK : IN STD_LOGIC;
         S04_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S04_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S04_AXI_ARVALID : IN STD_LOGIC;
         S04_AXI_ARREADY : OUT STD_LOGIC;
         S04_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S04_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S04_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S04_AXI_RLAST : OUT STD_LOGIC;
         S04_AXI_RVALID : OUT STD_LOGIC;
         S04_AXI_RREADY : IN STD_LOGIC;
         S05_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S05_AXI_ACLK : IN STD_LOGIC;
         S05_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S05_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S05_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_AWLOCK : IN STD_LOGIC;
         S05_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_AWVALID : IN STD_LOGIC;
         S05_AXI_AWREADY : OUT STD_LOGIC;
         S05_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S05_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S05_AXI_WLAST : IN STD_LOGIC;
         S05_AXI_WVALID : IN STD_LOGIC;
         S05_AXI_WREADY : OUT STD_LOGIC;
         S05_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_BVALID : OUT STD_LOGIC;
         S05_AXI_BREADY : IN STD_LOGIC;
         S05_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S05_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S05_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_ARLOCK : IN STD_LOGIC;
         S05_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S05_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S05_AXI_ARVALID : IN STD_LOGIC;
         S05_AXI_ARREADY : OUT STD_LOGIC;
         S05_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S05_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S05_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S05_AXI_RLAST : OUT STD_LOGIC;
         S05_AXI_RVALID : OUT STD_LOGIC;
         S05_AXI_RREADY : IN STD_LOGIC;
         S06_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S06_AXI_ACLK : IN STD_LOGIC;
         S06_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S06_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S06_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S06_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S06_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S06_AXI_AWLOCK : IN STD_LOGIC;
         S06_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S06_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S06_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S06_AXI_AWVALID : IN STD_LOGIC;
         S06_AXI_AWREADY : OUT STD_LOGIC;
         S06_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S06_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S06_AXI_WLAST : IN STD_LOGIC;
         S06_AXI_WVALID : IN STD_LOGIC;
         S06_AXI_WREADY : OUT STD_LOGIC;
         S06_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S06_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S06_AXI_BVALID : OUT STD_LOGIC;
         S06_AXI_BREADY : IN STD_LOGIC;
         S06_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S06_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S06_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S06_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S06_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S06_AXI_ARLOCK : IN STD_LOGIC;
         S06_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S06_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S06_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S06_AXI_ARVALID : IN STD_LOGIC;
         S06_AXI_ARREADY : OUT STD_LOGIC;
         S06_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S06_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S06_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S06_AXI_RLAST : OUT STD_LOGIC;
         S06_AXI_RVALID : OUT STD_LOGIC;
         S06_AXI_RREADY : IN STD_LOGIC;
         S07_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S07_AXI_ACLK : IN STD_LOGIC;
         S07_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S07_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S07_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S07_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S07_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S07_AXI_AWLOCK : IN STD_LOGIC;
         S07_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S07_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S07_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S07_AXI_AWVALID : IN STD_LOGIC;
         S07_AXI_AWREADY : OUT STD_LOGIC;
         S07_AXI_WDATA : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
         S07_AXI_WSTRB : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
         S07_AXI_WLAST : IN STD_LOGIC;
         S07_AXI_WVALID : IN STD_LOGIC;
         S07_AXI_WREADY : OUT STD_LOGIC;
         S07_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S07_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S07_AXI_BVALID : OUT STD_LOGIC;
         S07_AXI_BREADY : IN STD_LOGIC;
         S07_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S07_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S07_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S07_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S07_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S07_AXI_ARLOCK : IN STD_LOGIC;
         S07_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S07_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S07_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S07_AXI_ARVALID : IN STD_LOGIC;
         S07_AXI_ARREADY : OUT STD_LOGIC;
         S07_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S07_AXI_RDATA : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
         S07_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S07_AXI_RLAST : OUT STD_LOGIC;
         S07_AXI_RVALID : OUT STD_LOGIC;
         S07_AXI_RREADY : IN STD_LOGIC;
         S08_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S08_AXI_ACLK : IN STD_LOGIC;
         S08_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S08_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S08_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S08_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S08_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S08_AXI_AWLOCK : IN STD_LOGIC;
         S08_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S08_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S08_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S08_AXI_AWVALID : IN STD_LOGIC;
         S08_AXI_AWREADY : OUT STD_LOGIC;
         S08_AXI_WDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
         S08_AXI_WSTRB : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S08_AXI_WLAST : IN STD_LOGIC;
         S08_AXI_WVALID : IN STD_LOGIC;
         S08_AXI_WREADY : OUT STD_LOGIC;
         S08_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S08_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S08_AXI_BVALID : OUT STD_LOGIC;
         S08_AXI_BREADY : IN STD_LOGIC;
         S08_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S08_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S08_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S08_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S08_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S08_AXI_ARLOCK : IN STD_LOGIC;
         S08_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S08_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S08_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S08_AXI_ARVALID : IN STD_LOGIC;
         S08_AXI_ARREADY : OUT STD_LOGIC;
         S08_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S08_AXI_RDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
         S08_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S08_AXI_RLAST : OUT STD_LOGIC;
         S08_AXI_RVALID : OUT STD_LOGIC;
         S08_AXI_RREADY : IN STD_LOGIC;
         S09_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         S09_AXI_ACLK : IN STD_LOGIC;
         S09_AXI_AWID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S09_AXI_AWADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S09_AXI_AWLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S09_AXI_AWSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S09_AXI_AWBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S09_AXI_AWLOCK : IN STD_LOGIC;
         S09_AXI_AWCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S09_AXI_AWPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S09_AXI_AWQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S09_AXI_AWVALID : IN STD_LOGIC;
         S09_AXI_AWREADY : OUT STD_LOGIC;
         S09_AXI_WDATA : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
         S09_AXI_WSTRB : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
         S09_AXI_WLAST : IN STD_LOGIC;
         S09_AXI_WVALID : IN STD_LOGIC;
         S09_AXI_WREADY : OUT STD_LOGIC;
         S09_AXI_BID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S09_AXI_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S09_AXI_BVALID : OUT STD_LOGIC;
         S09_AXI_BREADY : IN STD_LOGIC;
         S09_AXI_ARID : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
         S09_AXI_ARADDR : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
         S09_AXI_ARLEN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
         S09_AXI_ARSIZE : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S09_AXI_ARBURST : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         S09_AXI_ARLOCK : IN STD_LOGIC;
         S09_AXI_ARCACHE : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S09_AXI_ARPROT : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
         S09_AXI_ARQOS : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         S09_AXI_ARVALID : IN STD_LOGIC;
         S09_AXI_ARREADY : OUT STD_LOGIC;
         S09_AXI_RID : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
         S09_AXI_RDATA : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
         S09_AXI_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         S09_AXI_RLAST : OUT STD_LOGIC;
         S09_AXI_RVALID : OUT STD_LOGIC;
         S09_AXI_RREADY : IN STD_LOGIC;
         M00_AXI_ARESET_OUT_N : OUT STD_LOGIC;
         M00_AXI_ACLK : IN STD_LOGIC;
         M00_AXI_AWID : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_AWADDR : OUT STD_LOGIC_VECTOR(29 DOWNTO 0);
         M00_AXI_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
         M00_AXI_AWSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_AWBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_AWLOCK : OUT STD_LOGIC;
         M00_AXI_AWCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_AWQOS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_AWVALID : OUT STD_LOGIC;
         M00_AXI_AWREADY : IN STD_LOGIC;
         M00_AXI_WDATA : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
         M00_AXI_WSTRB : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
         M00_AXI_WLAST : OUT STD_LOGIC;
         M00_AXI_WVALID : OUT STD_LOGIC;
         M00_AXI_WREADY : IN STD_LOGIC;
         M00_AXI_BID : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_BVALID : IN STD_LOGIC;
         M00_AXI_BREADY : OUT STD_LOGIC;
         M00_AXI_ARID : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_ARADDR : OUT STD_LOGIC_VECTOR(29 DOWNTO 0);
         M00_AXI_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
         M00_AXI_ARSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_ARLOCK : OUT STD_LOGIC;
         M00_AXI_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
         M00_AXI_ARQOS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_ARVALID : OUT STD_LOGIC;
         M00_AXI_ARREADY : IN STD_LOGIC;
         M00_AXI_RID : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
         M00_AXI_RDATA : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
         M00_AXI_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
         M00_AXI_RLAST : IN STD_LOGIC;
         M00_AXI_RVALID : IN STD_LOGIC;
         M00_AXI_RREADY : OUT STD_LOGIC
      );
   END COMPONENT;
   
   signal aximRstN            : sl;
   
   -- AXI Interconnect RTL 1.7 generates ports for unused channels
   -- unused channels
   signal axiAdcReadMasters   : AxiReadMasterArray(7 downto 0);
   signal axiAdcReadSlaves    : AxiReadSlaveArray(7 downto 0);
   signal axiDoutWriteMaster  : AxiWriteMasterType;
   signal axiDoutWriteSlave   : AxiWriteSlaveType;

begin
   
   aximRstN <= not aximRst;
   
   -- AXI Interconnect RTL 1.7 generates ports for unused channels
   -- unused channels
   axiAdcReadMasters    <= (others=>AXI_READ_MASTER_INIT_C);
   axiDoutWriteMaster   <= AXI_WRITE_MASTER_INIT_C;

   U_AxiInterconnect : AxiInterconnect
   PORT MAP (
      INTERCONNECT_ACLK       => aximClk,
      INTERCONNECT_ARESETN    => aximRstN,
      
      S00_AXI_ARESET_OUT_N    => open,
      S00_AXI_ACLK            => axiAdcClk,
      S00_AXI_AWID            => axiAdcWriteMasters(0).awid(0 downto 0),
      S00_AXI_AWADDR          => axiAdcWriteMasters(0).awaddr(29 downto 0),
      S00_AXI_AWLEN           => axiAdcWriteMasters(0).awlen,
      S00_AXI_AWSIZE          => axiAdcWriteMasters(0).awsize,
      S00_AXI_AWBURST         => axiAdcWriteMasters(0).awburst,
      S00_AXI_AWLOCK          => axiAdcWriteMasters(0).awlock(0),
      S00_AXI_AWCACHE         => axiAdcWriteMasters(0).awcache,
      S00_AXI_AWPROT          => axiAdcWriteMasters(0).awprot,
      S00_AXI_AWQOS           => axiAdcWriteMasters(0).awqos,
      S00_AXI_AWVALID         => axiAdcWriteMasters(0).awvalid,
      S00_AXI_AWREADY         => axiAdcWriteSlaves(0).awready,
      S00_AXI_WDATA           => axiAdcWriteMasters(0).wdata(127 downto 0),
      S00_AXI_WSTRB           => axiAdcWriteMasters(0).wstrb(15 downto 0),
      S00_AXI_WLAST           => axiAdcWriteMasters(0).wlast,
      S00_AXI_WVALID          => axiAdcWriteMasters(0).wvalid,
      S00_AXI_WREADY          => axiAdcWriteSlaves(0).wready,
      S00_AXI_BID             => axiAdcWriteSlaves(0).bid(0 downto 0),
      S00_AXI_BRESP           => axiAdcWriteSlaves(0).bresp,
      S00_AXI_BVALID          => axiAdcWriteSlaves(0).bvalid,
      S00_AXI_BREADY          => axiAdcWriteMasters(0).bready,
      S00_AXI_ARID            => axiAdcReadMasters(0).arid(0 downto 0),
      S00_AXI_ARADDR          => axiAdcReadMasters(0).araddr(29 downto 0),
      S00_AXI_ARLEN           => axiAdcReadMasters(0).arlen,
      S00_AXI_ARSIZE          => axiAdcReadMasters(0).arsize,
      S00_AXI_ARBURST         => axiAdcReadMasters(0).arburst,
      S00_AXI_ARLOCK          => axiAdcReadMasters(0).arlock(0),
      S00_AXI_ARCACHE         => axiAdcReadMasters(0).arcache,
      S00_AXI_ARPROT          => axiAdcReadMasters(0).arprot,
      S00_AXI_ARQOS           => axiAdcReadMasters(0).arqos,
      S00_AXI_ARVALID         => axiAdcReadMasters(0).arvalid,
      S00_AXI_ARREADY         => axiAdcReadSlaves(0).arready,
      S00_AXI_RID             => axiAdcReadSlaves(0).rid(0 downto 0),
      S00_AXI_RDATA           => axiAdcReadSlaves(0).rdata(127 downto 0),
      S00_AXI_RRESP           => axiAdcReadSlaves(0).rresp,
      S00_AXI_RLAST           => axiAdcReadSlaves(0).rlast,
      S00_AXI_RVALID          => axiAdcReadSlaves(0).rvalid,
      S00_AXI_RREADY          => axiAdcReadMasters(0).rready,
      
      S01_AXI_ARESET_OUT_N    => open,
      S01_AXI_ACLK            => axiAdcClk,
      S01_AXI_AWID            => axiAdcWriteMasters(1).awid(0 downto 0),
      S01_AXI_AWADDR          => axiAdcWriteMasters(1).awaddr(29 downto 0),
      S01_AXI_AWLEN           => axiAdcWriteMasters(1).awlen,
      S01_AXI_AWSIZE          => axiAdcWriteMasters(1).awsize,
      S01_AXI_AWBURST         => axiAdcWriteMasters(1).awburst,
      S01_AXI_AWLOCK          => axiAdcWriteMasters(1).awlock(0),
      S01_AXI_AWCACHE         => axiAdcWriteMasters(1).awcache,
      S01_AXI_AWPROT          => axiAdcWriteMasters(1).awprot,
      S01_AXI_AWQOS           => axiAdcWriteMasters(1).awqos,
      S01_AXI_AWVALID         => axiAdcWriteMasters(1).awvalid,
      S01_AXI_AWREADY         => axiAdcWriteSlaves(1).awready,
      S01_AXI_WDATA           => axiAdcWriteMasters(1).wdata(127 downto 0),
      S01_AXI_WSTRB           => axiAdcWriteMasters(1).wstrb(15 downto 0),
      S01_AXI_WLAST           => axiAdcWriteMasters(1).wlast,
      S01_AXI_WVALID          => axiAdcWriteMasters(1).wvalid,
      S01_AXI_WREADY          => axiAdcWriteSlaves(1).wready,
      S01_AXI_BID             => axiAdcWriteSlaves(1).bid(0 downto 0),
      S01_AXI_BRESP           => axiAdcWriteSlaves(1).bresp,
      S01_AXI_BVALID          => axiAdcWriteSlaves(1).bvalid,
      S01_AXI_BREADY          => axiAdcWriteMasters(1).bready,
      S01_AXI_ARID            => axiAdcReadMasters(1).arid(0 downto 0),
      S01_AXI_ARADDR          => axiAdcReadMasters(1).araddr(29 downto 0),
      S01_AXI_ARLEN           => axiAdcReadMasters(1).arlen,
      S01_AXI_ARSIZE          => axiAdcReadMasters(1).arsize,
      S01_AXI_ARBURST         => axiAdcReadMasters(1).arburst,
      S01_AXI_ARLOCK          => axiAdcReadMasters(1).arlock(0),
      S01_AXI_ARCACHE         => axiAdcReadMasters(1).arcache,
      S01_AXI_ARPROT          => axiAdcReadMasters(1).arprot,
      S01_AXI_ARQOS           => axiAdcReadMasters(1).arqos,
      S01_AXI_ARVALID         => axiAdcReadMasters(1).arvalid,
      S01_AXI_ARREADY         => axiAdcReadSlaves(1).arready,
      S01_AXI_RID             => axiAdcReadSlaves(1).rid(0 downto 0),
      S01_AXI_RDATA           => axiAdcReadSlaves(1).rdata(127 downto 0),
      S01_AXI_RRESP           => axiAdcReadSlaves(1).rresp,
      S01_AXI_RLAST           => axiAdcReadSlaves(1).rlast,
      S01_AXI_RVALID          => axiAdcReadSlaves(1).rvalid,
      S01_AXI_RREADY          => axiAdcReadMasters(1).rready,
      
      S02_AXI_ARESET_OUT_N    => open,
      S02_AXI_ACLK            => axiAdcClk,
      S02_AXI_AWID            => axiAdcWriteMasters(2).awid(0 downto 0),
      S02_AXI_AWADDR          => axiAdcWriteMasters(2).awaddr(29 downto 0),
      S02_AXI_AWLEN           => axiAdcWriteMasters(2).awlen,
      S02_AXI_AWSIZE          => axiAdcWriteMasters(2).awsize,
      S02_AXI_AWBURST         => axiAdcWriteMasters(2).awburst,
      S02_AXI_AWLOCK          => axiAdcWriteMasters(2).awlock(0),
      S02_AXI_AWCACHE         => axiAdcWriteMasters(2).awcache,
      S02_AXI_AWPROT          => axiAdcWriteMasters(2).awprot,
      S02_AXI_AWQOS           => axiAdcWriteMasters(2).awqos,
      S02_AXI_AWVALID         => axiAdcWriteMasters(2).awvalid,
      S02_AXI_AWREADY         => axiAdcWriteSlaves(2).awready,
      S02_AXI_WDATA           => axiAdcWriteMasters(2).wdata(127 downto 0),
      S02_AXI_WSTRB           => axiAdcWriteMasters(2).wstrb(15 downto 0),
      S02_AXI_WLAST           => axiAdcWriteMasters(2).wlast,
      S02_AXI_WVALID          => axiAdcWriteMasters(2).wvalid,
      S02_AXI_WREADY          => axiAdcWriteSlaves(2).wready,
      S02_AXI_BID             => axiAdcWriteSlaves(2).bid(0 downto 0),
      S02_AXI_BRESP           => axiAdcWriteSlaves(2).bresp,
      S02_AXI_BVALID          => axiAdcWriteSlaves(2).bvalid,
      S02_AXI_BREADY          => axiAdcWriteMasters(2).bready,
      S02_AXI_ARID            => axiAdcReadMasters(2).arid(0 downto 0),
      S02_AXI_ARADDR          => axiAdcReadMasters(2).araddr(29 downto 0),
      S02_AXI_ARLEN           => axiAdcReadMasters(2).arlen,
      S02_AXI_ARSIZE          => axiAdcReadMasters(2).arsize,
      S02_AXI_ARBURST         => axiAdcReadMasters(2).arburst,
      S02_AXI_ARLOCK          => axiAdcReadMasters(2).arlock(0),
      S02_AXI_ARCACHE         => axiAdcReadMasters(2).arcache,
      S02_AXI_ARPROT          => axiAdcReadMasters(2).arprot,
      S02_AXI_ARQOS           => axiAdcReadMasters(2).arqos,
      S02_AXI_ARVALID         => axiAdcReadMasters(2).arvalid,
      S02_AXI_ARREADY         => axiAdcReadSlaves(2).arready,
      S02_AXI_RID             => axiAdcReadSlaves(2).rid(0 downto 0),
      S02_AXI_RDATA           => axiAdcReadSlaves(2).rdata(127 downto 0),
      S02_AXI_RRESP           => axiAdcReadSlaves(2).rresp,
      S02_AXI_RLAST           => axiAdcReadSlaves(2).rlast,
      S02_AXI_RVALID          => axiAdcReadSlaves(2).rvalid,
      S02_AXI_RREADY          => axiAdcReadMasters(2).rready,
      
      S03_AXI_ARESET_OUT_N    => open,
      S03_AXI_ACLK            => axiAdcClk,
      S03_AXI_AWID            => axiAdcWriteMasters(3).awid(0 downto 0),
      S03_AXI_AWADDR          => axiAdcWriteMasters(3).awaddr(29 downto 0),
      S03_AXI_AWLEN           => axiAdcWriteMasters(3).awlen,
      S03_AXI_AWSIZE          => axiAdcWriteMasters(3).awsize,
      S03_AXI_AWBURST         => axiAdcWriteMasters(3).awburst,
      S03_AXI_AWLOCK          => axiAdcWriteMasters(3).awlock(0),
      S03_AXI_AWCACHE         => axiAdcWriteMasters(3).awcache,
      S03_AXI_AWPROT          => axiAdcWriteMasters(3).awprot,
      S03_AXI_AWQOS           => axiAdcWriteMasters(3).awqos,
      S03_AXI_AWVALID         => axiAdcWriteMasters(3).awvalid,
      S03_AXI_AWREADY         => axiAdcWriteSlaves(3).awready,
      S03_AXI_WDATA           => axiAdcWriteMasters(3).wdata(127 downto 0),
      S03_AXI_WSTRB           => axiAdcWriteMasters(3).wstrb(15 downto 0),
      S03_AXI_WLAST           => axiAdcWriteMasters(3).wlast,
      S03_AXI_WVALID          => axiAdcWriteMasters(3).wvalid,
      S03_AXI_WREADY          => axiAdcWriteSlaves(3).wready,
      S03_AXI_BID             => axiAdcWriteSlaves(3).bid(0 downto 0),
      S03_AXI_BRESP           => axiAdcWriteSlaves(3).bresp,
      S03_AXI_BVALID          => axiAdcWriteSlaves(3).bvalid,
      S03_AXI_BREADY          => axiAdcWriteMasters(3).bready,
      S03_AXI_ARID            => axiAdcReadMasters(3).arid(0 downto 0),
      S03_AXI_ARADDR          => axiAdcReadMasters(3).araddr(29 downto 0),
      S03_AXI_ARLEN           => axiAdcReadMasters(3).arlen,
      S03_AXI_ARSIZE          => axiAdcReadMasters(3).arsize,
      S03_AXI_ARBURST         => axiAdcReadMasters(3).arburst,
      S03_AXI_ARLOCK          => axiAdcReadMasters(3).arlock(0),
      S03_AXI_ARCACHE         => axiAdcReadMasters(3).arcache,
      S03_AXI_ARPROT          => axiAdcReadMasters(3).arprot,
      S03_AXI_ARQOS           => axiAdcReadMasters(3).arqos,
      S03_AXI_ARVALID         => axiAdcReadMasters(3).arvalid,
      S03_AXI_ARREADY         => axiAdcReadSlaves(3).arready,
      S03_AXI_RID             => axiAdcReadSlaves(3).rid(0 downto 0),
      S03_AXI_RDATA           => axiAdcReadSlaves(3).rdata(127 downto 0),
      S03_AXI_RRESP           => axiAdcReadSlaves(3).rresp,
      S03_AXI_RLAST           => axiAdcReadSlaves(3).rlast,
      S03_AXI_RVALID          => axiAdcReadSlaves(3).rvalid,
      S03_AXI_RREADY          => axiAdcReadMasters(3).rready,
      
      S04_AXI_ARESET_OUT_N    => open,
      S04_AXI_ACLK            => axiAdcClk,
      S04_AXI_AWID            => axiAdcWriteMasters(4).awid(0 downto 0),
      S04_AXI_AWADDR          => axiAdcWriteMasters(4).awaddr(29 downto 0),
      S04_AXI_AWLEN           => axiAdcWriteMasters(4).awlen,
      S04_AXI_AWSIZE          => axiAdcWriteMasters(4).awsize,
      S04_AXI_AWBURST         => axiAdcWriteMasters(4).awburst,
      S04_AXI_AWLOCK          => axiAdcWriteMasters(4).awlock(0),
      S04_AXI_AWCACHE         => axiAdcWriteMasters(4).awcache,
      S04_AXI_AWPROT          => axiAdcWriteMasters(4).awprot,
      S04_AXI_AWQOS           => axiAdcWriteMasters(4).awqos,
      S04_AXI_AWVALID         => axiAdcWriteMasters(4).awvalid,
      S04_AXI_AWREADY         => axiAdcWriteSlaves(4).awready,
      S04_AXI_WDATA           => axiAdcWriteMasters(4).wdata(127 downto 0),
      S04_AXI_WSTRB           => axiAdcWriteMasters(4).wstrb(15 downto 0),
      S04_AXI_WLAST           => axiAdcWriteMasters(4).wlast,
      S04_AXI_WVALID          => axiAdcWriteMasters(4).wvalid,
      S04_AXI_WREADY          => axiAdcWriteSlaves(4).wready,
      S04_AXI_BID             => axiAdcWriteSlaves(4).bid(0 downto 0),
      S04_AXI_BRESP           => axiAdcWriteSlaves(4).bresp,
      S04_AXI_BVALID          => axiAdcWriteSlaves(4).bvalid,
      S04_AXI_BREADY          => axiAdcWriteMasters(4).bready,
      S04_AXI_ARID            => axiAdcReadMasters(4).arid(0 downto 0),
      S04_AXI_ARADDR          => axiAdcReadMasters(4).araddr(29 downto 0),
      S04_AXI_ARLEN           => axiAdcReadMasters(4).arlen,
      S04_AXI_ARSIZE          => axiAdcReadMasters(4).arsize,
      S04_AXI_ARBURST         => axiAdcReadMasters(4).arburst,
      S04_AXI_ARLOCK          => axiAdcReadMasters(4).arlock(0),
      S04_AXI_ARCACHE         => axiAdcReadMasters(4).arcache,
      S04_AXI_ARPROT          => axiAdcReadMasters(4).arprot,
      S04_AXI_ARQOS           => axiAdcReadMasters(4).arqos,
      S04_AXI_ARVALID         => axiAdcReadMasters(4).arvalid,
      S04_AXI_ARREADY         => axiAdcReadSlaves(4).arready,
      S04_AXI_RID             => axiAdcReadSlaves(4).rid(0 downto 0),
      S04_AXI_RDATA           => axiAdcReadSlaves(4).rdata(127 downto 0),
      S04_AXI_RRESP           => axiAdcReadSlaves(4).rresp,
      S04_AXI_RLAST           => axiAdcReadSlaves(4).rlast,
      S04_AXI_RVALID          => axiAdcReadSlaves(4).rvalid,
      S04_AXI_RREADY          => axiAdcReadMasters(4).rready,
      
      S05_AXI_ARESET_OUT_N    => open,
      S05_AXI_ACLK            => axiAdcClk,
      S05_AXI_AWID            => axiAdcWriteMasters(5).awid(0 downto 0),
      S05_AXI_AWADDR          => axiAdcWriteMasters(5).awaddr(29 downto 0),
      S05_AXI_AWLEN           => axiAdcWriteMasters(5).awlen,
      S05_AXI_AWSIZE          => axiAdcWriteMasters(5).awsize,
      S05_AXI_AWBURST         => axiAdcWriteMasters(5).awburst,
      S05_AXI_AWLOCK          => axiAdcWriteMasters(5).awlock(0),
      S05_AXI_AWCACHE         => axiAdcWriteMasters(5).awcache,
      S05_AXI_AWPROT          => axiAdcWriteMasters(5).awprot,
      S05_AXI_AWQOS           => axiAdcWriteMasters(5).awqos,
      S05_AXI_AWVALID         => axiAdcWriteMasters(5).awvalid,
      S05_AXI_AWREADY         => axiAdcWriteSlaves(5).awready,
      S05_AXI_WDATA           => axiAdcWriteMasters(5).wdata(127 downto 0),
      S05_AXI_WSTRB           => axiAdcWriteMasters(5).wstrb(15 downto 0),
      S05_AXI_WLAST           => axiAdcWriteMasters(5).wlast,
      S05_AXI_WVALID          => axiAdcWriteMasters(5).wvalid,
      S05_AXI_WREADY          => axiAdcWriteSlaves(5).wready,
      S05_AXI_BID             => axiAdcWriteSlaves(5).bid(0 downto 0),
      S05_AXI_BRESP           => axiAdcWriteSlaves(5).bresp,
      S05_AXI_BVALID          => axiAdcWriteSlaves(5).bvalid,
      S05_AXI_BREADY          => axiAdcWriteMasters(5).bready,
      S05_AXI_ARID            => axiAdcReadMasters(5).arid(0 downto 0),
      S05_AXI_ARADDR          => axiAdcReadMasters(5).araddr(29 downto 0),
      S05_AXI_ARLEN           => axiAdcReadMasters(5).arlen,
      S05_AXI_ARSIZE          => axiAdcReadMasters(5).arsize,
      S05_AXI_ARBURST         => axiAdcReadMasters(5).arburst,
      S05_AXI_ARLOCK          => axiAdcReadMasters(5).arlock(0),
      S05_AXI_ARCACHE         => axiAdcReadMasters(5).arcache,
      S05_AXI_ARPROT          => axiAdcReadMasters(5).arprot,
      S05_AXI_ARQOS           => axiAdcReadMasters(5).arqos,
      S05_AXI_ARVALID         => axiAdcReadMasters(5).arvalid,
      S05_AXI_ARREADY         => axiAdcReadSlaves(5).arready,
      S05_AXI_RID             => axiAdcReadSlaves(5).rid(0 downto 0),
      S05_AXI_RDATA           => axiAdcReadSlaves(5).rdata(127 downto 0),
      S05_AXI_RRESP           => axiAdcReadSlaves(5).rresp,
      S05_AXI_RLAST           => axiAdcReadSlaves(5).rlast,
      S05_AXI_RVALID          => axiAdcReadSlaves(5).rvalid,
      S05_AXI_RREADY          => axiAdcReadMasters(5).rready,
      
      S06_AXI_ARESET_OUT_N    => open,
      S06_AXI_ACLK            => axiAdcClk,
      S06_AXI_AWID            => axiAdcWriteMasters(6).awid(0 downto 0),
      S06_AXI_AWADDR          => axiAdcWriteMasters(6).awaddr(29 downto 0),
      S06_AXI_AWLEN           => axiAdcWriteMasters(6).awlen,
      S06_AXI_AWSIZE          => axiAdcWriteMasters(6).awsize,
      S06_AXI_AWBURST         => axiAdcWriteMasters(6).awburst,
      S06_AXI_AWLOCK          => axiAdcWriteMasters(6).awlock(0),
      S06_AXI_AWCACHE         => axiAdcWriteMasters(6).awcache,
      S06_AXI_AWPROT          => axiAdcWriteMasters(6).awprot,
      S06_AXI_AWQOS           => axiAdcWriteMasters(6).awqos,
      S06_AXI_AWVALID         => axiAdcWriteMasters(6).awvalid,
      S06_AXI_AWREADY         => axiAdcWriteSlaves(6).awready,
      S06_AXI_WDATA           => axiAdcWriteMasters(6).wdata(127 downto 0),
      S06_AXI_WSTRB           => axiAdcWriteMasters(6).wstrb(15 downto 0),
      S06_AXI_WLAST           => axiAdcWriteMasters(6).wlast,
      S06_AXI_WVALID          => axiAdcWriteMasters(6).wvalid,
      S06_AXI_WREADY          => axiAdcWriteSlaves(6).wready,
      S06_AXI_BID             => axiAdcWriteSlaves(6).bid(0 downto 0),
      S06_AXI_BRESP           => axiAdcWriteSlaves(6).bresp,
      S06_AXI_BVALID          => axiAdcWriteSlaves(6).bvalid,
      S06_AXI_BREADY          => axiAdcWriteMasters(6).bready,
      S06_AXI_ARID            => axiAdcReadMasters(6).arid(0 downto 0),
      S06_AXI_ARADDR          => axiAdcReadMasters(6).araddr(29 downto 0),
      S06_AXI_ARLEN           => axiAdcReadMasters(6).arlen,
      S06_AXI_ARSIZE          => axiAdcReadMasters(6).arsize,
      S06_AXI_ARBURST         => axiAdcReadMasters(6).arburst,
      S06_AXI_ARLOCK          => axiAdcReadMasters(6).arlock(0),
      S06_AXI_ARCACHE         => axiAdcReadMasters(6).arcache,
      S06_AXI_ARPROT          => axiAdcReadMasters(6).arprot,
      S06_AXI_ARQOS           => axiAdcReadMasters(6).arqos,
      S06_AXI_ARVALID         => axiAdcReadMasters(6).arvalid,
      S06_AXI_ARREADY         => axiAdcReadSlaves(6).arready,
      S06_AXI_RID             => axiAdcReadSlaves(6).rid(0 downto 0),
      S06_AXI_RDATA           => axiAdcReadSlaves(6).rdata(127 downto 0),
      S06_AXI_RRESP           => axiAdcReadSlaves(6).rresp,
      S06_AXI_RLAST           => axiAdcReadSlaves(6).rlast,
      S06_AXI_RVALID          => axiAdcReadSlaves(6).rvalid,
      S06_AXI_RREADY          => axiAdcReadMasters(6).rready,
      
      S07_AXI_ARESET_OUT_N    => open,
      S07_AXI_ACLK            => axiAdcClk,
      S07_AXI_AWID            => axiAdcWriteMasters(7).awid(0 downto 0),
      S07_AXI_AWADDR          => axiAdcWriteMasters(7).awaddr(29 downto 0),
      S07_AXI_AWLEN           => axiAdcWriteMasters(7).awlen,
      S07_AXI_AWSIZE          => axiAdcWriteMasters(7).awsize,
      S07_AXI_AWBURST         => axiAdcWriteMasters(7).awburst,
      S07_AXI_AWLOCK          => axiAdcWriteMasters(7).awlock(0),
      S07_AXI_AWCACHE         => axiAdcWriteMasters(7).awcache,
      S07_AXI_AWPROT          => axiAdcWriteMasters(7).awprot,
      S07_AXI_AWQOS           => axiAdcWriteMasters(7).awqos,
      S07_AXI_AWVALID         => axiAdcWriteMasters(7).awvalid,
      S07_AXI_AWREADY         => axiAdcWriteSlaves(7).awready,
      S07_AXI_WDATA           => axiAdcWriteMasters(7).wdata(127 downto 0),
      S07_AXI_WSTRB           => axiAdcWriteMasters(7).wstrb(15 downto 0),
      S07_AXI_WLAST           => axiAdcWriteMasters(7).wlast,
      S07_AXI_WVALID          => axiAdcWriteMasters(7).wvalid,
      S07_AXI_WREADY          => axiAdcWriteSlaves(7).wready,
      S07_AXI_BID             => axiAdcWriteSlaves(7).bid(0 downto 0),
      S07_AXI_BRESP           => axiAdcWriteSlaves(7).bresp,
      S07_AXI_BVALID          => axiAdcWriteSlaves(7).bvalid,
      S07_AXI_BREADY          => axiAdcWriteMasters(7).bready,
      S07_AXI_ARID            => axiAdcReadMasters(7).arid(0 downto 0),
      S07_AXI_ARADDR          => axiAdcReadMasters(7).araddr(29 downto 0),
      S07_AXI_ARLEN           => axiAdcReadMasters(7).arlen,
      S07_AXI_ARSIZE          => axiAdcReadMasters(7).arsize,
      S07_AXI_ARBURST         => axiAdcReadMasters(7).arburst,
      S07_AXI_ARLOCK          => axiAdcReadMasters(7).arlock(0),
      S07_AXI_ARCACHE         => axiAdcReadMasters(7).arcache,
      S07_AXI_ARPROT          => axiAdcReadMasters(7).arprot,
      S07_AXI_ARQOS           => axiAdcReadMasters(7).arqos,
      S07_AXI_ARVALID         => axiAdcReadMasters(7).arvalid,
      S07_AXI_ARREADY         => axiAdcReadSlaves(7).arready,
      S07_AXI_RID             => axiAdcReadSlaves(7).rid(0 downto 0),
      S07_AXI_RDATA           => axiAdcReadSlaves(7).rdata(127 downto 0),
      S07_AXI_RRESP           => axiAdcReadSlaves(7).rresp,
      S07_AXI_RLAST           => axiAdcReadSlaves(7).rlast,
      S07_AXI_RVALID          => axiAdcReadSlaves(7).rvalid,
      S07_AXI_RREADY          => axiAdcReadMasters(7).rready,
      
      S08_AXI_ARESET_OUT_N    => open,
      S08_AXI_ACLK            => axiDoutClk,
      S08_AXI_AWID            => axiDoutWriteMaster.awid(0 downto 0),
      S08_AXI_AWADDR          => axiDoutWriteMaster.awaddr(29 downto 0),
      S08_AXI_AWLEN           => axiDoutWriteMaster.awlen,
      S08_AXI_AWSIZE          => axiDoutWriteMaster.awsize,
      S08_AXI_AWBURST         => axiDoutWriteMaster.awburst,
      S08_AXI_AWLOCK          => axiDoutWriteMaster.awlock(0),
      S08_AXI_AWCACHE         => axiDoutWriteMaster.awcache,
      S08_AXI_AWPROT          => axiDoutWriteMaster.awprot,
      S08_AXI_AWQOS           => axiDoutWriteMaster.awqos,
      S08_AXI_AWVALID         => axiDoutWriteMaster.awvalid,
      S08_AXI_AWREADY         => axiDoutWriteSlave.awready,
      S08_AXI_WDATA           => axiDoutWriteMaster.wdata(31 downto 0),
      S08_AXI_WSTRB           => axiDoutWriteMaster.wstrb(3 downto 0),
      S08_AXI_WLAST           => axiDoutWriteMaster.wlast,
      S08_AXI_WVALID          => axiDoutWriteMaster.wvalid,
      S08_AXI_WREADY          => axiDoutWriteSlave.wready,
      S08_AXI_BID             => axiDoutWriteSlave.bid(0 downto 0),
      S08_AXI_BRESP           => axiDoutWriteSlave.bresp,
      S08_AXI_BVALID          => axiDoutWriteSlave.bvalid,
      S08_AXI_BREADY          => axiDoutWriteMaster.bready,
      S08_AXI_ARID            => axiDoutReadMaster.arid(0 downto 0),
      S08_AXI_ARADDR          => axiDoutReadMaster.araddr(29 downto 0),
      S08_AXI_ARLEN           => axiDoutReadMaster.arlen,
      S08_AXI_ARSIZE          => axiDoutReadMaster.arsize,
      S08_AXI_ARBURST         => axiDoutReadMaster.arburst,
      S08_AXI_ARLOCK          => axiDoutReadMaster.arlock(0),
      S08_AXI_ARCACHE         => axiDoutReadMaster.arcache,
      S08_AXI_ARPROT          => axiDoutReadMaster.arprot,
      S08_AXI_ARQOS           => axiDoutReadMaster.arqos,
      S08_AXI_ARVALID         => axiDoutReadMaster.arvalid,
      S08_AXI_ARREADY         => axiDoutReadSlave.arready,
      S08_AXI_RID             => axiDoutReadSlave.rid(0 downto 0),
      S08_AXI_RDATA           => axiDoutReadSlave.rdata(31 downto 0),
      S08_AXI_RRESP           => axiDoutReadSlave.rresp,
      S08_AXI_RLAST           => axiDoutReadSlave.rlast,
      S08_AXI_RVALID          => axiDoutReadSlave.rvalid,
      S08_AXI_RREADY          => axiDoutReadMaster.rready,
      
      S09_AXI_ARESET_OUT_N    => open,
      S09_AXI_ACLK            => aximClk,
      S09_AXI_AWID            => axiBistWriteMaster.awid(0 downto 0),
      S09_AXI_AWADDR          => axiBistWriteMaster.awaddr(29 downto 0),
      S09_AXI_AWLEN           => axiBistWriteMaster.awlen,
      S09_AXI_AWSIZE          => axiBistWriteMaster.awsize,
      S09_AXI_AWBURST         => axiBistWriteMaster.awburst,
      S09_AXI_AWLOCK          => axiBistWriteMaster.awlock(0),
      S09_AXI_AWCACHE         => axiBistWriteMaster.awcache,
      S09_AXI_AWPROT          => axiBistWriteMaster.awprot,
      S09_AXI_AWQOS           => axiBistWriteMaster.awqos,
      S09_AXI_AWVALID         => axiBistWriteMaster.awvalid,
      S09_AXI_AWREADY         => axiBistWriteSlave.awready,
      S09_AXI_WDATA           => axiBistWriteMaster.wdata(255 downto 0),
      S09_AXI_WSTRB           => axiBistWriteMaster.wstrb(31 downto 0),
      S09_AXI_WLAST           => axiBistWriteMaster.wlast,
      S09_AXI_WVALID          => axiBistWriteMaster.wvalid,
      S09_AXI_WREADY          => axiBistWriteSlave.wready,
      S09_AXI_BID             => axiBistWriteSlave.bid(0 downto 0),
      S09_AXI_BRESP           => axiBistWriteSlave.bresp,
      S09_AXI_BVALID          => axiBistWriteSlave.bvalid,
      S09_AXI_BREADY          => axiBistWriteMaster.bready,
      S09_AXI_ARID            => axiBistReadMaster.arid(0 downto 0),
      S09_AXI_ARADDR          => axiBistReadMaster.araddr(29 downto 0),
      S09_AXI_ARLEN           => axiBistReadMaster.arlen,
      S09_AXI_ARSIZE          => axiBistReadMaster.arsize,
      S09_AXI_ARBURST         => axiBistReadMaster.arburst,
      S09_AXI_ARLOCK          => axiBistReadMaster.arlock(0),
      S09_AXI_ARCACHE         => axiBistReadMaster.arcache,
      S09_AXI_ARPROT          => axiBistReadMaster.arprot,
      S09_AXI_ARQOS           => axiBistReadMaster.arqos,
      S09_AXI_ARVALID         => axiBistReadMaster.arvalid,
      S09_AXI_ARREADY         => axiBistReadSlave.arready,
      S09_AXI_RID             => axiBistReadSlave.rid(0 downto 0),
      S09_AXI_RDATA           => axiBistReadSlave.rdata(255 downto 0),
      S09_AXI_RRESP           => axiBistReadSlave.rresp,
      S09_AXI_RLAST           => axiBistReadSlave.rlast,
      S09_AXI_RVALID          => axiBistReadSlave.rvalid,
      S09_AXI_RREADY          => axiBistReadMaster.rready,
      
      M00_AXI_ARESET_OUT_N    => open,
      M00_AXI_ACLK            => aximClk,
      M00_AXI_AWID            => aximWriteMaster.awid(3 downto 0),
      M00_AXI_AWADDR          => aximWriteMaster.awaddr(29 downto 0),
      M00_AXI_AWLEN           => aximWriteMaster.awlen,
      M00_AXI_AWSIZE          => aximWriteMaster.awsize,
      M00_AXI_AWBURST         => aximWriteMaster.awburst,
      M00_AXI_AWLOCK          => aximWriteMaster.awlock(0),
      M00_AXI_AWCACHE         => aximWriteMaster.awcache,
      M00_AXI_AWPROT          => aximWriteMaster.awprot,
      M00_AXI_AWQOS           => aximWriteMaster.awqos,
      M00_AXI_AWVALID         => aximWriteMaster.awvalid,
      M00_AXI_AWREADY         => aximWriteSlave.awready,
      M00_AXI_WDATA           => aximWriteMaster.wdata(255 downto 0),
      M00_AXI_WSTRB           => aximWriteMaster.wstrb(31 downto 0),
      M00_AXI_WLAST           => aximWriteMaster.wlast,
      M00_AXI_WVALID          => aximWriteMaster.wvalid,
      M00_AXI_WREADY          => aximWriteSlave.wready,
      M00_AXI_BID             => aximWriteSlave.bid(3 downto 0),
      M00_AXI_BRESP           => aximWriteSlave.bresp,
      M00_AXI_BVALID          => aximWriteSlave.bvalid,
      M00_AXI_BREADY          => aximWriteMaster.bready,
      M00_AXI_ARID            => aximReadMaster.arid(3 downto 0),
      M00_AXI_ARADDR          => aximReadMaster.araddr(29 downto 0),
      M00_AXI_ARLEN           => aximReadMaster.arlen,
      M00_AXI_ARSIZE          => aximReadMaster.arsize,
      M00_AXI_ARBURST         => aximReadMaster.arburst,
      M00_AXI_ARLOCK          => aximReadMaster.arlock(0),
      M00_AXI_ARCACHE         => aximReadMaster.arcache,
      M00_AXI_ARPROT          => aximReadMaster.arprot,
      M00_AXI_ARQOS           => aximReadMaster.arqos,
      M00_AXI_ARVALID         => aximReadMaster.arvalid,
      M00_AXI_ARREADY         => aximReadSlave.arready,
      M00_AXI_RID             => aximReadSlave.rid(3 downto 0),
      M00_AXI_RDATA           => aximReadSlave.rdata(255 downto 0),
      M00_AXI_RRESP           => aximReadSlave.rresp,
      M00_AXI_RLAST           => aximReadSlave.rlast,
      M00_AXI_RVALID          => aximReadSlave.rvalid,
      M00_AXI_RREADY          => aximReadMaster.rready
   );

end mapping;
