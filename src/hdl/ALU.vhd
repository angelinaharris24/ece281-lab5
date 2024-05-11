--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
--|
--| ALU OPCODES:
--|
--|     ADD          000
--|     SUBTRACT     001
--|     OR           110
--|     AND          010
--|     LEFT SHIFT   100
--      RIGHT SHIFT  101
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
 use ieee.std_logic_unsigned.all;


entity ALU is
port (
   operand_A: in std_logic_vector(7 downto 0);
   operand_B: in std_logic_vector (7 downto 0);
   i_opcode: in std_logic_vector(2 downto 0);
   o_result: out std_logic_vector(7 downto 0);
   o_flags: out std_logic_vector (2 downto 0)
   );
end ALU;

architecture Behavioral of ALU is 

-- all signals declared below
signal w_B_pos_or_neg : std_logic_vector(7 downto 0);
signal adder_result : std_logic_vector (7 downto 0);
signal o_adder_result : std_logic_vector (7 downto 0);
signal w_AND : std_logic_vector (7 downto 0);
signal w_OR: std_logic_vector (7 downto 0);
signal w_shift_left : std_logic_vector (7 downto 0);
signal w_shift_right: std_logic_vector (7 downto 0);
signal w_output_shifting_mux: std_logic_vector (7 downto 0);
signal w_result: std_logic_vector (7 downto 0);
signal w_temporary_sum: std_logic_vector (8 downto 0);
signal c_in: std_logic;
signal c_out: std_logic;


begin   
       -- mux implemented here: determines whether to take inverse of operand B based on whether ADD or SUBTRACT
     w_B_pos_or_neg <= operand_B when i_opcode(0) = '0' else
                       not operand_B;
                    
      -- adder implemented below (satisfies ADD and SUBTRACT)
      
      -- brings in a 1 as the "carry in" if subtracting (for two's compliment)
      c_in <= i_opcode(0);
      
      -- w_temporary_sum is the correct decimal in signed binary
      w_temporary_sum <= ("0" & operand_A) + ("0" & w_B_pos_or_neg) + c_in;
      -- o_adder_result is the correct decimal, represented in unsigned binary      
      o_adder_result <= w_temporary_sum(7 downto 0);
      -- carry out bit is the sign bit (MSB) of the full sum
      c_out <= w_temporary_sum(8);
      
      
            
      -- AND implemented here
      w_AND <= std_logic_vector(unsigned(operand_A) and unsigned(operand_B));
      
      -- OR implemented here
      w_OR <= std_logic_vector(unsigned(operand_A) or unsigned(operand_B));
            
      -- shift left implemented here
      w_shift_left <= std_logic_vector(shift_left(unsigned(operand_A), to_integer(unsigned(operand_B(2 downto 0)))));
      
      -- shift right implemented here
      w_shift_right <= std_logic_vector(shift_right(unsigned(operand_A), to_integer(unsigned(operand_B(2 downto 0)))));
      
      -- mux implemented here: determines whether to display the right-shifted or left-shifted ALU result based on the opcode    
     w_output_shifting_mux <= w_shift_left when i_opcode(0) = '0' else
                               w_shift_right;
                                
      -- 4:1 mux implemented here to get the ALU result
      w_result <= o_adder_result when i_opcode(2 downto 1) = "00" else
                  w_AND when i_opcode(2 downto 1) = "01" else
                  w_OR when i_opcode (2 downto 1) = "11" else
                  w_output_shifting_mux;
                  
      o_result <= w_result;
                  
      -- implement flags below --> o_flags is (sign, zero, carry)
      
      -- implement carry flag here
      -- present when carry out bit is 1 and adding/subtracting
      o_flags(0) <= '1' when (c_out <= '1' and (i_opcode = "000" or i_opcode = "001")) else
      '0';
      
      -- implement zero flag here
      -- present when all bits of the output are 0
    o_flags(1) <= '1' when w_result = "00000000" else
    '0';
    
     -- implement negative flag here by connecting it to MSB of ALU output
     o_flags(2) <= w_result(7);

end Behavioral;