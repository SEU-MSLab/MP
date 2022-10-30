`timescale  1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lizhe   904016301@qq.com
// 
// Create Date: 2022/06/28 19:31:32
// Design Name: 
// Module Name: MP_LUT_wrapper 
// Description: 查找表实现的MP模型，4路逻辑复制
// 先使用Bram来实现
// 
// Dependencies: dpram.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module MP_LUT_wrapper #(
    parameter       M = 3,   // LUT的数量是M+1
    parameter       LUT_num = M + 1,
    parameter       n = LUT_num / 4 + 1,
    parameter       K = 7,
    parameter       RESOLUTION = 4096
)(
    input                               JESD_clk_i,
    input                               reset_i,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 MP_BRAM CLK" *)
    input                               AXI_clk_i,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0  MP_BRAM DIN" *)
    input   [31:0]                      coeff_i,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 MP_BRAM ADDR" *)
    input   [$clog2(RESOLUTION) + $clog2(LUT_num) + 1:0]    coeff_addr_i, 
    // input   [$clog2(RESOLUTION) + $clog2(LUT_num) - 1:0]    coeff_addr_i, 
      (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 MP_BRAM EN" *)
    input                               coeff_en_i,
    input   [127:0]                     dac_i,
    input                               vio_wdpd_i, //控制是否用DPD输出

    output                              LED_OVF,
    output  [127:0]                     data_o,
    output  [15:0]                      sample0_r_ila,
    output  [15:0]                      sample0_i_ila
);

    localparam COEFF_WIDTH  = $clog2(RESOLUTION);
    localparam LUTNUM_WIDTH = $clog2(LUT_num);
    
    reg     [31:0]                          coeff_data;
    reg     [COEFF_WIDTH+LUTNUM_WIDTH-1:0]  coeff_addr;
    reg                                     coeff_en;
    wire    [$clog2(M):0]                   coeff_num;// 写入的LUT编号，虽然逻辑复制，但是内部是一样的，所以只用M+1个

    assign coeff_num = coeff_addr[COEFF_WIDTH+:LUTNUM_WIDTH];
    
    // 4个sample的数据
    // reg signed  [15:0]          dac_data0_i_reg;
    // reg signed  [15:0]          dac_data0_q_reg;
    // reg signed  [15:0]          dac_data1_i_reg;
    // reg signed  [15:0]          dac_data1_q_reg;  
    // reg signed  [15:0]          dac_data2_i_reg;
    // reg signed  [15:0]          dac_data2_q_reg;
    // reg signed  [15:0]          dac_data3_i_reg;
    // reg signed  [15:0]          dac_data3_q_reg;
    reg signed  [15:0]          dac_data0_i;
    reg signed  [15:0]          dac_data0_q;
    reg signed  [15:0]          dac_data1_i;
    reg signed  [15:0]          dac_data1_q;
    reg signed  [15:0]          dac_data2_i;
    reg signed  [15:0]          dac_data2_q;
    reg signed  [15:0]          dac_data3_i;
    reg signed  [15:0]          dac_data3_q;

    wire signed  [15:0]         dpd_data0_i [M:0];
    wire signed  [15:0]         dpd_data0_q [M:0];
    wire signed  [15:0]         dpd_data1_i [M:0];
    wire signed  [15:0]         dpd_data1_q [M:0];
    wire signed  [15:0]         dpd_data2_i [M:0];
    wire signed  [15:0]         dpd_data2_q [M:0];
    wire signed  [15:0]         dpd_data3_i [M:0];
    wire signed  [15:0]         dpd_data3_q [M:0];


    wire signed  [16*LUT_num-1:0]dpd_i_branch [3:0];
    wire signed  [16*LUT_num-1:0]dpd_q_branch [3:0];
    


// 用异或比用比较运算符节省更多资源
assign LED_OVF = (dac_data0_i[15] ^ dac_data0_i[14]) || (dac_data0_q[15] ^ dac_data0_q[14]) || 
                (dac_data1_i[15] ^ dac_data1_i[14]) || (dac_data1_q[15] ^ dac_data1_q[14]) || 
                (dac_data2_i[15] ^ dac_data2_i[14]) || (dac_data2_q[15] ^ dac_data2_q[14]) ||
                (dac_data3_i[15] ^ dac_data3_i[14]) || (dac_data3_q[15] ^ dac_data3_q[14]);



// AXI时钟下打拍信号
always @(posedge AXI_clk_i) begin
    coeff_data  <=  coeff_i;
    coeff_addr  <=  coeff_addr_i[2+:COEFF_WIDTH+LUTNUM_WIDTH]; // Bram Ctrl是以字节为单位写入的，因此低2位忽视
    // coeff_addr  <= coeff_addr_i[COEFF_WIDTH-1:0];
    coeff_en    <=  coeff_en_i;
end

// JESD时钟下打拍信号
// 最先发送给DAC的，会放在更低位，所以dac_data0比dac_data3更早发送出去
always @(posedge JESD_clk_i) begin
    dac_data0_i         <= {dac_i[0+:8 ] , dac_i[32+:8] };
    dac_data0_q         <= {dac_i[64+:8] , dac_i[96+:8] };
    dac_data1_i         <= {dac_i[8+:8 ] , dac_i[40+:8] };
    dac_data1_q         <= {dac_i[72+:8] , dac_i[104+:8] };
    dac_data2_i         <= {dac_i[16+:8] , dac_i[48+:8] };
    dac_data2_q         <= {dac_i[80+:8] , dac_i[112+:8]};
    dac_data3_i         <= {dac_i[24+:8] , dac_i[56+:8] };
    dac_data3_q         <= {dac_i[88+:8] , dac_i[120+:8]};
    // dac_data0_i_reg     <= dac_data0_i << 1;
    // dac_data0_q_reg     <= dac_data0_q << 1;
    // dac_data1_i_reg     <= dac_data1_i << 1;
    // dac_data1_q_reg     <= dac_data1_q << 1;
    // dac_data2_i_reg     <= dac_data2_i << 1;
    // dac_data2_q_reg     <= dac_data2_q << 1;
    // dac_data3_i_reg     <= dac_data3_i << 1;
    // dac_data3_q_reg     <= dac_data3_q << 1;
end   

    // branch1放x(n)，也就是最新的数据点
    MP_LUT #(
        .BRANCH     (1), 
        .M          (M),
        .RESOLUTION (RESOLUTION)
    ) branch1 (
        .JESD_clk_i         (JESD_clk_i),
        .AXI_clk_i          (AXI_clk_i),
        .reset_i            (reset_i),
        .dac_input_i        (dac_data3_i),
        .dac_input_q        (dac_data3_q),
        .coeff_data_i       (coeff_data),
        .coeff_addr_i       (coeff_addr[COEFF_WIDTH-1:0]),
        .coeff_num_i        (coeff_num),
        .coeff_en_i         (coeff_en),
        .dpd_data_i         (dpd_i_branch[3]),
        .dpd_data_q         (dpd_q_branch[3])
    );

    MP_LUT #(
        .BRANCH (2),
        .M      (M),
        .RESOLUTION (RESOLUTION)
    ) branch2 (
        .JESD_clk_i         (JESD_clk_i),
        .AXI_clk_i          (AXI_clk_i),
        .reset_i            (reset_i),
        .dac_input_i        (dac_data2_i),
        .dac_input_q        (dac_data2_q),
        .coeff_data_i       (coeff_data),
        .coeff_addr_i       (coeff_addr[COEFF_WIDTH-1:0]),
        .coeff_num_i        (coeff_num),
        .coeff_en_i         (coeff_en),
        .dpd_data_i         (dpd_i_branch[2]),
        .dpd_data_q         (dpd_q_branch[2])
    );
    
    MP_LUT #(
        .BRANCH (3),
        .M      (M),
        .RESOLUTION (RESOLUTION)
    ) branch3 (
        .JESD_clk_i         (JESD_clk_i),
        .AXI_clk_i          (AXI_clk_i),
        .reset_i            (reset_i),
        .dac_input_i        (dac_data1_i),
        .dac_input_q        (dac_data1_q),
        .coeff_data_i       (coeff_data),
        .coeff_addr_i       (coeff_addr[COEFF_WIDTH-1:0]),
        .coeff_num_i        (coeff_num),
        .coeff_en_i         (coeff_en),
        .dpd_data_i         (dpd_i_branch[1]),
        .dpd_data_q         (dpd_q_branch[1])
    );

    MP_LUT #(
        .BRANCH (4),
        .M      (M),
        .RESOLUTION (RESOLUTION)
    ) branch4 (
        .JESD_clk_i         (JESD_clk_i),
        .AXI_clk_i          (AXI_clk_i),
        .reset_i            (reset_i),
        .dac_input_i        (dac_data0_i),
        .dac_input_q        (dac_data0_q),
        .coeff_data_i       (coeff_data),
        .coeff_addr_i       (coeff_addr[COEFF_WIDTH-1:0]),
        .coeff_num_i        (coeff_num),
        .coeff_en_i         (coeff_en),
        .dpd_data_i         (dpd_i_branch[0]),
        .dpd_data_q         (dpd_q_branch[0])
    );

genvar i;
generate 
    // dpd_data0_i就是y0_i
    // branch[0]表示x0的branch
    assign dpd_data0_i[0] = dpd_i_branch[0][15:0];
    assign dpd_data0_q[0] = dpd_q_branch[0][15:0];
    assign dpd_data1_i[0] = dpd_i_branch[1][15:0];
    assign dpd_data1_q[0] = dpd_q_branch[1][15:0];
    assign dpd_data2_i[0] = dpd_i_branch[2][15:0];
    assign dpd_data2_q[0] = dpd_q_branch[2][15:0];
    assign dpd_data3_i[0] = dpd_i_branch[3][15:0];
    assign dpd_data3_q[0] = dpd_q_branch[3][15:0];

    
    for(i = 1; i < LUT_num; i = i + 1) begin
        assign dpd_data0_i[i] = dpd_i_branch[(4*n-i)%4][i*16+:16]   + dpd_data0_i[i-1];
        assign dpd_data1_i[i] = dpd_i_branch[(4*n-i+1)%4][i*16+:16] + dpd_data1_i[i-1];
        assign dpd_data2_i[i] = dpd_i_branch[(4*n-i+2)%4][i*16+:16] + dpd_data2_i[i-1];
        assign dpd_data3_i[i] = dpd_i_branch[(4*n-i+3)%4][i*16+:16] + dpd_data3_i[i-1];

        assign dpd_data0_q[i] = dpd_q_branch[(4*n-i)%4][i*16+:16]   + dpd_data0_q[i-1];
        assign dpd_data1_q[i] = dpd_q_branch[(4*n-i+1)%4][i*16+:16] + dpd_data1_q[i-1];
        assign dpd_data2_q[i] = dpd_q_branch[(4*n-i+2)%4][i*16+:16] + dpd_data2_q[i-1];
        assign dpd_data3_q[i] = dpd_q_branch[(4*n-i+3)%4][i*16+:16] + dpd_data3_q[i-1];
    end
    
endgenerate

    wire [31:0] lane0;
    wire [31:0] lane1;
    wire [31:0] lane2;
    wire [31:0] lane3;

    reg  [15:0] dpd_data0_i_reg;
    reg  [15:0] dpd_data1_i_reg;
    reg  [15:0] dpd_data2_i_reg;
    reg  [15:0] dpd_data3_i_reg;
    reg  [15:0] dpd_data0_q_reg;
    reg  [15:0] dpd_data1_q_reg;
    reg  [15:0] dpd_data2_q_reg;
    reg  [15:0] dpd_data3_q_reg;

    always @(posedge JESD_clk_i) begin
        dpd_data0_i_reg = dpd_data0_i[M];
        dpd_data1_i_reg = dpd_data1_i[M];
        dpd_data2_i_reg = dpd_data2_i[M];
        dpd_data3_i_reg = dpd_data3_i[M];
        dpd_data0_q_reg = dpd_data0_q[M];
        dpd_data1_q_reg = dpd_data1_q[M];
        dpd_data2_q_reg = dpd_data2_q[M];
        dpd_data3_q_reg = dpd_data3_q[M];
    end
    

    // dpd_data3是y3，最晚进入PA的
    assign lane0 = { dpd_data3_i_reg[15:8], dpd_data2_i_reg[15:8], dpd_data1_i_reg[15:8],dpd_data0_i_reg[15:8]};
    assign lane1 = { dpd_data3_i_reg[7:0 ], dpd_data2_i_reg[7:0 ], dpd_data1_i_reg[7:0 ],dpd_data0_i_reg[7:0]}; 
    assign lane2 = { dpd_data3_q_reg[15:8], dpd_data2_q_reg[15:8], dpd_data1_q_reg[15:8],dpd_data0_q_reg[15:8]};
    assign lane3 = { dpd_data3_q_reg[7:0 ], dpd_data2_q_reg[7:0 ], dpd_data1_q_reg[7:0 ],dpd_data0_q_reg[7:0]}; 


// 低位放先传输的数据
assign data_o = vio_wdpd_i ? {lane3, lane2, lane1, lane0} : dac_i;

assign sample0_r_ila = vio_wdpd_i ? dpd_data0_i[M] : {dac_i[7:0], dac_i[39:32]};
assign sample0_i_ila = vio_wdpd_i ? dpd_data0_q[M] : {dac_i[71:64], dac_i[103:96]};


endmodule