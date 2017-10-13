-------------------------------------------------------------------------------
-- File       : FastAdcBuffer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-10-04
-- Last update: 2017-10-13
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
use work.AxiPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;

entity FastAdcBuffer is
   generic (
      TPD_G            : time             := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C;
      AXI_BASE_ADDR_G  : slv(31 downto 0) := (others => '0'));
   port (
      -- ADC interface
      adcClk          : in  sl;
      adcRst          : in  sl;
      adcValid        : in  slv(7 downto 0);
      adcData         : in  Slv64Array(7 downto 0);
      gTime           : in  slv(63 downto 0);
      extTrigger      : in  sl;
      -- AXI-Lite Interface (axilClk domain)
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- AxiStream output (axisClk domain)
      axisClk         : in  sl;
      axisRst         : in  sl;
      axisMaster      : out AxiStreamMasterType;
      axisSlave       : in  AxiStreamSlaveType
      );
end FastAdcBuffer;

architecture mapping of FastAdcBuffer is

   constant NUM_AXI_MASTERS_C : natural := 8;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 24, 20);

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal axisMasters : AxiStreamMasterArray(7 downto 0);
   signal axisSlaves  : AxiStreamSlaveArray(7 downto 0);

begin

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

   ---------------------
   -- Fast ADC buffers
   ---------------------
   GEN_VEC : for i in 7 downto 0 generate
      U_FastAdcChannel : entity work.FastAdcBufferChannel
         generic map (
            TPD_G     => TPD_G,
            CHANNEL_G => toSlv(i, 8))
         port map (
            -- ADC Clock Domain
            adcClk          => adcClk,
            adcRst          => adcRst,
            adcData         => adcData(i),
            adcValid        => adcValid(i),
            gTime           => gTime,
            extTrigger      => extTrigger,
            -- AXI-Lite Interface for local registers 
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(i),
            axilReadSlave   => axilReadSlaves(i),
            axilWriteMaster => axilWriteMasters(i),
            axilWriteSlave  => axilWriteSlaves(i),
            -- AxiStream output
            axisClk         => axisClk,
            axisRst         => axisRst,
            axisMaster      => axisMasters(i),
            axisSlave       => axisSlaves(i));
   end generate GEN_VEC;

   ---------------------
   -- Fast ADC stream mux
   ---------------------
   U_AxiStreamMux : entity work.AxiStreamMux
      generic map(
         TPD_G         => TPD_G,
         NUM_SLAVES_G  => 8,
         PIPE_STAGES_G => 1)
      port map(
         axisClk      => axisClk,
         axisRst      => axisRst,
         sAxisMasters => axisMasters,
         sAxisSlaves  => axisSlaves,
         mAxisMaster  => axisMaster,
         mAxisSlave   => axisSlave);

end mapping;
