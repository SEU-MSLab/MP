//******************************************************************************
// Copyright 2023 Microwave System Lab or its affiliates. All Rights Reserved.
//
// File: MP_LUT.sv
// Authors:
// Zhe Li, 904016301@qq.com
//
// Description:
// input:
// output:
// function:
// The High 16 bits in BRAM store I component, and the Low 16 bits store Q component
//
// Revision history:
// Version   Date        Author      Changes
// 1.0    2022-06-28    Zhe Li      initial version
//******************************************************************************
`ifndef MP_LUT__SV
`define MP_LUT__SV
// If the data range in [-16384, 16383], use B16_14
// else if the data range in [-32768, 32767], use B16_15
// `define B16_15
`ifndef B16_15
`define B16_14
`endif

`include "dpram.sv"

(* dont_touch = "yes" *)
module MP_LUT#(
    parameter int M = 3,
    parameter int K = 7,
    parameter int RESOLUTION =4096,
    parameter int BRANCH = 1  // The branch number count from 1 to 4
)(
    input                               JESD_clk_i,
    input                               AXI_clk_i,
    input                               reset_i,

    input signed  [15:0]                dac_input_i,
    input signed  [15:0]                dac_input_q,

    input   [31:0]                      coeff_data_i,
    input   [COEFF_WIDTH-1:0]           coeff_addr_i,
    // coeff_num_i: The LUT number for writing, since the logic
    // is replicated The content is the same for every branch,
    // so we only need M+1 address width
    input   [$clog2(M):0]               coeff_num_i,
    input                               coeff_en_i,

    // Each LUT has one output
    output  [16*LUT_num-1:0]            dpd_data_i,
    output  [16*LUT_num-1:0]            dpd_data_q
);

    localparam int LUT_num = M + 1;
    localparam int COEFF_WIDTH = $clog2(RESOLUTION);

    // compute how many delay unit we need
    function integer funclog4;
        input integer value;
        begin
            for(funclog4=0; value > 0; funclog4 = funclog4 + 1)
                value = value >> 2;
        end
    endfunction


    localparam      latency_num = funclog4(M); // The number of delay unit

    wire    [M:0]                   LUT_wea;    // controlled by coeff_num_i
    wire    [M:0]                   LUT_reb;
    wire    [COEFF_WIDTH-1:0]       LUT_addr    [latency_num+1];
    reg     signed  [31:0]          LUT_out     [M+1];
    reg     signed  [15:0]          LUT_out_i   [M+1];
    reg     signed  [15:0]          LUT_out_q   [M+1];

    reg     signed  [31:0]          MUL_i       [M+1];
    reg     signed  [31:0]          MUL_q       [M+1];
    reg     signed  [31:0]          MUL_A       [M+1];
    reg     signed  [31:0]          MUL_B       [M+1];
    reg     signed  [31:0]          MUL_C       [M+1];

    reg     signed  [31:0]          magnitude   [latency_num+1];
    reg     signed  [15:0]          dac_i_reg   [latency_num+1];
    reg     signed  [15:0]          dac_q_reg   [latency_num+1];

    reg     signed  [15:0]          dpd_i_reg   [M+1];
    reg     signed  [15:0]          dpd_q_reg   [M+1];
    reg     signed  [15:0]          dac_input_i_reg;
    reg     signed  [15:0]          dac_input_q_reg;

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
                    .addrb          (LUT_addr[i/4+1]),
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
    // The shift register for magnitude
    always @(posedge JESD_clk_i) begin
        magnitude[0] <= dac_input_i * dac_input_i + dac_input_q * dac_input_q;
        for(k = 0; k < latency_num; k = k + 1) begin
            magnitude[k+1] <= magnitude[k];
        end
    end

    generate
        for(i = 0; i < latency_num+1; i = i + 1) begin
            // The content in LUT is always in B16_14
            // However, depends on the input data, the magnitude may be in B16_14 or B16_15
            `ifdef B16_14
            assign LUT_addr[i] = magnitude[i][28] ? {COEFF_WIDTH{1'b1}} : magnitude[i][27-:COEFF_WIDTH];
            `elsif B16_15
            assign LUT_addr[i] = magnitude[i][30] ? {COEFF_WIDTH{1'b1}} : magnitude[i][29-:COEFF_WIDTH];
            `endif
        end
    endgenerate

    generate
        for(i = 0; i < LUT_num; i = i + 1) begin
            assign LUT_out_i[i] = LUT_out[i][31:16];
            assign LUT_out_q[i] = LUT_out[i][15:0];
        end
    endgenerate


    // shift registers for input data
    always @(posedge JESD_clk_i) begin
        dac_i_reg[0]    <= dac_input_i_reg;
        dac_q_reg[0]    <= dac_input_q_reg;
        for(k = 0; k < latency_num; k = k + 1) begin
            dac_i_reg[k+1] <= dac_i_reg[k];
            dac_q_reg[k+1] <= dac_q_reg[k];
        end
    end


    // core compute unit
    // each LUT take one multiplication
    always @(posedge JESD_clk_i) begin
        for(k = 0; k < LUT_num; k = k + 1) begin
            MUL_i[k] <= MUL_A[k] - MUL_B[k];
            MUL_q[k] <= MUL_B[k] - MUL_C[k];
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
                // 16_15+16_15 = 17_15，16_14*17_15 = 33_29, remove a signed bit，32_29
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
`endif
