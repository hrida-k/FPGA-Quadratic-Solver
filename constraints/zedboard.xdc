
## 100 MHz PL clock
set_property PACKAGE_PIN Y9 [get_ports clk_0]
set_property IOSTANDARD LVCMOS33 [get_ports clk_0]
create_clock -period 10.000 -name sys_clk [get_ports clk_0]

## Start - Center Push Button (BTNC)
set_property PACKAGE_PIN R18 [get_ports start_0]
set_property IOSTANDARD LVCMOS33 [get_ports start_0]

## Reset - Switch 0 (SW0)
set_property PACKAGE_PIN F22 [get_ports reset_n_0]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n_0]