//******************************************************************************
// Copyright 2023 Microwave System Lab or its affiliates. All Rights Reserved.
//
// File: dpram.sv
// Authors:
// Zhe Li, 904016301@qq.com
//
// Description:
// input:
// output:
// function:
// The async dual-port RAM with the same width of input and output data
// When writing, wea, data and address are asserted in the same cycle
// When reading, reb is asserted and wait for the next cycle to get data
// Refer to Figure 3-22 in PG058
//
// Revision history:
// Version   Date        Author      Changes
// 1.0    2022-06-28    Zhe Li      initial version
//******************************************************************************
`ifndef DPRAM__SV
`define DPRAM__SV

module dpram #(
  parameter int DATA_WIDTH = 16,
  parameter int ADDRESS_WIDTH = 5
  ) (

  input                               clka,
  input                               wea,
  input       [(ADDRESS_WIDTH-1):0]   addra,
  input       [(DATA_WIDTH-1):0]      dina,

  input                               clkb,
  input                               reb,
  input       [(ADDRESS_WIDTH-1):0]   addrb,
  output  reg [(DATA_WIDTH-1):0]      doutb);

  (* ram_style = "block" *)
  reg         [(DATA_WIDTH-1):0]      m_ram[0:((2**ADDRESS_WIDTH)-1)];

  always @(posedge clka) begin
    if (wea == 1'b1) begin
      m_ram[addra] <= dina;
    end
  end


  always @(posedge clkb) begin
    if (reb == 1'b1) begin
      doutb <= m_ram[addrb];
    end
  end

endmodule
`endif
