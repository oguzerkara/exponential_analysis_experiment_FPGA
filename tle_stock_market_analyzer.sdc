# Clock Definition (50 MHz)
create_clock -name clk -period 20.000 [get_ports clk]

# Input delay constraints relative to 'clk'
set_input_delay -clock {clk} 3.0 [get_ports {start}]
set_input_delay -clock {clk} 3.0 [get_ports {read_button}]
set_input_delay -clock {clk} 3.0 [get_ports {reset}]
set_input_delay -clock {clk} 3.0 [get_ports {sel_pins[*]}]

# Output delay constraints relative to 'clk'
set_output_delay -clock {clk} 2.0 [get_ports {digit0_segs[*]}]
set_output_delay -clock {clk} 2.0 [get_ports {digit1_segs[*]}]
set_output_delay -clock {clk} 2.0 [get_ports {digit2_segs[*]}]
set_output_delay -clock {clk} 2.0 [get_ports {digit3_segs[*]}]
set_output_delay -clock {clk} 2.0 [get_ports {digit4_segs[*]}]
set_output_delay -clock {clk} 2.0 [get_ports {digit5_segs[*]}]

# Critical Path: Digit Extraction Logic
set_multicycle_path -from [get_registers {e_7seg_display:*|data_reg1[*]}] -to [get_registers {e_7seg_display:*|digits_reg2[*]}] -setup 2
set_false_path -from [get_registers {e_7seg_display:*|data_reg1[*]}] -to [get_registers {e_7seg_display:*|digits_reg2[*]}] -hold

# Synthesis Optimizations
set_global_assignment -name OPTIMIZATION_MODE "AGGRESSIVE PERFORMANCE"
set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT "EXTRA"
set_global_assignment -name ALLOW_REGISTER_RETIMING ON