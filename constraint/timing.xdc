create_clock -period 4.069 -name clk [get_ports JESD_clk_i]
create_clock -period 10 -name clk [get_ports AXI_clk_i]
