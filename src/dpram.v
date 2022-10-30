`timescale 1ns/100ps
//From ADI_Library ad_mem.v
// 输入数据与输出数据宽度一样的异步双口RAM
// 写入时，wea、数据和地址同一个周期给
// 读出时，拉高reb后要等下一个周期取数据
// 参考PG058的Figure 3-22

module dpram #(

  parameter  DATA_WIDTH = 16,
  parameter  ADDRESS_WIDTH = 5
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

// ***************************************************************************
// ***************************************************************************
