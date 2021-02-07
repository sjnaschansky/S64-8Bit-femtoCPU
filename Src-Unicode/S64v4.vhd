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
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

-- Простейший микропроцессор, предназначенный для размещения в CLPD на 64 макроячейки.
-- По сравнению с S64v2 на один бит расширено поле смещения в команде JCC, и на 1 бит расширено поле адреса в команде STA.
-- Т.е. неиспользуемых битов в кодах команд более нет.
-- На будущее можно было бы добавить один теневой регистр, биты которого расширяли бы 5-битный адрес,
-- позволяя получать доступ к данным расположенным во всём адресном пространстве.
-- Запись в этот регистр можно производить командой STA, задавая адрес в диапазоне 32 ... 63.
-- 01.07.2015

-- По сравнению с S64v3 добавлен 1 сигнал, теперь для чтения инструкций и данных вырабатываются 2 независимых сигнала,
-- таким образом, появляется возможность разделить адресное пространство команд и данных.
-- Названия состояний конечного автомата немного изменены.
-- 09.02.2018

-- Коды команд:
-- 00xxxxxx - JCC: переход, если перенос сброшен (смещение 6 бит со знаком),
-- 01xxxxxx - STA: запись аккумулятора в память (адрес - 6 бит),
-- 100xxxxx - NOR: Acc := Acc NOR Mem (адрес - 5 бит),
-- 101xxxxx - LDA: Acc := Mem (адрес - 5 бит),
-- 110xxxxx - ADD: Acc := Acc + Mem, флаг переноса обновляется (адрес - 5 бит),
-- 111xxxxx - SUB: Acc := Acc - Mem, флаг переноса обновляется (адрес - 5 бит).

entity S64v4 is
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
end S64v4;

architecture Arc_S64v4 of S64v4 is

-- Сигналы разрешения тактирования.
signal CE0, CECPU : STD_LOGIC;

-- Перечень состояний конечного автомата процессора.
type CPU_StateS is (CmdRead, CmdDecode, DataRW, ALUAndNop);
-- Сигналы для конечного автомата процессора.
signal CurrentState, NextState : CPU_StateS;

-- Текущие и будущие сигналы чтения/записи памяти.
signal Int_IRE_next, Int_IRE, Int_DRE_next, Int_DRE, Int_DWE_next, Int_DWE : STD_LOGIC;

-- Буфер для всех данных, считываемых из памяти.
signal InputBuffer : STD_LOGIC_VECTOR ((CPUBits - 1) downto 0);
-- Сигнал разрешения записи в этот буфер.
signal InputBuf_En : STD_LOGIC;

-- Указатель команды.
signal PC : STD_LOGIC_VECTOR ((CPUBits - 1) downto 0);
-- Разрешение на обновление и режим обновления (инкремент либо увеличение на константу).
signal PC_En, PC_Mode : STD_LOGIC;

-- Регистр адреса памяти.
signal Addr : STD_LOGIC_VECTOR ((CPUBits - 1) downto 0);
-- Разрешение на обновление и источник нового значения (InputBuffer либо PC).
signal Addr_En, Addr_Mode : STD_LOGIC;

-- Аккумулятор.
signal Acc : STD_LOGIC_VECTOR ((CPUBits - 1) downto 0);
-- Флаг переноса.
signal Carry : STD_LOGIC;
-- Буферные регистры для сигналов разрешения обновления и кода операции.
signal Acc_En_Buf, Acc_Mode0_Buf, Acc_Mode1_Buf : STD_LOGIC;

begin

  -- Схема сброса и управления тактированием.
  process (Res, Clk)
  begin
  if (Res = '1') then
    CE0 <= '0';
    CECPU <= '0';
  elsif RISING_EDGE (Clk) then
    CE0 <= CE;
    CECPU <= CE0;
  end if;
  end process;

  -- Конечный автомат управления процессором внешней памятью (регистр).
  process (Res, Clk)
  begin
  if (Res = '1') then
    CurrentState <= ALUAndNop;
    Int_IRE <= '0';
    Int_DRE <= '0';
    Int_DWE <= '0';
  elsif RISING_EDGE (Clk) then
    if (CECPU = '1') then
      CurrentState <= NextState;
      Int_IRE <= Int_IRE_next;
      Int_DRE <= Int_DRE_next;
      Int_DWE <= Int_DWE_next;
    end if;
  end if;
  end process;

  -- Если производится чтение памяти, то считанные данные в любом случае будут записаны в InputBuffer.
  InputBuf_En <= Int_IRE or Int_DRE;

  -- Входной буфер.
  process (Res, Clk)
  begin
  if (Res = '1') then
    InputBuffer <= (others => '0');
  elsif RISING_EDGE (Clk) then
    if (CECPU = '1') then
      if (InputBuf_En = '1') then
        InputBuffer <= Data;
      end if;
    end if;
  end if;
  end process;

  -- Дополнительный буфер для сигнала разрешения работы и команды АЛУ.
  process (Res, Clk)
  begin
  if (Res = '1') then
    Acc_En_Buf <= '0';
    Acc_Mode1_Buf <= '0';
    Acc_Mode0_Buf <= '0';
  elsif RISING_EDGE (Clk) then
    if (CECPU = '1') then
      if (CurrentState = DataRW) then -- АЛУ запускается только после состояния DataRW.
        Acc_En_Buf <= InputBuffer (CPUBits - 1); -- Дополнительно здесь должна быть 1.
        Acc_Mode1_Buf <= InputBuffer (CPUBits - 2); -- Этот сигнал и сигнал ниже можно вынести из под последнего if, сэкономив 1 Product Term,
        Acc_Mode0_Buf <= InputBuffer (CPUBits - 3); -- но за счёт частого переключения АЛУ потребление может стать больше.
      else
        Acc_En_Buf <= '0';
        Acc_Mode1_Buf <= '0';
        Acc_Mode0_Buf <= '0';
      end if;
    end if;
  end if;
  end process;

  -- Выполнение команд.
  -- Для команд STA, NOR, LDA, ADD, SUB последовательность смены состояний: CmdRead, CmdDecode, DataRW, ALUAndNop.
  -- Для команды JCC последовательность смены состояний: CmdRead, CmdDecode, если переход не выполняется.
  -- Для команды JCC последовательность смены состояний: CmdRead, CmdDecode, ALUAndNop, если переход выполняется.

  -- Конечный автомат управления процессором внешней памятью (логика).
  process (CurrentState, InputBuffer, Carry)
  begin
  case (CurrentState) is

    when CmdRead => -- Состояние, на котором происходит чтение команды из памяти.
      NextState <= CmdDecode;
      Int_IRE_next <= '0';
      Int_DRE_next <= '0';
      Int_DWE_next <= '0';
      PC_En <= '0';
      PC_Mode <= '0';
      Addr_En <= '0';
      Addr_Mode <= '0';

    when CmdDecode => -- Состояние, на котором происходит декодирование команды.
      if (InputBuffer(CPUBits - 1) = '1') then -- Переход к чтению данных из памяти.
        NextState <= DataRW;
        Int_IRE_next <= '0';
        Int_DRE_next <= '1'; -- Выдача сигнала чтения памяти данных.
        Int_DWE_next <= '0';
        PC_En <= '0';
        PC_Mode <= '0';
        Addr_En <= '1';
        Addr_Mode <= '1';

      elsif (InputBuffer(CPUBits - 2) = '1') then -- Переход к записи данных в память.
        NextState <= DataRW;
        Int_IRE_next <= '0';
        Int_DRE_next <= '0';
        Int_DWE_next <= '1'; -- Выдача сигнала записи памяти данных.
        PC_En <= '0';
        PC_Mode <= '0';
        Addr_En <= '1';
        Addr_Mode <= '1';

      elsif (Carry = '1') then  -- Переход к чтению следующей команды, команда перехода не выполняется.
        NextState <= CmdRead;
        Int_IRE_next <= '1'; -- Выдача сигнала чтения памяти программ.
        Int_DRE_next <= '0';
        Int_DWE_next <= '0';
        PC_En <= '1';
        PC_Mode <= '1';
        Addr_En <= '1';
        Addr_Mode <= '0';

      else -- Выполнение команды перехода.
        NextState <= ALUAndNop;
        Int_IRE_next <= '0';
        Int_DRE_next <= '0';
        Int_DWE_next <= '0';
        PC_En <= '1'; -- Увеличение PC на константу из кода операции, на 1 PC был увеличен ранее.
        PC_Mode <= '0';
        Addr_En <= '0';
        Addr_Mode <= '0';
      end if;

    when DataRW => -- Состояние для чтения и записи данных.
      NextState <= ALUAndNop;
      Int_IRE_next <= '0';
      Int_DRE_next <= '0';
      Int_DWE_next <= '0';
      PC_En <= '0';
      PC_Mode <= '0';
      Addr_En <= '0';
      Addr_Mode <= '0';

    when ALUAndNop => -- Состояние, на котором подготавливается исполнение следующей инструкции, а также при необходимости работает АЛУ, обновляется аккумулятор и флаг переноса.
      NextState <= CmdRead;
      Int_IRE_next <= '1'; -- Выдача сигнала чтения памяти программ.
      Int_DRE_next <= '0';
      Int_DWE_next <= '0';
      PC_En <= '1'; -- Увеличение PC на 1.
      PC_Mode <= '1';
      Addr_En <= '1'; -- Вывод предыдущего значения PC на шину адреса памяти.
      Addr_Mode <= '0';

    end case;
  end process;

  -- АЛУ и аккумулятор.
  process (Res, Clk)
  variable ExtendedALU : STD_LOGIC_VECTOR (CPUBits downto 0);
  begin
  if (Res = '1') then
    Acc <= (others => '0');
    Carry <= '0';
  elsif RISING_EDGE (Clk) then
    if (CECPU = '1') then

      if (Acc_En_Buf  = '1') then
        -- Для четырёх операций ниже коды подобраны так, чтобы количество используемых Product Term и Macrocell было минимальным.
        --
        if (Acc_Mode1_Buf = '1') and (Acc_Mode0_Buf = '0') then -- ADD
          ExtendedALU := ('0' & Acc) + ('0' & InputBuffer);
          Acc <= ExtendedALU ((CPUBits - 1) downto 0);
          Carry <= ExtendedALU (CPUBits);
        --
        elsif (Acc_Mode1_Buf = '1') and (Acc_Mode0_Buf = '1') then -- SUB
          ExtendedALU := ('0' & Acc) - ('0' & InputBuffer);
          Acc <= ExtendedALU ((CPUBits - 1) downto 0);
          Carry <= ExtendedALU (CPUBits);
        --
        elsif (Acc_Mode1_Buf = '0') and (Acc_Mode0_Buf = '0') then -- NOR
          Acc <= not (Acc or InputBuffer);
        --
        elsif (Acc_Mode1_Buf = '0') and (Acc_Mode0_Buf = '1') then -- LDA
          Acc <= InputBuffer;
        --
        end if;
      end if;

    end if;
  end if;
  end process;

  -- Програмный счётчик.
  process (Res, Clk)
  begin
  if (Res = '1') then
    PC <= (others => '0');
  elsif RISING_EDGE (Clk) then
    if (CECPU = '1') and (PC_En = '1') then
      if (PC_Mode = '1') then
        PC <= PC + 1;
      else
        PC <= PC + SXT (InputBuffer ((CPUBits - 3) downto 0), CPUBits);
      end if;
    end if;
  end if;
  end process;

  -- Регистр адреса.
  process (Res, Clk)
  begin
  if (Res = '1') then
    Addr <= (others => '0');
  elsif RISING_EDGE (Clk) then
    if (CECPU = '1') and (Addr_En = '1') then
      if (Addr_Mode = '1') then
        -- В зависимости от кода команды здесь загружается либо 5 бит, либо 6.
        Addr <= EXT ((not InputBuffer(CPUBits - 1) and InputBuffer(CPUBits - 3)) & InputBuffer((CPUBits - 4) downto 0), CPUBits);
      else
        Addr <= PC;
      end if;
    end if;
  end if;
  end process;

  Addres <= Addr;
  Data <= Acc when (Int_DWE = '1') else (others => 'Z');
  IRE <= Int_IRE;
  DRE <= Int_DRE;
  DWE <= Int_DWE;

end Arc_S64v4;
