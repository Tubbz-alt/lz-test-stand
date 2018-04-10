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
      SIM_SPEEDUP_G     : boolean         := false);
   port (
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- PLL clock input
      pllClk            : in  sl;
      -- local oscillator clock input
      locClk            : in  sl;
      -- Master command inputs (synchronous to pllClk)
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
      muxClk            : out sl;
      rstOut            : out sl;
      gTime             : out slv(63 downto 0);
      -- status LEDs
      clkLed            : out sl;
      cmdLed            : out sl;
      mstLed            : out sl
   );
end LztsSynchronizer;

architecture rtl of LztsSynchronizer is
   
   constant LED_TIME_C       : integer := ite(SIM_SPEEDUP_G, 100, 250000000);
   
   type MuxType is record
      gTime          : slv(63 downto 0);
      serIn          : slv(7 downto 0);
      serOut         : slv(7 downto 0);
      cmdOut         : sl;
      slaveDev       : sl;
      syncCmdReg     : slv(2 downto 0);
      syncCmd        : sl;
      syncCmdCnt     : slv(15 downto 0);
      syncDet        : sl;
      syncDetDly     : slv(2 downto 0);
      syncPending    : sl;
      rstCmdReg      : slv(2 downto 0);
      rstCmd         : sl;
      rstCmdCnt      : slv(15 downto 0);
      rstDet         : sl;
      rstDetDly      : slv(2 downto 0);
      rstPending     : sl;
      cmdBits        : integer range 0 to 7;
      clkLedCnt      : integer range 0 to LED_TIME_C;
      cmdLedCnt      : integer range 0 to LED_TIME_C;
      clkLed         : sl;
      cmdLed         : sl;
      badIdleCnt     : slv(15 downto 0);
   end record MuxType;
   
   constant MUX_INIT_C : MuxType := (
      gTime          => (others=>'0'),
      serIn          => (others=>'0'),
      serOut         => "01010101",
      cmdOut         => '0',
      slaveDev       => '0',
      syncCmdReg     => (others=>'0'),
      syncCmd        => '0',
      syncCmdCnt     => (others=>'0'),
      syncDet        => '0',
      syncDetDly     => "000",
      syncPending    => '0',
      rstCmdReg      => (others=>'0'),
      rstCmd         => '0',
      rstCmdCnt      => (others=>'0'),
      rstDet         => '0',
      rstDetDly      => "000",
      rstPending     => '0',
      cmdBits        => 0,
      clkLedCnt      => 0,
      cmdLedCnt      => 0,
      clkLed         => '0',
      cmdLed         => '0',
      badIdleCnt     => (others=>'0')
   );
   
   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      slaveDev       : sl;
      gTime          : slv(63 downto 0);
      syncCmdCnt     : slv(15 downto 0);
      rstCmdCnt      : slv(15 downto 0);
      badIdleCnt     : slv(15 downto 0);
      rstCmd         : sl;
      syncCmd        : sl;
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      slaveDev       => '0',
      gTime          => (others=>'0'),
      syncCmdCnt     => (others=>'0'),
      rstCmdCnt      => (others=>'0'),
      badIdleCnt     => (others=>'0'),
      rstCmd         => '0',
      syncCmd        => '0'
   );
   
   signal mux     : MuxType   := MUX_INIT_C;
   signal muxIn   : MuxType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal clkInBuf         : sl;
   signal cmdIn            : sl;
   signal cmdInBuf         : sl;
   signal cmdOutBuf        : sl;
   signal pllClkB          : sl;
   
   attribute keep : string;                        -- for chipscope
   attribute keep of mux    : signal is "true";    -- for chipscope
   
begin
   
   U_IBUFGDS_1 : IBUFGDS
   port map (
      I  => clkInP,
      IB => clkInN,
      O  => clkInBuf
   );
   
   U_BUFGMUX_1 : BUFGMUX
   port map (
      O  => muxClk,
      I0 => locClk,
      I1 => clkInBuf,
      S  => reg.slaveDev
   );
   
   
   U_IBUFDS_1 : IBUFDS
   port map (
      I  => cmdInP,
      IB => cmdInN,
      O  => cmdInBuf
   );
   
   U_IDDRE_1 : IDDRE1
   port map (
      C  => pllClk,
      CB => pllClkB,
      R  => '0',
      D  => cmdInBuf,
      Q1 => cmdIn,
      Q2 => open
   );
   pllClkB <= not pllClk;   
   
   U_ClkOutBufDiff_1 : entity work.ClkOutBufDiff
   generic map (
      XIL_DEVICE_G => "ULTRASCALE")
   port map (
      clkIn   => pllClk,
      clkOutP => clkOutP,
      clkOutN => clkOutN
   );
   
   -- register logic (axilClk domain)
   -- patern serdes logic (pllClk domain)
   comb : process (axilRst, axilReadMaster, axilWriteMaster, reg, mux, cmdIn, syncCmd, rstCmd) is
      variable vreg        : RegType := REG_INIT_C;
      variable vmux        : MuxType := MUX_INIT_C;
      variable regCon      : AxiLiteEndPointType;
   begin
      -- Latch the current value
      vreg := reg;
      vmux := mux;
      
      vreg.rstCmd    := '0';
      vreg.syncCmd   := '0';
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vreg.gTime           := mux.gTime;
      vreg.syncCmdCnt      := mux.syncCmdCnt;
      vreg.rstCmdCnt       := mux.rstCmdCnt;
      vreg.badIdleCnt      := mux.badIdleCnt;
      vmux.slaveDev        := reg.slaveDev;
      vmux.rstCmdReg(0)    := reg.rstCmd;
      vmux.rstCmdReg(1)    := mux.rstCmdReg(0);
      vmux.rstCmdReg(2)    := mux.rstCmdReg(1);
      vmux.syncCmdReg(0)   := reg.syncCmd;
      vmux.syncCmdReg(1)   := mux.syncCmdReg(0);
      vmux.syncCmdReg(2)   := mux.syncCmdReg(1);
      
      ------------------------------------------------
      -- register access (axilClk domain)
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      axiSlaveRegister (regCon, x"000", 0, vreg.slaveDev);
      axiSlaveRegisterR(regCon, x"004", 0, reg.gTime(31 downto 0));
      axiSlaveRegisterR(regCon, x"008", 0, reg.gTime(63 downto 32));
      axiSlaveRegisterR(regCon, x"00C", 0, reg.rstCmdCnt);
      axiSlaveRegisterR(regCon, x"010", 0, reg.syncCmdCnt);
      axiSlaveRegisterR(regCon, x"014", 0, reg.badIdleCnt);
      
      -- optional register based commands
      axiSlaveRegister (regCon, x"100", 0, vreg.rstCmd);
      axiSlaveRegister (regCon, x"104", 0, vreg.syncCmd);
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_RESP_DECERR_C);
      
      ------------------------------------------------
      -- Serial pattern in/out logic (pllClk domain)
      ------------------------------------------------
      
      -- clear strobes
      vmux.syncDet := '0';
      vmux.rstDet  := '0';
      vmux.syncDetDly(0) := '0';
      vmux.syncDetDly(1) := mux.syncDetDly(0);
      vmux.syncDetDly(2) := mux.syncDetDly(1);
      vmux.rstDetDly(0)  := '0';
      vmux.rstDetDly(1)  := mux.rstDetDly(0);
      vmux.rstDetDly(2)  := mux.rstDetDly(1);
      
      ------------------------------------------------
      -- slave logic
      ------------------------------------------------
      
      if mux.slaveDev = '1' then
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
      
      if mux.slaveDev = '0' then
         -- clear unused de-serializer
         vmux.serIn  := (others=>'0');
         -- look for master commands
         if rstCmd = '1' or (mux.rstCmdReg(1) = '1' and mux.rstCmdReg(2) = '0') then
            vmux.rstCmd := '1';
         elsif syncCmd = '1' or (mux.syncCmdReg(1) = '1' and mux.syncCmdReg(2) = '0') then
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
         vmux.rstDet  := mux.rstDetDly(2);
         vmux.syncDet := mux.syncDetDly(2);
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
      
      -- bad idle counter
      if mux.syncDet = '1' or mux.rstDet = '1' then
         vmux.badIdleCnt  := (others=>'0');
      elsif mux.slaveDev = '1' then
         if mux.serIn(0) = mux.serIn(1) and mux.badIdleCnt /= 2**mux.badIdleCnt'length-1 then
            vmux.badIdleCnt  := vmux.badIdleCnt + 1;
         end if;
      else
         if mux.serOut(0) = mux.serOut(1) and mux.badIdleCnt /= 2**mux.badIdleCnt'length-1 then
            vmux.badIdleCnt  := vmux.badIdleCnt + 1;
         end if;
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
      muxIn <= vmux;

      -- Outputs
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      gTime          <= mux.gTime;
      rstOut         <= mux.rstDet;
      clkLed         <= mux.clkLed;
      cmdLed         <= mux.cmdLed;
      mstLed         <= not mux.slaveDev;
   end process comb;

   seqR : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seqR;
   
   seqM : process (pllClk) is
   begin
      if (rising_edge(pllClk)) then
         mux <= muxIn after TPD_G;
      end if;
   end process seqM;
   
   -- clock out command on falling edge
   U_ODDRE_1 : ODDRE1
   generic map (
      IS_C_INVERTED  => '1'
   )
   port map (
      C  => pllClk,
      SR => '0',
      D1 => mux.cmdOut,
      D2 => mux.cmdOut,
      Q  => cmdOutBuf
   );
   
   
   U_OBUFDS_1 : OBUFDS
   port map (
      I  => cmdOutBuf,
      OB => cmdOutN,
      O  => cmdOutP
   );

end rtl;
