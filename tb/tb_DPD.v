`timescale  1ns/1ps

module tb_DPD();

localparam M = 3;
localparam MEMORY_DEPTH = 32768; // 激励数据的深度
localparam DATA_WIDTH = 32; // 包含实部与虚部
localparam LUT_DEPTH = 4096;



reg     JESD_clk = 0;
reg     AXI_clk = 0;
reg     reset = 0;

reg [31:0]      coeff = 32'hAAAAAAAA;
reg [$clog2(LUT_DEPTH*(M+1))-1:0]      coeff_addr = 'd0;
reg             coeff_en = 1'b1;

reg [127:0]     dac; // 包含4个DAC数据
wire [127:0]    dpd;
reg [31:0]      lut;
reg [$clog2(MEMORY_DEPTH/4)-1:0] counter_dac = 'd0;

reg [127:0]     dac_data    [0:MEMORY_DEPTH-1];
reg [31:0]      dpd_data    [0:MEMORY_DEPTH-1];
reg [31:0]      lut_data    [0:LUT_DEPTH*(M+1)-1];

wire [15:0]              dpd_i_sample0;
wire [15:0]              dpd_i_sample1;
wire [15:0]              dpd_i_sample2;
wire [15:0]              dpd_i_sample3;
wire [15:0]              dpd_q_sample0;
wire [15:0]              dpd_q_sample1;
wire [15:0]              dpd_q_sample2;
wire [15:0]              dpd_q_sample3;

always #2.035 JESD_clk = ~JESD_clk;
always #2 AXI_clk = ~AXI_clk;


assign    dpd_i_sample0 = {dpd[0+:8 ] , dpd[32+:8] };
assign    dpd_q_sample0 = {dpd[64+:8] , dpd[96+:8] };
assign    dpd_i_sample1 = {dpd[8+:8 ] , dpd[40+:8] };
assign    dpd_q_sample1 = {dpd[72+:8] , dpd[104+:8]};
assign    dpd_i_sample2 = {dpd[16+:8] , dpd[48+:8] };
assign    dpd_q_sample2 = {dpd[80+:8] , dpd[112+:8]};
assign    dpd_i_sample3 = {dpd[24+:8] , dpd[56+:8] };
assign    dpd_q_sample3 = {dpd[88+:8] , dpd[120+:8]};


integer outfile;
integer number = 0;
// 读取输入数据
initial begin
    // 修改下面文件的命名
    // 需要将dat或txt文件用vivado添加为simulation source，就无需指定相对路径，否则会在.sim\sim_1\behav\xsim下
    // 实测时发现每次还是要从xsim复制走，所以用绝对路径最好
    outfile = $fopen("D:/Documents/Matlab/for_FPGA/TB_DPD.dat", "w");

    if (outfile == 0) begin
        $display("Error: File, output file could not be opened.\nExiting Simulation.");
        $finish;
    end

    // 读取输入文件的值，16进制或2进制
    // $readmemh("input.dat", input_data, 0, MEMORY_DEPTH-1);
    // 用绝对路径最好，相对路径添加source后就会被复制到xsim文件夹下，后面在matlab里修改没用
    $readmemb("D:/Documents/Matlab/for_FPGA/TB_DAC.dat", dac_data, 0, MEMORY_DEPTH/4-1);
    $readmemb("D:/Documents/Matlab/for_FPGA/TB_LUT.dat", lut_data, 0, LUT_DEPTH*(M+1)-1);

    // 将Data_out写入文件
    @(coeff_addr == LUT_DEPTH*(M+1) - 1);
    # 100
    while(number != MEMORY_DEPTH/4) begin
        @(posedge JESD_clk) begin
                // 注意是fdisplay不是display
                $fdisplay (outfile, "%b", dpd);
                number = number + 1;
        end
    end


    // 等待1ms
    #1000
    $display("Simulation Ended Normally at Time: %t", $realtime);
    $fclose(outfile);
    $finish;
end

initial begin
@(coeff_addr == LUT_DEPTH*(M+1) - 1);
while(1)
  @(posedge JESD_clk) begin
    dac         <= dac_data[counter_dac];
    counter_dac     <= counter_dac + 1;
end
end


initial begin
lut = lut_data[0];
#100 
while(coeff_addr != LUT_DEPTH*(M+1) - 1) begin
    @(posedge AXI_clk) begin
        lut = lut_data[coeff_addr]; 
        coeff_addr = coeff_addr + 1'b1;
        coeff_en = 1'b1;
    end
end 

end


MP_LUT_wrapper #(
    .M          (M),
    .RESOLUTION (LUT_DEPTH)
)
DUT(
    .JESD_clk_i     (JESD_clk),
    .AXI_clk_i      (AXI_clk),
    .reset_i        (reset),
    .coeff_i        (lut),
    .coeff_addr_i   ({coeff_addr, 2'b0}),
    .coeff_en_i     (coeff_en),
    .dac_i          (dac),
    .vio_wdpd_i     (1'b1),
    .LED_OVF        (),
    .data_o         (dpd),
    .sample0_i_ila  (),
    .sample0_r_ila  ()
);


endmodule