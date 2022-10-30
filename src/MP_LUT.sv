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
// LUT的高16位放I，低16位放Q
//////////////////////////////////////////////////////////////////////////////k////
// 测试的时候，输入数据是B16_14的，范围在-16384到16383之间
// `define B16_15
`ifndef B16_15
`define B16_14
`endif
(* dont_touch = "yes" *)
module MP_LUT#(
    parameter       M = 3,
    parameter       LUT_num = M + 1,
    parameter       K = 7,
    parameter       RESOLUTION =4096,
    parameter       COEFF_WIDTH = $clog2(RESOLUTION),
    parameter       BRANCH = 1  // 分支从1开始计数，为1,2,3,4条分支
)(
    input                               JESD_clk_i,
    input                               AXI_clk_i,
    input                               reset_i,

    input signed  [15:0]                dac_input_i,
    input signed  [15:0]                dac_input_q,

    input   [31:0]                      coeff_data_i,
    input   [COEFF_WIDTH-1:0]           coeff_addr_i,
    input   [$clog2(M):0]               coeff_num_i, // 写入的LUT编号，虽然逻辑复制，但是内部是一样的，所以只用M+1个 
    input                               coeff_en_i, 

    output  [16*LUT_num-1:0]            dpd_data_i,   // 每个LUT有一个输出，总共LUT_num个输出
    output  [16*LUT_num-1:0]            dpd_data_q
);
    
// 计算需要多少延时单元
function integer funclog4;
    input integer value;
    begin
        for(funclog4=0; value > 0; funclog4 = funclog4 + 1)
            value = value >> 2;
    end
endfunction
    
    
    localparam      latency_num = funclog4(M); // 表示有多少个延时单元

    wire    [M:0]                   LUT_wea;    // 由coeff_num_i控制
    wire    [M:0]                   LUT_reb;
    wire    [COEFF_WIDTH-1:0]       LUT_addr [latency_num:0];
    reg     signed  [31:0]   LUT_out     [M:0]; // 总共LUT_num个输出
    reg     signed  [15:0]   LUT_out_i   [M:0];
    reg     signed  [15:0]   LUT_out_q   [M:0];
    // wire    signed  [31:0]   LUT_out_wire[M:0];
    reg     signed  [31:0]   MUL_i       [M:0];
    reg     signed  [31:0]   MUL_q       [M:0];
    reg     signed  [31:0]   MUL_A       [M:0];
    reg     signed  [31:0]   MUL_B       [M:0];
    reg     signed  [31:0]   MUL_C       [M:0];
    
    reg     signed  [31:0]   magnitude   [latency_num:0];  // 1个延时单元就需要2个寄存器装了
    reg     signed  [15:0]   dac_i_reg   [latency_num:0];
    reg     signed  [15:0]   dac_q_reg   [latency_num:0];    

    reg     signed  [15:0]   dpd_i_reg   [M:0];
    reg     signed  [15:0]   dpd_q_reg   [M:0];
    reg     signed  [15:0]   dac_input_i_reg;
    reg     signed  [15:0]   dac_input_q_reg;
 
genvar i,j;
generate  
    for(i = 0; i < LUT_num; i = i + 1) begin: LUT_gen
        if(i%4 >= BRANCH) begin
            dpram #(
                .DATA_WIDTH     (32),
                .ADDRESS_WIDTH  (COEFF_WIDTH)
            ) LUT (
                .clka           (AXI_clk_i),
                .clkb           (JESD_clk_i),
                .wea            (LUT_wea[i]),
                .reb            (1'b1),
                .addra          (coeff_addr_i),
                .addrb          (LUT_addr[i/4+1]), // magnitude右移17位，相当于除131,072就是地址
                .dina           (coeff_data_i),
                .doutb          (LUT_out[i])
            );
        end
        else begin
            dpram #(
                .DATA_WIDTH     (32),
                .ADDRESS_WIDTH  (COEFF_WIDTH)
            ) LUT (
                .clka           (AXI_clk_i),
                .clkb           (JESD_clk_i),
                .wea            (LUT_wea[i]),
                .reb            (1'b1),
                .addra          (coeff_addr_i),
                .addrb          (LUT_addr[i/4]),
                .dina           (coeff_data_i),
                .doutb          (LUT_out[i])
            );
        end
    end
endgenerate


always@(posedge JESD_clk_i) begin
    dac_input_i_reg <= dac_input_i;
    dac_input_q_reg <= dac_input_q;
end

integer k;
// 模值的移位寄存器
always @(posedge JESD_clk_i) begin
    magnitude[0] <= dac_input_i * dac_input_i + dac_input_q * dac_input_q;
    for(k = 0; k < latency_num; k = k + 1) begin
        magnitude[k+1] <= magnitude[k];
    end
end

// always @(posedge JESD_clk_i) begin
//     for(k = 0; k < LUT_num; k = k+1) begin
//         LUT_out[k] <= LUT_out_wire[k];
//     end
// end

generate
    for(i = 0; i < latency_num+1; i = i + 1) begin
        // 下一行对16_14的DAC输入，即范围在-16384~16383
        `ifdef B16_14
        assign LUT_addr[i] = magnitude[i][28] ? {COEFF_WIDTH{1'b1}} : magnitude[i][27-:COEFF_WIDTH];
        // 下一行对16_15的DAC输入，即范围在-32768~32767
        `elsif B16_15
        assign LUT_addr[i] = magnitude[i][30] ? {COEFF_WIDTH{1'b1}} : magnitude[i][29-:COEFF_WIDTH];
        `endif
        // 不想判断也行，通过控制ADC输入防止溢出
        // assign LUT_addr[i] = magnitude[i][27-:COEFF_WIDTH];
    end
endgenerate

generate
    for(i = 0; i < LUT_num; i = i + 1) begin
        assign LUT_out_i[i] = LUT_out[i][31:16];
        assign LUT_out_q[i] = LUT_out[i][15:0];
    end
endgenerate


// 输入数据的移位寄存器
always @(posedge JESD_clk_i) begin
    dac_i_reg[0]    <= dac_input_i_reg;
    dac_q_reg[0]    <= dac_input_q_reg;
    for(k = 0; k < latency_num; k = k + 1) begin
        dac_i_reg[k+1] <= dac_i_reg[k];
        dac_q_reg[k+1] <= dac_q_reg[k];
    end
end


// 核心计算单元
// 每个LUT完成一次乘法
always @(posedge JESD_clk_i) begin
    for(k = 0; k < LUT_num; k = k + 1) begin
        MUL_i[k] <= MUL_A[k] - MUL_B[k];
        MUL_q[k] <= MUL_B[k] - MUL_C[k];
        // 这里可以将输出功率的缺陷补偿
        // 下面2行是对16_14的输入
        `ifdef B16_14
        dpd_i_reg[k] <= {MUL_i[k][31], MUL_i[k][28-:15]};
        dpd_q_reg[k] <= {MUL_q[k][31], MUL_q[k][28-:15]};
        `elsif B16_15
        dpd_i_reg[k] <= {MUL_i[k][31], MUL_i[k][29-:15]};
        dpd_q_reg[k] <= {MUL_q[k][31], MUL_q[k][29-:15]};
        `endif
    end
end




generate
for(i=0; i < LUT_num; i = i+1) begin
always@(posedge JESD_clk_i) begin
        if(i%4 >= BRANCH) begin
            // 必须要加$signed，只有LUT_out定义时加signed不够
            // 16_15+16_15 = 17_15，16_14*17_15 = 33_29, 去掉1个符号位，32_29
            MUL_A[i] <= dac_i_reg[i/4 + 1]  * (LUT_out_i[i] + LUT_out_q[i]);
            // 16_14+16_14 = 17_14, 16_15*17_14 = 33_29
            MUL_B[i] <= LUT_out_q[i]        * (dac_i_reg[i/4 + 1] + dac_q_reg[i/4 + 1]); 
            MUL_C[i] <= dac_q_reg[i/4 + 1]  * (LUT_out_q[i] - LUT_out_i[i]);
        end
        else begin
            MUL_A[i] <= dac_i_reg[i/4]      * (LUT_out_i[i] + LUT_out_q[i]);
            MUL_B[i] <= LUT_out_q[i]        * (dac_i_reg[i/4] + dac_q_reg[i/4]);
            MUL_C[i] <= dac_q_reg[i/4]      * (LUT_out_q[i] - LUT_out_i[i]);
        end
    end    
end
endgenerate





generate
for(i=0; i < LUT_num; i = i+1) begin
    assign dpd_data_i[i*16+:16] = dpd_i_reg[i];
    assign dpd_data_q[i*16+:16] = dpd_q_reg[i];
end
endgenerate

    assign LUT_wea = coeff_en_i ? 1 << coeff_num_i : 'd0;


endmodule


