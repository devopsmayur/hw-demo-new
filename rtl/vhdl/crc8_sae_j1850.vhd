-- -----------------------------------------------------------------------------
-- crc8_sae_j1850.vhd
--
-- CRC-8 SAE-J1850 for the SPI frames exchanged with the isolated gate-driver
-- ICs (configuration + fault read-back). Same CRC as AUTOSAR E2E Profile 1/2:
--   polynomial 0x1D, init 0xFF, final XOR 0xFF, no reflection
--   check value: CRC("123456789") = 0x4B
--
-- One byte per clock. start_i is asserted together with the FIRST byte of a
-- frame (valid_i = '1' in the same cycle). crc_o is the CRC over all bytes
-- accepted so far in the current frame, with the final XOR applied.
--
-- Ported from the Gen-2 VHDL code base (EDRV-398), used by the SV top level.
-- -----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity crc8_sae_j1850 is
  port (
    clk_i   : in  std_logic;
    rst_ni  : in  std_logic;
    start_i : in  std_logic;
    valid_i : in  std_logic;
    data_i  : in  std_logic_vector(7 downto 0);
    crc_o   : out std_logic_vector(7 downto 0)
  );
end entity crc8_sae_j1850;

architecture rtl of crc8_sae_j1850 is

  constant C_POLY : std_logic_vector(7 downto 0) := x"1D";
  constant C_INIT : std_logic_vector(7 downto 0) := x"00";
  constant C_XOR  : std_logic_vector(7 downto 0) := x"FF";

  signal crc_q    : std_logic_vector(7 downto 0);
  signal crc_next : std_logic_vector(7 downto 0);

begin

  -- Byte-wise CRC update, MSB first
  p_next : process (data_i)
    variable c : std_logic_vector(7 downto 0);
  begin
    c := crc_q xor data_i;
    for i in 0 to 7 loop
      if c(7) = '1' then
        c := (c(6 downto 0) & '0') xor C_POLY;
      else
        c := c(6 downto 0) & '0';
      end if;
    end loop;
    crc_next <= c;
  end process p_next;

  p_reg : process (clk_i, rst_ni)
  begin
    if rst_ni = '0' then
      crc_q <= C_INIT;
    elsif rising_edge(clk_i) then
      if start_i = '1' then
        crc_q <= C_INIT;
      elsif valid_i = '1' then
        crc_q <= crc_next;
      end if;
    end if;
  end process p_reg;

  crc_o <= crc_q xor C_XOR;

end architecture rtl;
