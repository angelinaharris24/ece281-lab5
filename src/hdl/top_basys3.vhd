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
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity top_basys3 is
port(
        clk     :   in std_logic; -- native 100MHz FPGA clock
		-- 7-segment display segments (cathodes CG ... CA)
		seg		:	out std_logic_vector(6 downto 0);  -- seg(6) = CG, seg(0) = CA
		-- 7-segment display active-low enables (anodes)
		an      :	out std_logic_vector(3 downto 0);
		-- Switches
		sw		:	in  std_logic_vector(15 downto 0);
		-- Buttons
		btnC	:	in	std_logic;
		btnU    : in  std_logic;
		-- lEDs
		led	    :	out	std_logic_vector(15 downto 0)

	);
end top_basys3;

architecture top_basys3_arch of top_basys3 is 

  component clock_divider is
             generic ( constant k_DIV : natural := 2    );
             port (  i_clk    : in std_logic;           -- basys3 clk
                     i_reset  : in std_logic;           
                     o_clk    : out std_logic          
             );
         end component clock_divider;

  component sevenSegDecoder is
            port(  i_D : in std_logic_vector (3 downto 0);
                   o_S : out std_logic_vector (6 downto 0)
             );
         end component sevenSegDecoder;
    
    component controller_fsm is 
     port (
     i_adv     : in  STD_LOGIC;
     i_clk     : in STD_LOGIC;
     i_reset   : in  STD_LOGIC;
     o_cycle   : out STD_LOGIC_VECTOR (3 downto 0)
     );
     end component controller_fsm;
     
     component registerA is 
       port (
      o_state : in STD_LOGIC_VECTOR (3 downto 0);
      o_switch_signal : in std_logic_vector (7 downto 0);
      o_A : out STD_LOGIC_VECTOR (7 downto 0)
       );
       end component registerA;
       
     component registerB is 
      port (
           o_state : in STD_LOGIC_VECTOR (3 downto 0);
           o_switch_signal : in std_logic_vector (7 downto 0);
           o_B : out STD_LOGIC_VECTOR (7 downto 0)
      );
      end component registerB;

     component TDM4 is
     generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
              Port ( i_clk        : in  STD_LOGIC;
                     i_reset        : in  STD_LOGIC; 
                     i_D3         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                     i_D2         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                     i_D1         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                     i_D0         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                     o_data        : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
                     o_sel        : out STD_LOGIC_VECTOR (3 downto 0)   
              );
      end component TDM4;
          
          
    component twoscomp_decimal is 
           port (
           i_binary: in std_logic_vector(7 downto 0);
           o_negative: out std_logic_vector (3 downto 0);
           o_hundreds: out std_logic_vector(3 downto 0);
           o_tens: out std_logic_vector(3 downto 0);
           o_ones: out std_logic_vector(3 downto 0)
           );
     end component twoscomp_decimal;
           
     component ALU is 
       port (
              operand_A: in std_logic_vector (7 downto 0);
              operand_B: in std_logic_vector (7 downto 0);
               i_opcode: in std_logic_vector(2 downto 0);
               o_result: out std_logic_vector(7 downto 0);
               o_flags: out std_logic_vector (2 downto 0)
               );
      end component ALU;
      
      -- all signals below
        signal w_state : std_logic_vector (3 downto 0);
        signal w_A : std_logic_vector (7 downto 0);
        signal w_B : std_logic_vector (7 downto 0);
        signal w_clk : std_logic;
        signal x_clk : std_logic;
        signal w_clk_reset : std_logic;
        signal w_clk_reset2 : std_logic;
        signal w_cath : std_logic_vector (3 downto 0);
        signal w_tdm_reset : std_logic;
        signal w_ones : std_logic_vector (3 downto 0);
        signal w_tens : std_logic_vector (3 downto 0);
        signal w_hund : std_logic_vector (3 downto 0);
        signal w_sign : std_logic_vector (3 downto 0);
        signal w_an : std_logic_vector (3 downto 0);        
        signal w_mux_result : std_logic_vector (7 downto 0);
        signal w_ALU_result : std_logic_vector (7 downto 0);
 

begin
     
        controller_inst: controller_fsm
                port map(
                i_clk => w_clk,
                o_cycle   => w_state,
                i_reset    => btnU,
                i_adv => btnC
                );
                
        registerA_inst: registerA
               port map(
               o_state => w_state,
               o_A   => w_A,
               o_switch_signal => sw (7 downto 0)
               );
                        
        registerB_inst: registerB
                port map(
                o_state => w_state,
                o_B   => w_B,
                o_switch_signal => sw (7 downto 0)
                );
                
        clkdiv_inst : clock_divider 		--instantiation of clock_divider for the elevator FSM
           generic map ( k_DIV => 25000000) 
                 port map (                         
                 i_clk   => clk,
                 i_reset => w_clk_reset,
                 o_clk   => w_clk
                 );  
                        
         clkdiv_inst2 : clock_divider 		-- 2nd instantiation of clock_divider for the TDM
            generic map ( k_DIV => 1000) 
            port map (                          
            i_clk   => clk,
           i_reset => w_clk_reset2,
           o_clk   => x_clk
            ); 
        
        sevenSeg_inst: sevenSegDecoder
           port map(
           i_D => w_cath,
           o_S => seg
         );
      
       TDM4_inst: TDM4
           port map (
              i_clk  => x_clk,  
              i_reset => w_tdm_reset,      
              i_D3  => w_ones (3 downto 0), 
              i_D2  => w_tens (3 downto 0), 
              i_D1 => w_hund (3 downto 0),   
              i_D0 => w_sign (3 downto 0),
              o_data => w_cath,
              o_sel => w_an
            );
            
    twoscomp_inst: twoscomp_decimal
          port map(
             i_binary => w_mux_result,
             o_negative => w_sign,
             o_hundreds => w_hund,
             o_tens => w_tens,
             o_ones => w_ones
           );
           
     ALU_inst: ALU
        port map(
        operand_A => w_A,
        operand_B => w_B,
        i_opcode => sw (2 downto 0),
        o_result => w_ALU_result,
        o_flags(2) => led(15),
        o_flags(1) => led(14),
        o_flags(0) => led(13)
        -- o_flags is (sign, zero, carry)
         );       
           
    -- mux implemented below: determines whether to display operand A, operand B, or the ALU result
    w_mux_result <= w_A when w_state = "0010" else
              w_B when w_state = "0100" else
              w_ALU_result;
              
     an <= "1111" when w_state = "0001" else
      w_an;
              
   -- additional statements
   
   -- wires up LEDs to reflect FSM     
   led(3 downto 0) <= w_state;
   -- establishes reset button
   w_clk_reset <= btnU;
   -- grounds all unused LEDs
   led(12 downto 4) <= "000000000";

end top_basys3_arch;