----------------------------------------------------------------------------------
-- Copyright (C) 2015, 2018 SN
--
-- Redistribution and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
-- this list of conditions and the following disclaimer in the documentation and/or
-- other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its contributors
-- may be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
-- IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
-- BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
-- DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
-- LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
-- OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
-- OF THE POSSIBILITY OF SUCH DAMAGE.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity S64v4_TB is
end S64v4_TB;

architecture ArcS64v4_TB of S64v4_TB is

component S64v4 is
  generic (
    CPUBits : Natural := 8);
  port (
    Res : in STD_LOGIC;
    CE : in STD_LOGIC;
    Clk : in STD_LOGIC;
    Data : inout STD_LOGIC_VECTOR ((CPUBits - 1) downto 0);
    Addres : out STD_LOGIC_VECTOR ((CPUBits - 1) downto 0);
    IRE : out STD_LOGIC; -- Чтение из памяти (только код).
    DRE : out STD_LOGIC; -- Чтение из памяти (только данные).
    DWE : out STD_LOGIC); -- Запись в память (только данные).
end component;

-- Clock period definitions
constant BaseTimeStep : time := 10 ns;

-- Constants
constant CPUBits_TB : Natural := 8;

-- Inputs and BiDirs of UUT
signal Res : STD_LOGIC := '0';
signal CE : STD_LOGIC := '0';
signal Clk : STD_LOGIC;
signal Data : STD_LOGIC_VECTOR ((CPUBits_TB - 1) downto 0) := (others => 'Z');

-- Outputs of UUT
signal Addres : STD_LOGIC_VECTOR ((CPUBits_TB - 1) downto 0);
signal IRE : STD_LOGIC;
signal DRE : STD_LOGIC;
signal DWE : STD_LOGIC;

-- Auxiliary signals, etc.
signal Clk_Orig : STD_LOGIC := '0';
signal Clk_Gate : STD_LOGIC := '0';

begin

  -- Instantiate the Unit Under Test (UUT)
  UUT: S64v4
    generic map (
      CPUBits => CPUBits_TB)
    port map (
      Res => Res,
      CE => CE,
      Clk => Clk,
      Data => Data,
      Addres => Addres,
      IRE => IRE,
      DRE => DRE,
      DWE => DWE);

  -- Program & Data ROM
  Data <= "00000000" when (Addres = x"00") and ((IRE = '1') or (DRE = '1')) else -- JCC PC + 00 ----> Jump to 0x01 memory location
          "10100000" when (Addres = x"01") and ((IRE = '1') or (DRE = '1')) else -- LDA A, #00  ----> Acc = 0x00
          "01001111" when (Addres = x"02") and ((IRE = '1') or (DRE = '1')) else -- STA #0F, A
          "01111111" when (Addres = x"03") and ((IRE = '1') or (DRE = '1')) else -- STA #3F, A
          "11000011" when (Addres = x"04") and ((IRE = '1') or (DRE = '1')) else -- ADD A, #03  ----> Acc = 0x7F, Carry = 0
          "11100011" when (Addres = x"05") and ((IRE = '1') or (DRE = '1')) else -- SUB A, #03  ----> Acc = 0x00, Carry = 0
          "10000000" when (Addres = x"06") and ((IRE = '1') or (DRE = '1')) else -- NOR A, #00  ----> Acc = 0xFF
          "10100000" when (Addres = x"07") and ((IRE = '1') or (DRE = '1')) else -- LDA A, #00  ----> Acc = 0x00
          "11100011" when (Addres = x"08") and ((IRE = '1') or (DRE = '1')) else -- SUB A, #03  ----> Acc = 0x81, Carry = 1
          "00110110" when (Addres = x"09") and ((IRE = '1') or (DRE = '1')) else -- JCC PC - 0A ----> No Jump
          "00000000" when (Addres = x"0A") and ((IRE = '1') or (DRE = '1')) else -- JCC PC + 00 ----> No Jump
          "11001110" when (Addres = x"0B") and ((IRE = '1') or (DRE = '1')) else -- ADD A, #0E  ----> Acc = 0x80, Carry = 1
          "11000000" when (Addres = x"0C") and ((IRE = '1') or (DRE = '1')) else -- ADD A, #00  ----> Acc = 0x80, Carry = 0
          "00110010" when (Addres = x"0D") and ((IRE = '1') or (DRE = '1')) else -- JCC PC - 0E ----> Jump to 0x00 memory location
          "11111111" when (Addres = x"0E") and ((IRE = '1') or (DRE = '1')) else -- Just a data
          (others => 'Z');

  -- Clock process definitions
  Clk_Orig_process : process
    begin
      Clk_Orig <= '0';
      wait for BaseTimeStep;
      Clk_Orig <= '1';
      wait for BaseTimeStep;
    end process;

  Clk_Gate_process : process
    begin
      Clk_Gate <= '0';
      wait for BaseTimeStep * 8;
      Clk_Gate <= '1';
      wait; -- will wait forever
    end process;

  Clk <= Clk_Orig and Clk_Gate;

  -- Stimulus process
  Stim_process : process
    begin

      wait for BaseTimeStep * 4;
      Res <= '1'; -- Appling Reset.

      wait for BaseTimeStep * 2;
      Res <= '0'; -- Releasing Reset.

      wait for BaseTimeStep * 4;
      CE <= '1'; -- Enabling Clock.




      wait for BaseTimeStep * 8;



      wait; -- will wait forever

  end process;

end;
