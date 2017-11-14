-------------------------------------------------------------------------------
-- File       : LztsSynchronizer.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-11-13
-- Last update: 2017-11-13
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

library unisim;
use unisim.vcomponents.all;

entity LztsSynchronizer is
   generic (
      TPD_G             : time            := 1 ns;
      SIM_SPEEDUP_G     : boolean         := false;
      AXI_ERROR_RESP_G  : slv(1 downto 0) := AXI_RESP_DECERR_C
   );
   port (
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- local clock input/output
      locClk            : in  sl;
      -- Master command inputs (synchronous to clkOut)
      syncCmd           : in  sl;
      rstCmd            : in  sl;
      -- Inter-board clock and command
      clkInP            : in  sl;
      clkInN            : in  sl;
      clkOutP           : out sl;
      clkOutN           : out sl;
      cmdInP            : in  sl;
      cmdInN            : in  sl;
      cmdOutP           : out sl;
      cmdOutN           : out sl;
      -- globally synchronized outputs
      clkOut            : out sl;
      rstOut            : out sl;
      gTime             : out slv(63 downto 0);
      -- status LEDs
      clkLed            : out sl;
      cmdLed            : out sl;
      mstLed            : out sl
   );
end LztsSynchronizer;

architecture rtl of LztsSynchronizer is
   
   
   constant MAX_CLK_PULSES_C : integer := ite(SIM_SPEEDUP_G, 40, 2**16-1);
   constant MAX_CLK_ERROR_C  : integer := integer(MAX_CLK_PULSES_C * 0.05);
   constant LED_TIME_C       : integer := ite(SIM_SPEEDUP_G, 100, 250000000);
   
   type MuxType is record
      gTime          : slv(63 downto 0);
      serIn          : slv(7 downto 0);
      serOut         : slv(7 downto 0);
      cmdOut         : sl;
      extClkDet      : sl;
      syncCmd        : sl;
      syncCmdCnt     : slv(15 downto 0);
      syncDet        : sl;
      syncDetDly     : slv(1 downto 0);
      syncPending    : sl;
      rstCmd         : sl;
      rstCmdCnt      : slv(15 downto 0);
      rstDet         : sl;
      rstDetDly      : slv(1 downto 0);
      rstPending     : sl;
      cmdBits        : integer range 0 to 7;
      clkLedCnt      : integer range 0 to LED_TIME_C;
      cmdLedCnt      : integer range 0 to LED_TIME_C;
      clkLed         : sl;
      cmdLed         : sl;
   end record MuxType;
   
   constant MUX_INIT_C : MuxType := (
      gTime          => (others=>'0'),
      serIn          => (others=>'0'),
      serOut         => "01010101",
      cmdOut         => '0',
      extClkDet      => '0',
      syncCmd        => '0',
      syncCmdCnt     => (others=>'0'),
      syncDet        => '0',
      syncDetDly     => "00",
      syncPending    => '0',
      rstCmd         => '0',
      rstCmdCnt      => (others=>'0'),
      rstDet         => '0',
      rstDetDly      => "00",
      rstPending     => '0',
      cmdBits        => 0,
      clkLedCnt      => 0,
      cmdLedCnt      => 0,
      clkLed         => '0',
      cmdLed         => '0'
   );
   
   type ExtType is record
      extCount       : integer range 0 to MAX_CLK_PULSES_C;
      extReset       : sl;
   end record ExtType;
   
   constant EXT_INIT_C : ExtType := (
      extCount       => 0,
      extReset       => '0'
   );
   
   type LocType is record
      locCount       : integer range 0 to MAX_CLK_PULSES_C;
      extCount       : integer range 0 to MAX_CLK_PULSES_C;
      extReset       : slv(7 downto 0);
      extCountZero   : sl;
      extClkDet      : sl;
   end record LocType;
   
   constant LOC_INIT_C : LocType := (
      locCount       => 0,
      extCount       => 0,
      extReset       => (others=>'0'),
      extCountZero   => '0',
      extClkDet      => '0'
   );
   
   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      extClkDet      : sl;
      gTime          : slv(63 downto 0);
      syncCmdCnt     : slv(15 downto 0);
      rstCmdCnt      : slv(15 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      extClkDet      => '0',
      gTime          => (others=>'0'),
      syncCmdCnt     => (others=>'0'),
      rstCmdCnt      => (others=>'0')
   );
   
   signal mux     : MuxType   := MUX_INIT_C;
   signal muxIn   : MuxType;
   signal ext     : ExtType   := EXT_INIT_C;
   signal extIn   : ExtType;
   signal loc     : LocType   := LOC_INIT_C;
   signal locIn   : LocType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal clkInBuf         : sl;
   signal clkIn            : sl;
   signal cmdIn            : sl;
   signal cmdOutBuf        : sl;
   signal muxClk           : sl;
   
begin
   
   U_IBUFGDS_1 : IBUFGDS
   port map (
      I  => clkInP,
      IB => clkInN,
      O  => clkInBuf
   );
   
   U_BUFG_1 : BUFG
   port map (
      I => clkInBuf,
      O => clkIn
   );
   
   U_BUFGMUX_1 : BUFGMUX
   port map (
      O  => muxClk,
      I0 => locClk,
      I1 => clkInBuf,
      S  => loc.extClkDet
   );
   
   clkOut <= muxClk;
   
   U_IBUFDS_1 : IBUFDS
   port map (
      I  => cmdInP,
      IB => cmdInN,
      O  => cmdIn
   );
   
   U_ClkOutBufDiff_1 : entity work.ClkOutBufDiff
   generic map (
      XIL_DEVICE_G => "ULTRASCALE")
   port map (
      clkIn   => muxClk,
      clkOutP => clkOutP,
      clkOutN => clkOutN
   );
   
   -- register logic (axilClk domain)
   -- remote clock detect (locClk domain)
   -- remote clock counter (clkIn domain)
   -- patern serdes logic (muxClk domain)
   comb : process (axilRst, axilReadMaster, axilWriteMaster, reg, loc, ext, mux, cmdIn, syncCmd, rstCmd) is
      variable vreg        : RegType := REG_INIT_C;
      variable vloc        : LocType := LOC_INIT_C;
      variable vext        : ExtType := EXT_INIT_C;
      variable vmux        : MuxType := MUX_INIT_C;
      variable regCon      : AxiLiteEndPointType;
   begin
      -- Latch the current value
      vreg := reg;
      vloc := loc;
      vext := ext;
      vmux := mux;
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vloc.extCount   := ext.extCount;
      vext.extReset   := loc.extReset(7);
      vreg.extClkDet  := loc.extClkDet;
      vreg.gTime      := mux.gTime;
      vreg.syncCmdCnt := mux.syncCmdCnt;
      vreg.rstCmdCnt  := mux.rstCmdCnt;
      vmux.extClkDet  := loc.extClkDet;
      
      ------------------------------------------------
      -- register access (axilClk domain)
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      axiSlaveRegisterR(regCon, x"000", 0, reg.extClkDet);
      axiSlaveRegisterR(regCon, x"004", 0, reg.gTime(31 downto 0));
      axiSlaveRegisterR(regCon, x"008", 0, reg.gTime(63 downto 32));
      axiSlaveRegisterR(regCon, x"00C", 0, reg.rstCmdCnt);
      axiSlaveRegisterR(regCon, x"010", 0, reg.syncCmdCnt);
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      ------------------------------------------------
      -- Remote clock counter (clkIn domain)
      ------------------------------------------------
      
      if ext.extReset = '1' then
         vext.extCount := 0;
      elsif ext.extCount < MAX_CLK_PULSES_C then
         vext.extCount := ext.extCount + 1;
      end if;
      
      ------------------------------------------------
      -- Remote clock detect (locClk domain)
      ------------------------------------------------
      
      if loc.extReset(7) = '1' then
         vloc.extReset := loc.extReset(6 downto 0) & '0';
         if loc.extCount = 0 then
            vloc.extCountZero := '1';
         else
            vloc.extCountZero := '0';
         end if;
      elsif loc.locCount = MAX_CLK_PULSES_C then
         vloc.locCount := 0;
         vloc.extReset := x"FF";
         -- verify extCount both 0 and max value
         if loc.extCount >= (MAX_CLK_PULSES_C-MAX_CLK_ERROR_C) and loc.extCountZero = '1' then
            vloc.extClkDet := '1';
         else
            vloc.extClkDet := '0';
         end if;
      else
         vloc.locCount := loc.locCount + 1;
      end if;
      
      ------------------------------------------------
      -- Serial pattern in/out logic (muxClk domain)
      ------------------------------------------------
      
      -- clear strobes
      vmux.syncDet := '0';
      vmux.rstDet  := '0';
      vmux.syncDetDly(0) := '0';
      vmux.syncDetDly(1) := mux.syncDetDly(0);
      vmux.rstDetDly(0)  := '0';
      vmux.rstDetDly(1)  := mux.rstDetDly(0);
      
      ------------------------------------------------
      -- slave logic
      ------------------------------------------------
      
      if mux.extClkDet = '1' then
         -- repeat cmdIn
         vmux.cmdOut := cmdIn;
         -- decode cmdIn and look for reser/sync
         vmux.serIn  := mux.serIn(6 downto 0) & cmdIn;
         if mux.serIn = "00001111" then
            vmux.syncDet := '1';
         elsif mux.serIn = "00110011" then
            vmux.rstDet := '1';
         end if;
         -- reset unused logic
         vmux.cmdBits := 0;
         vmux.serOut  := "01010101";
      end if;
      
      ------------------------------------------------
      -- master logic
      ------------------------------------------------
      
      if mux.extClkDet = '0' then
         -- clear unused de-serializer
         vmux.serIn  := (others=>'0');
         -- look for master commands
         if rstCmd = '1' then
            vmux.rstCmd := '1';
         elsif syncCmd = '1' then
            vmux.syncCmd := '1';
         end if;
         -- generate patterns
         if mux.cmdBits = 0 then
            vmux.cmdBits := 7;
            -- register commands or idle once every 8 cycles
            if mux.rstCmd = '1' then
               vmux.rstPending := '1';
               vmux.rstCmd  := '0';
               vmux.serOut  := "00110011";
            elsif mux.syncCmd = '1' then
               vmux.syncPending := '1';
               vmux.syncCmd := '0';
               vmux.serOut  := "00001111";
            else
               vmux.serOut  := "01010101";
            end if;
         else
            vmux.cmdBits := mux.cmdBits - 1;
            vmux.serOut  := mux.serOut(6 downto 0) & mux.serOut(7);
         end if;
         
         -- execute command locally after they are serialized to slaves
         if mux.cmdBits = 0 then
            if mux.rstPending = '1' then
               vmux.rstDetDly(0) := '1';
               vmux.rstPending   := '0';
            elsif mux.syncPending = '1' then
               vmux.syncDetDly(0) := '1';
               vmux.syncPending   := '0';
            end if;
         end if;
         -- delay local command detect in master
         vmux.rstDet  := mux.rstDetDly(1);
         vmux.syncDet := mux.syncDetDly(1);
         -- register serial output
         vmux.cmdOut := mux.serOut(7);
      end if;
      
      ------------------------------------------------
      -- master/slave common logic
      ------------------------------------------------
      
      -- synchronous global timer
      if mux.syncDet = '1' or mux.rstDet = '1' then
         vmux.gTime := (others=>'0');
      else
         vmux.gTime := mux.gTime + 1;
      end if;
      
      -- command counters
      if mux.syncDet = '1' then
         vmux.syncCmdCnt := mux.syncCmdCnt + 1;
      end if;
      if mux.rstDet = '1' then
         vmux.rstCmdCnt := mux.rstCmdCnt + 1;
      end if;
      
      -- LED timers
      if mux.syncDet = '1' or mux.rstDet = '1'  then
         vmux.clkLedCnt := 0;
         vmux.clkLed    := '1';
      elsif mux.clkLedCnt >= LED_TIME_C then
         vmux.clkLedCnt := 0;
         vmux.clkLed    := not mux.clkLed;
      else
         vmux.clkLedCnt := mux.clkLedCnt + 1;
      end if;
      
      if mux.syncDet = '1' or mux.rstDet = '1' then
         vmux.cmdLedCnt := LED_TIME_C;
         vmux.cmdLed    := '1';
      elsif mux.cmdLedCnt > 0 then
         vmux.cmdLedCnt := mux.cmdLedCnt - 1;
      else
         vmux.cmdLed := '0';
      end if;
      
      ------------------------------------------------
      -- Reset
      ------------------------------------------------
      
      if (axilRst = '1') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn <= vreg;
      locIn <= vloc;
      extIn <= vext;
      muxIn <= vmux;

      -- Outputs
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      gTime          <= mux.gTime;
      rstOut         <= mux.rstDet;
      clkLed         <= mux.clkLed;
      cmdLed         <= mux.cmdLed;
      mstLed         <= not mux.extClkDet;
   end process comb;

   seqR : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seqR;
   
   seqL : process (locClk) is
   begin
      if (rising_edge(locClk)) then
         loc <= locIn after TPD_G;
      end if;
   end process seqL;
   
   seqE : process (clkIn) is
   begin
      if (rising_edge(clkIn)) then
         ext <= extIn after TPD_G;
      end if;
   end process seqE;
   
   seqM : process (muxClk) is
   begin
      if (rising_edge(muxClk)) then
         mux <= muxIn after TPD_G;
      end if;
   end process seqM;
   
   -- clock out command on falling edge
   seqCmd : process (muxClk) is
   begin
      if (falling_edge(muxClk)) then
         cmdOutBuf <= mux.cmdOut after TPD_G;
      end if;
   end process seqCmd;
   
   U_OBUFDS_1 : OBUFDS
   port map (
      I  => cmdOutBuf,
      OB => cmdOutN,
      O  => cmdOutP
   );

end rtl;
