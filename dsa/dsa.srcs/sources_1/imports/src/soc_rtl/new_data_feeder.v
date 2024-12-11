
`timescale 1ns / 1ps

`include "aquila_config.vh"

module data_feeder #(
    parameter XLEN = 32
) (
    // System signals
    input                   clk_i,
    input                   rst_i,

    // Device bus signals
    input                   en_i,
    input                   we_i,
    input [XLEN-1 : 0]      addr_i,
    input [XLEN-1 : 0]      data_i,
    output                  ready_o,
    output reg [XLEN-1 : 0]     data_o
);

/*
in soc_top.v
data_feeder Data_Feeder
(
    // System signals
    .clk_i(clk),
    .rst_i(rst),

    // Device bus signals
    .en_i(dev_strobe & dsa_sel),
    .we_i(dev_we),
    .addr_i(dev_addr),
    .data_i(dev_din),
    .ready_o(dsa_ready),
    .data_o(dsa_dout)
);
*/

/*****************************************************************
declare MMIO address
*****************************************************************
//---weight data--------------
32'hC400_0000 = trigger load weight (input weight data size)
32'hC400_0004 = weight data input
32'hC400_0008 = input image data A
32'hC400_000c = output data

//---input image data--------------
32'hC410_0000 = trigger load input image data (input image data size)
32'hC410_0004 = input image data input

//---output image data--------------
32'hC420_0000 = trigger refresh output image (output image data size)

//calculation data
32'hC430_0000 = out_.height ( = out_.weight)
32'hC430_0004 = trigger calculation

//-- simple calculation(for fully connected layer)---
32'hC450_0000 = input data A
32'hC460_0000 = input data B
32'hC470_0000 = output data 
*/


//---weight data--------------
reg [4:0] load_weight_cnt;
reg [XLEN-1:0] total_weight;
reg [XLEN-1:0] weight_data[24:0];
reg written;

integer  i;
initial begin
    for(i = 0; i < 25; i = i + 1)begin
        weight_data[i] = 0;
    end
end
always @(posedge clk_i) begin
    if(rst_i)begin
        load_weight_cnt <= 0;
        total_weight <= 0;
        written <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC400_0000) begin
        total_weight <= data_i;
        load_weight_cnt <= 0;
        written <= 0;
    end
    else if(S == S_LOAD_WEIGHT)begin
        if(load_weight_cnt == total_weight)begin
            load_weight_cnt <= 0;
        end
        else
        if(we_i && addr_i == 32'hC400_0004 && !written)begin
            weight_data[load_weight_cnt] <= data_i;
            load_weight_cnt <= load_weight_cnt + 1;
            written <= 1;
        end
        else if(!we_i)begin
        written <= 0;
    end
    end
    
end

// input image  data
/*
ppi=0
for(int i = 0;i<24;i++){
for(int j = 0;j < 24;j++){ ppi++;}
ppi += 4;
}
ppi = 676;
*/
initial begin
    for(i = 0; i < 676; i = i + 1)begin
        i_img[i] = 0;
    end
end

reg [9:0] load_i_img_cnt;
reg [XLEN-1:0] total_i_img;
reg [XLEN-1:0] i_img[675:0];
reg i_img_written;

always @(posedge clk_i) begin
    if(rst_i)begin
        load_i_img_cnt <= 0;
        total_i_img <= 0;
        i_img_written <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC410_0000) begin
        total_i_img <= data_i;
        load_i_img_cnt <= 0;
        i_img_written <= 0;
    end
    else if(S == S_LOAD_I_IMG)begin
        if(load_i_img_cnt == total_i_img)begin
            load_i_img_cnt <= 0;
        end
        else
        if(we_i && addr_i == 32'hC410_0004 && !i_img_written)begin
            i_img[load_i_img_cnt] <= data_i;
            load_i_img_cnt <= load_i_img_cnt + 1;
            i_img_written <= 1;
        end
        else if(!we_i)begin
        i_img_written <= 0;
    end
    end
    
end

//output image data
reg [9:0] load_o_img_cnt;
reg [XLEN-1:0] total_o_img;
reg [XLEN-1:0] o_img[575:0];  // 24*24
reg o_img_written;

always @(posedge clk_i) begin
    if(rst_i)begin
        total_o_img <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC420_0000) begin
        total_o_img <= data_i;
    end
    else if(S == S_RESET_O_IMG)begin
        for(i = 0; i < total_o_img; i = i + 1)begin
            o_img[i] <= 0;
        end
    end
end

reg data_valid;
wire result_valid;
reg [XLEN-1:0] feeder_dataA;
reg [XLEN-1:0] feeder_dataB;
reg [XLEN-1:0] feeder_dataC;
wire [XLEN-1:0] fp_result_data;
reg [XLEN-1:0] result_reg;
reg [4:0] calculation_cnt;
reg next_data;

reg [4:0] out_width;
reg [4:0] wx, widx;
reg [9:0] o_img_idx, i_img_idx;
integer idx, jdx, kdx;
always @(posedge clk_i)
begin
    if(rst_i)begin
        feeder_dataA <= 0;
        feeder_dataB <= 0;
        feeder_dataC <= 0;
        data_valid <= 0;
        calculation_cnt <= 0;
        next_data <= 0;
        out_width <= 0;
        wx <= 0;
        widx <= 0;
        o_img_idx <= 0;
        i_img_idx <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0000)begin
      out_width <= data_i;
      wx <= 0;
      widx <= 0;
      o_img_idx <= 0;
      i_img_idx <= 0;
    end
    else if(S == S_CALC)begin
        for(idx = 0;idx < out_width ;idx <= idx + 1)begin
            for(jdx = 0;jdx < out_width;jdx <= jdx + 1)begin

            end
        end
    end
    else begin
        if(data_valid)begin
            data_valid <= 0;
            next_data <= 0;
        end
    end
end

reg [2:0] S, S_next;
localparam S_IDLE = 3'b00, S_LOAD_WEIGHT = 3'b01, S_CALC = 3'b10, S_LOAD_I_IMG = 3'b11, S_RESET_O_IMG = 3'b100;

always @(posedge clk_i)
begin
    if(rst_i) S <= S_IDLE;
    else  S <= S_next;
end

always @(*)
begin
    S_next = S;
    case(S)
        S_IDLE:begin
            if(en_i && we_i && addr_i == 32'hC400_0000)begin
                S_next = S_LOAD_WEIGHT;
            end
            else if(en_i && we_i && addr_i == 32'hC410_0000)begin
                S_next = S_LOAD_I_IMG;
            end
            else if(en_i && we_i && addr_i == 32'hC420_0000)begin
                S_next = S_RESET_O_IMG;
            end
            else if(en_i && we_i && addr_i == 32'hC430_0000)begin
                S_next = S_CALC;
            end
        end
        S_LOAD_WEIGHT:begin
            if(load_weight_cnt == total_weight)begin
                S_next = S_IDLE;
            end
        end
        S_LOAD_I_IMG:begin
            if(load_i_img_cnt == total_i_img)begin
                S_next = S_IDLE;
            end
        end
        S_LOAD_O_IMG:begin
            if(load_o_img_cnt == total_o_img)begin
                S_next = S_IDLE;
            end
        end
        S_CALC:begin
            if(result_valid)begin
                S_next = S_IDLE;
            end
        end
    endcase
end

reg send;
always @(posedge clk_i)
begin
    if(rst_i)begin
        result_reg <= 0;
        data_o <= 0;
        send <= 0;
    end
    else if(result_valid)begin
        result_reg <= fp_result_data;
        send <= 0;
    end
    else if(!we_i && (addr_i == 32'hC430_0000 || addr_i == 32'hC470_0000) && send == 0)begin
            result_reg <= 0;
            data_o <= result_reg;
            send <= 1;
    end
end

assign ready_o = 1;

integer gen_idx;
generate
    for(gen_idx = 0; gen_idx < 25; gen_idx = gen_idx + 1)begin: gen
        floating_point_0 floating_point_0(
    .aclk(clk_i),
    .s_axis_a_tvalid(data_valid),
    .s_axis_a_tdata(feeder_dataA),

    .s_axis_b_tvalid(data_valid),
    .s_axis_b_tdata(feeder_dataB),

    .s_axis_c_tvalid(data_valid),
    .s_axis_c_tdata(feeder_dataC),

    .m_axis_result_tvalid(result_valid),
    .m_axis_result_tdata(fp_result_data)
);
    end
endgenerate



endmodule