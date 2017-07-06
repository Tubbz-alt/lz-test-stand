-------------------------------------------------------------------------------
-- File       : DdrMemTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-07-05
-- Last update: 2017-07-06
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the MigCoreWrapper module
-------------------------------------------------------------------------------
-- This file is part of 'LZ Test stand'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LZ Test stand', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity DdrMemTb is end DdrMemTb;

architecture testbed of DdrMemTb is

   constant CLK_PERIOD_C  : time    := 5 ns;
   constant TPD_C         : time    := CLK_PERIOD_C/4;
   constant DLY_C         : natural := 16;
   constant SIM_SPEEDUP_C : boolean := true;

   constant AXI_CONFIG_C : AxiConfigType := (
      ADDR_WIDTH_C => 31,
      DATA_BYTES_C => 64,
      ID_BITS_C    => 4,
      LEN_BITS_C   => 8);

   constant START_ADDR_C : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '0');
   constant STOP_ADDR_C  : slv(AXI_CONFIG_C.ADDR_WIDTH_C-1 downto 0) := (others => '1');

   component Ddr4ModelWrapper
      port (
         c0_ddr4_dq       : inout slv(63 downto 0);
         c0_ddr4_dqs_c    : inout slv(7 downto 0);
         c0_ddr4_dqs_t    : inout slv(7 downto 0);
         c0_ddr4_adr      : in    slv(16 downto 0);
         c0_ddr4_ba       : in    slv(1 downto 0);
         c0_ddr4_bg       : in    slv(0 to 0);
         c0_ddr4_reset_n  : in    sl;
         c0_ddr4_act_n    : in    sl;
         c0_ddr4_ck_t     : in    slv(0 to 0);
         c0_ddr4_ck_c     : in    slv(0 to 0);
         c0_ddr4_cke      : in    slv(0 to 0);
         c0_ddr4_cs_n     : in    slv(0 to 0);
         c0_ddr4_dm_dbi_n : inout slv(7 downto 0);
         c0_ddr4_odt      : in    slv(0 to 0));
   end component;

   signal clk       : sl                    := '0';
   signal rst       : sl                    := '0';
   signal rstL      : sl                    := '1';
   signal passed    : sl                    := '0';
   signal failed    : sl                    := '0';
   signal passedDly : slv(DLY_C-1 downto 0) := (others => '0');
   signal failedDly : slv(DLY_C-1 downto 0) := (others => '0');

   signal ddrClkP : sl := '0';
   signal ddrClkN : sl := '0';

   signal c0_ddr4_dq       : slv(63 downto 0) := (others => '0');
   signal c0_ddr4_dqs_c    : slv(7 downto 0)  := (others => '0');
   signal c0_ddr4_dqs_t    : slv(7 downto 0)  := (others => '0');
   signal c0_ddr4_adr      : slv(16 downto 0) := (others => '0');
   signal c0_ddr4_ba       : slv(1 downto 0)  := (others => '0');
   signal c0_ddr4_bg       : slv(0 to 0)      := (others => '0');
   signal c0_ddr4_reset_n  : sl               := '0';
   signal c0_ddr4_act_n    : sl               := '0';
   signal c0_ddr4_ck_t     : slv(0 to 0)      := (others => '0');
   signal c0_ddr4_ck_c     : slv(0 to 0)      := (others => '0');
   signal c0_ddr4_cke      : slv(0 to 0)      := (others => '0');
   signal c0_ddr4_cs_n     : slv(0 to 0)      := (others => '0');
   signal c0_ddr4_dm_dbi_n : slv(7 downto 0)  := (others => '0');
   signal c0_ddr4_odt      : slv(0 to 0)      := (others => '0');

   signal axiClk         : sl := '0';
   signal axiRst         : sl := '0';
   signal axiReadMaster  : AxiReadMasterType;
   signal axiReadSlave   : AxiReadSlaveType;
   signal axiWriteMaster : AxiWriteMasterType;
   signal axiWriteSlave  : AxiWriteSlaveType;
   signal ddrCalDone     : sl := '0';

begin

   -- Generate clocks and resets
   ClkRst_Inst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,  -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 1 us)     -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => rstL);

   OBUFDS_Inst : OBUFDS
      port map (
         I  => clk,
         O  => ddrClkP,
         Ob => ddrClkN);

   U_AxiMemTester : entity work.AxiMemTester
      generic map (
         TPD_G        => TPD_C,
         START_ADDR_G => START_ADDR_C,
         STOP_ADDR_G  => ite(SIM_SPEEDUP_C, toSlv(32*4096, AXI_CONFIG_C.ADDR_WIDTH_C), STOP_ADDR_C),
         AXI_CONFIG_G => AXI_CONFIG_C)
      port map (
         -- AXI-Lite Interface
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open,
         memReady        => passed,
         memError        => failed,
         -- DDR Memory Interface
         axiClk          => axiClk,
         axiRst          => axiRst,
         start           => ddrCalDone,
         axiWriteMaster  => axiWriteMaster,
         axiWriteSlave   => axiWriteSlave,
         axiReadMaster   => axiReadMaster,
         axiReadSlave    => axiReadSlave);

   ------------------------
   -- DDR memory controller
   ------------------------
   U_DDR : entity work.MigCoreWrapper
      generic map (
         TPD_G => TPD_C)
      port map (
         -- AXI Slave
         axiClk           => axiClk,
         axiRst           => axiRst,
         axiReadMaster    => axiReadMaster,
         axiReadSlave     => axiReadSlave,
         axiWriteMaster   => axiWriteMaster,
         axiWriteSlave    => axiWriteSlave,
         -- DDR PHY Ref clk
         c0_sys_clk_p     => ddrClkP,
         c0_sys_clk_n     => ddrClkN,
         -- DRR Memory interface ports
         sys_rst          => rst,
         c0_ddr4_aresetn  => rstL,
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
         calibComplete    => ddrCalDone);

   U_ddr4 : Ddr4ModelWrapper
      port map (
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
         c0_ddr4_ck_t     => c0_ddr4_ck_t);

   process(clk)
      variable i : natural;
   begin
      if rising_edge(clk) then
         -- Check for reset
         if rst = '1' then
            passedDly <= (others => '0') after TPD_C;
            failedDly <= (others => '0') after TPD_C;
         else
            passedDly(0) <= passed after TPD_C;
            failedDly(0) <= failed after TPD_C;
            for i in DLY_C-2 downto 0 loop
               passedDly(i+1) <= passedDly(i) after TPD_C;
               failedDly(i+1) <= failedDly(i) after TPD_C;
            end loop;
         end if;
      end if;
   end process;

   process(failedDly, passedDly)
   begin
      if failedDly(DLY_C-1) = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
      if passedDly(DLY_C-1) = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      end if;
   end process;

end testbed;
