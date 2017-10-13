-------------------------------------------------------------------------------
-- File       : FastAdcBufferChannel.vhd
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

entity FastAdcBufferChannel is
   generic (
      TPD_G             : time                     := 1 ns;
      AXI_ERROR_RESP_G  : slv(1 downto 0)          := AXI_RESP_DECERR_C;
      CHANNEL_G         : slv(7 downto 0)          := x"00";
      PGP_LANE_G        : slv(3 downto 0)          := "0000";
      PGP_VC_G          : slv(3 downto 0)          := "0001"
   );
   port (
      -- ADC Clock Domain
      adcClk            : in  sl;
      adcRst            : in  sl;
      adcData           : in  slv(63 downto 0);
      adcValid          : in  sl;
      gTime             : in  slv(63 downto 0);
      extTrigger        : in  sl := '0';
      -- AXI-Lite Interface for local registers 
      axilClk           : in  sl;
      axilRst           : in  sl;
      axilReadMaster    : in  AxiLiteReadMasterType;
      axilReadSlave     : out AxiLiteReadSlaveType;
      axilWriteMaster   : in  AxiLiteWriteMasterType;
      axilWriteSlave    : out AxiLiteWriteSlaveType;
      -- AxiStream output (axisClk domain)
      axisClk           : in  sl;
      axisRst           : in  sl;
      axisMaster        : out AxiStreamMasterType;
      axisSlave         : in  AxiStreamSlaveType
   );
end FastAdcBufferChannel;

architecture rtl of FastAdcBufferChannel is
   
   constant TRIG_SIZE_BITS_C     : integer := 14;                 -- 14 bits * 1ns ~= 16us max trigger size
   constant FIFO_ADDR_WIDTH_C    : integer := TRIG_SIZE_BITS_C-1; -- "WIDE" side of the FIFO is 4 samples wide
                                                                  -- FIFO size = 2 x max trigger size
   constant ADC_DATA_TIMOEUT_C   : integer := 2500;               -- 10 us at 250MHz
   
   constant SLAVE_AXI_CONFIG_C   : AxiStreamConfigType := ssiAxiStreamConfig(8);
   constant MASTER_AXI_CONFIG_C  : AxiStreamConfigType := ssiAxiStreamConfig(4);
   
   type StateType is (
      IDLE_S,
      HDR_S,
      DATA_S
   );
   
   type TrigType is record
      enable         : sl;
      extTrigger     : sl;
      extTrigSize    : slv(TRIG_SIZE_BITS_C-1 downto 0);  
      gTime          : slv(63 downto 0);
      txMaster       : AxiStreamMasterType;
      wordCnt        : slv(TRIG_SIZE_BITS_C-1 downto 0);
      state          : StateType;
      timeout        : integer;
   end record TrigType;
   
   constant TRIG_INIT_C : TrigType := (
      enable         => '0',
      extTrigger     => '0',
      extTrigSize    => (others => '0'),
      gTime          => (others => '0'),
      txMaster       => AXI_STREAM_MASTER_INIT_C,
      wordCnt        => (others => '0'),
      state          => IDLE_S,
      timeout        => 0
   );
   
   type RegType is record
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
      enable         : sl;
      extTrigSize    : slv(TRIG_SIZE_BITS_C-1 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      enable         => '0',
      extTrigSize    => (others => '0')
   );

   signal trig    : TrigType  := TRIG_INIT_C;
   signal trigIn  : TrigType;
   signal reg     : RegType   := REG_INIT_C;
   signal regIn   : RegType;
   
   signal txSlave : AxiStreamSlaveType;
   
begin

   
   -- register logic (axilClk domain)
   -- trigger and buffer logic (adcClk domian)
   comb : process (adcRst, axilRst, adcData, adcValid, axilReadMaster, axilWriteMaster, txSlave, reg, trig,
      gTime, extTrigger) is
      variable vreg     : RegType;
      variable vtrig    : TrigType;
      variable regCon   : AxiLiteEndPointType;
   begin
      -- Latch the current value
      vreg              := reg;
      vtrig             := trig;
      vtrig.extTrigger  := extTrigger;
      
      ------------------------------------------------
      -- cross domian sync
      ------------------------------------------------
      vtrig.enable         := reg.enable;
      
      
      ------------------------------------------------
      -- register access
      ------------------------------------------------
      
      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, vreg.axilWriteSlave, vreg.axilReadSlave);
      
      -- Map the registers
      axiSlaveRegister (regCon, x"000", 0, vreg.enable);
      axiSlaveRegister (regCon, x"004", 0, vreg.extTrigSize);
      
      -- Closeout the transaction
      axiSlaveDefault(regCon, vreg.axilWriteSlave, vreg.axilReadSlave, AXI_ERROR_RESP_G);
      
      
      -- Reset strobing Signals
      if (txSlave.tReady = '1') then
         vtrig.txMaster.tValid := '0';
         vtrig.txMaster.tLast  := '0';
         vtrig.txMaster.tUser  := (others => '0');
         vtrig.txMaster.tKeep  := (others => '1');
         vtrig.txMaster.tStrb  := (others => '1');
      end if;
      
      ----------------------------------------------------------------------
      -- Data stream state machine
      ----------------------------------------------------------------------
      
      case trig.state is
      
         when IDLE_S =>
            if trig.enable = '1' and trig.extTrigger = '1' then
               vtrig.gTime       := gTime;
               vtrig.extTrigSize := reg.extTrigSize;
               vtrig.wordCnt     := (others => '0');
               vtrig.state       := HDR_S;
            end if;
         
         when HDR_S =>
            if vtrig.txMaster.tValid = '0' then
               vtrig.txMaster.tValid := '1';
               if trig.wordCnt = 0 then
                  ssiSetUserSof(SLAVE_AXI_CONFIG_C, vtrig.txMaster, '1');
                  vtrig.txMaster.tData(31 downto  0) := x"000000" & PGP_LANE_G & PGP_VC_G;      -- PGP lane and VC
                  vtrig.txMaster.tData(63 downto 32) := x"000000" & CHANNEL_G;                  -- Fast ADC channel number
                  vtrig.wordCnt := trig.wordCnt + 1;
               elsif trig.wordCnt = 1 then
                  vtrig.txMaster.tData(31 downto  0) := x"0000" & "00" & trig.extTrigSize;      -- trigger size
                  vtrig.txMaster.tData(63 downto 32) := x"00000000";                            -- trigger offset (not yet implemented)
                  vtrig.wordCnt := trig.wordCnt + 1;
               else
                  vtrig.txMaster.tData(63 downto  0) := trig.gTime(31 downto 0) & trig.gTime(63 downto 32);   -- gTime
                  vtrig.wordCnt := (others => '0');
                  if trig.extTrigSize > 0 then
                     vtrig.timeout := 0;
                     vtrig.state   := DATA_S;
                  else
                     vtrig.txMaster.tLast := '1';
                     vtrig.state   := IDLE_S;
                  end if;
               end if;
            end if;
         
         when DATA_S =>
            
            -- Check if ready to move data
            if vtrig.txMaster.tValid = '0' and adcValid = '1' then
               
               -- reset timeout
               vtrig.timeout := 0;
               
               -- stream valid flag and data
               vtrig.txMaster.tValid := '1';
               vtrig.txMaster.tData(63 downto 0) := adcData;
               
               -- count samples 
               vtrig.wordCnt := trig.wordCnt + 4;
               if trig.wordCnt >= trig.extTrigSize then
                  vtrig.txMaster.tLast := '1';
                  vtrig.state := IDLE_S;
               end if;
               
            else
               -- count until timeout
               vtrig.timeout := trig.timeout + 1;
               if trig.timeout = ADC_DATA_TIMOEUT_C then
                  vtrig.txMaster.tLast := '1';
                  vtrig.txMaster.tValid := '1';
                  vtrig.state := IDLE_S;
                  ssiSetUserEofe(SLAVE_AXI_CONFIG_C, vtrig.txMaster, '1');
               end if;
            end if;
         
         when others =>
            vtrig.state := IDLE_S;
         
      end case;
      
      -- Reset      
      if (adcRst = '1') then
         vtrig := TRIG_INIT_C;
      end if;
      if (axilRst = '1') then
         vreg := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle      
      regIn <= vreg;
      trigIn <= vtrig;

      -- Outputs
      axilWriteSlave <= reg.axilWriteSlave;
      axilReadSlave  <= reg.axilReadSlave;
      
   end process comb;

   seqR : process (axilClk) is
   begin
      if (rising_edge(axilClk)) then
         reg <= regIn after TPD_G;
      end if;
   end process seqR;
   
   seqT : process (adcClk) is
   begin
      if (rising_edge(adcClk)) then
         trig <= trigIn after TPD_G;
      end if;
   end process seqT;
   
   ----------------------------------------------------------------------
   -- Streaming out FIFO
   ----------------------------------------------------------------------
   
   U_AxisOut : entity work.AxiStreamFifoV2
   generic map (
      -- General Configurations
      TPD_G               => TPD_G,
      PIPE_STAGES_G       => 1,
      SLAVE_READY_EN_G    => true,
      VALID_THOLD_G       => 1,     -- =0 = only when frame ready
      -- FIFO configurations
      BRAM_EN_G           => true,
      USE_BUILT_IN_G      => false,
      GEN_SYNC_FIFO_G     => false,
      CASCADE_SIZE_G      => 1,
      FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_C,
      FIFO_FIXED_THRESH_G => true,
      FIFO_PAUSE_THRESH_G => 128,
      -- Internal FIFO width select, "WIDE", "NARROW" or "CUSTOM"
      -- WIDE uses wider of slave / master. NARROW  uses narrower.
      INT_WIDTH_SELECT_G  => "WIDE", 
      -- AXI Stream Port Configurations
      SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_C,
      MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_C
   )
   port map (
      -- Slave Port
      sAxisClk    => adcClk,
      sAxisRst    => adcRst,
      sAxisMaster => trig.txMaster,
      sAxisSlave  => txSlave,
      -- Master Port
      mAxisClk    => axisClk,
      mAxisRst    => axisRst,
      mAxisMaster => axisMaster,
      mAxisSlave  => axisSlave
   );
   
   

end rtl;
