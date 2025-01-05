
`timescale 1ns / 1ps

`include "aquila_config.vh"

module fully_layer #(
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

/*****************************************************************
declare MMIO address
*****************************************************************
//conv layer
//calculation data
32'hC430_0000 = in_.width
32'hC430_0004 = out_.width
32'hC430_0008 = weight_width
32'hC430_000c = trigger calculation & check calculation done
32'hc430_0010 = in_.depth
32'hc430_0014 = out_.depth
//---weight data--------------
32'hC430_0018 = trigger load weight
32'hC430_001c = weight data input
//---input image data--------------
32'hC430_0020 = trigger load input image data
32'hC430_0024 = input image data input
//---output image data--------------
32'hC430_0028 = trigger refresh output image (output image data size)
32'hC430_002c = return calculation result

//-- simple calculation(for other layer)---
//ADD (pooling layer)
32'hC440_0000 = input data A
32'hC440_0004 = input data B
32'hC440_0008 = output data

//MUL (pooling layer)
32'hC440_000c = input data A
32'hC440_0010 = input data B
32'hC440_0014 = output data

//FMA (fully layer)
32'hC440_0018 = input data A
32'hC440_001c = input data B 
32'hC440_0020 = output data 

//new 
32'hC410_0000 = trigger load weight
32'hC410_0004 = weight data input
32'hC410_0008 = trigger load bias
32'hC410_000c = bias data input
32'hC410_0010 = trigger calculation
32'hC410_0014 = return calculation result
32'hC410_0018 = trigger load input image data
32'hC410_001c = input image data input
*/

////////////////////////////////////////////
//FSM management
/////////////////////////////////////////////////
reg [2:0] S, S_next;
localparam S_IDLE = 0, S_LOAD_WEIGHT = 1, S_FMA = 2, S_FMA_RESULT = 3 ,S_RELU =4, 
                    S_COMP = 5, S_RESULT = 6, S_LOAD_I_IMG = 7;

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
            if(en_i && we_i && addr_i == 32'hC410_0000) begin
                S_next = S_LOAD_WEIGHT;
            end
            else if(en_i && we_i && addr_i == 32'hC410_0018) begin
                S_next = S_LOAD_I_IMG;
            end
            else if(en_i && we_i && addr_i == 32'hC410_0010) begin
                S_next = S_FMA;
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
        S_FMA:begin
            S_next = S_FMA_RESULT;
        end
        S_FMA_RESULT:begin
           
            if(fma_result_valid)begin
                 if(img_idx == total_i_img)begin
                    S_next = S_RELU;
                end
                else begin
                    S_next = S_FMA;
                end
            end
        end
        S_RELU:begin
            if(comp_data_valid)begin
                S_next = S_COMP;
            end
        end
        S_COMP:begin
            if(curr_idx == 0)begin
                S_next = S_FMA;
            end
            else if(comp_result_valid2)begin
                if(curr_idx == 9)begin
                    S_next = S_RESULT;
                end
                else begin
                    S_next = S_FMA;
                end
            end
        end
        S_RESULT:begin
            if(en_i &&  !we_i && (addr_i == 32'hC410_0014))begin
                S_next = S_IDLE;
            end
        end
    endcase
end
////////////////////////////////////////////
//load weight data
/////////////////////////////////////////////////
reg [15:0] load_weight_cnt;
reg [15:0] total_weight;
(* ram_style="block" *) reg [XLEN-1:0] weight_data[5120:0];

always @(posedge clk_i) begin
    if(rst_i)begin
        load_weight_cnt <= 0;
        total_weight <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC410_0000) begin
        total_weight <= data_i;
        load_weight_cnt <= 0;
    end
    else if(S == S_LOAD_WEIGHT)begin
        if(load_weight_cnt == total_weight)begin
            load_weight_cnt <= 0;
        end
        else
        if(en_i && we_i && addr_i == 32'hC410_0004)begin
            weight_data[load_weight_cnt] <= data_i;
            load_weight_cnt <= load_weight_cnt + 1;
        end
    end
end
////////////////////////////////////////////
//load image data
/////////////////////////////////////////////////

reg [15:0] load_i_img_cnt;
reg [15:0] total_i_img;
(* ram_style="block" *) reg [XLEN-1:0] i_img[512:0];

always @(posedge clk_i) begin
    if(rst_i)begin
        load_i_img_cnt <= 0;
        total_i_img <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC410_0018) begin
        total_i_img <= data_i;
        load_i_img_cnt <= 0;
    end
    else if(S == S_LOAD_I_IMG)begin
        if(load_i_img_cnt == total_i_img)begin
            load_i_img_cnt <= 0;
        end
        else
        if(en_i && we_i && addr_i == 32'hC410_001c)begin
            i_img[load_i_img_cnt] <= data_i;
            load_i_img_cnt <= load_i_img_cnt + 1;
        end
    end
    
end


////////////////////////////////////////////
//for FMA data feeding
/////////////////////////////////////////////////
reg fma_data_valid;
wire fma_result_valid;
reg [XLEN-1:0] fma_dataA;
reg [XLEN-1:0] fma_dataB;
reg [XLEN-1:0] fma_dataC;
wire [XLEN-1:0] fma_result_data;
reg [XLEN-1:0] result_reg;

wire [XLEN-1:0] cmp_data = (comp_result_data) ? 0 : result_reg;
reg [XLEN-1:0] curr_max_data;
reg [5:0] curr_max_idx;

reg [15:0] img_idx;
reg [15:0] weight_idx;
reg [5:0] curr_idx;

always @(posedge clk_i)
begin
    if(rst_i)begin
        fma_dataA <= 0;
        fma_dataB <= 0;
        fma_dataC <= 0;
        fma_data_valid <= 0;
        img_idx <= 0;
        weight_idx <= 0;
        result_reg <= 0;
    end
    else if(S == S_FMA)begin
        fma_dataA <= i_img[img_idx];
        fma_dataB <= weight_data[weight_idx];
        fma_dataC <= result_reg;
        fma_data_valid <= 1;
        img_idx <= img_idx + 1;
        weight_idx <= weight_idx + 1;
    end
    else if(S == S_FMA_RESULT)begin
        if(fma_result_valid)begin
            result_reg <= fma_result_data;
        end
    end
    else if(comp_result_valid2)begin
        img_idx <= 0;
        result_reg <= 0;
    end
    if(fma_data_valid)begin
            fma_data_valid <= 0;
    end
end

//relu calculation
reg [XLEN-1:0] comp_dataA;
reg [XLEN-1:0] comp_dataB;
wire [7:0] comp_result_data;
reg comp_data_valid;
wire comp_result_valid;

always @(posedge clk_i) begin
    if(rst_i)begin
        comp_dataA <= 0;
        comp_dataB <= 0;
        comp_data_valid <= 0;
    end
    else if(S == S_RELU)begin
        comp_dataA <= result_reg;
        comp_dataB <= 0;
        comp_data_valid <= 1;
    end
    if(comp_data_valid)begin
            comp_data_valid <= 0;
    end
end

//compare calculation
reg [XLEN-1:0] comp_dataA2;
reg [XLEN-1:0] comp_dataB2;
wire [7:0] comp_result_data2;
reg comp_data_valid2;
wire comp_result_valid2;

always @(posedge clk_i)
begin
    if(rst_i)begin
        comp_dataA2 <= 0;
        comp_dataB2 <= 0;
        comp_data_valid2 <= 0;
        curr_max_data <= 0;
        curr_max_idx <= 0;
        curr_idx <= 0;
    end
    else if(S == S_COMP)begin
        if(curr_idx == 0)begin
            curr_max_data <= cmp_data;
            curr_max_idx <= 0;
            curr_idx <= curr_idx + 1;
        end
        else if(comp_result_valid)begin
            comp_dataA2 <= cmp_data;
            comp_dataB2 <= curr_max_data;
            comp_data_valid2 <= 1;
        end
        else if(comp_result_valid2)begin
            if(comp_result_data2)begin
                curr_max_data <= cmp_data;
                curr_max_idx <= curr_idx;
            end
            curr_idx <= curr_idx + 1;
        end
    end
    if(comp_data_valid2)begin
            comp_data_valid2 <= 0;
        end
end

////////////////////////////////////////////
//result management
/////////////////////////////////////////////////
reg send;
always @(posedge clk_i)
begin
    if(rst_i)begin
        data_o <= 0;
        send <= 0;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC410_0014) && send == 0)begin
            data_o <= curr_max_idx;
            send <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC410_0010) && send == 0)begin
            data_o <= S == S_RESULT;
            send <= 1;
    end
    else if(send)begin
        send <= 0;
    end
end

assign ready_o = S == S_RESULT || S == S_IDLE  || S == S_LOAD_WEIGHT || S == S_LOAD_I_IMG;

////////////////////////////////////////////
//fIP Management
/////////////////////////////////////////////////
// FMA IP
FP_FMA fma(
    .aclk(clk_i),
    .s_axis_a_tvalid(fma_data_valid),
    .s_axis_a_tdata(fma_dataA),

    .s_axis_b_tvalid(fma_data_valid),
    .s_axis_b_tdata(fma_dataB),

    .s_axis_c_tvalid(fma_data_valid),
    .s_axis_c_tdata(fma_dataC),

    .m_axis_result_tvalid(fma_result_valid),
    .m_axis_result_tdata(fma_result_data)
);

//FP COMPARE IP (LESS THAN)
FP_COMP fpcomp(
    .aclk(clk_i),
    .s_axis_a_tvalid(comp_data_valid),
    .s_axis_a_tdata(comp_dataA),

    .s_axis_b_tvalid(comp_data_valid),
    .s_axis_b_tdata(comp_dataB),


    .m_axis_result_tvalid(comp_result_valid),
    .m_axis_result_tdata(comp_result_data)
);

//FP COMPARE IP (GREATER THAN)
FP_COMP_GREATER fpcomp2(
    .aclk(clk_i),
    .s_axis_a_tvalid(comp_data_valid2),
    .s_axis_a_tdata(comp_dataA2),

    .s_axis_b_tvalid(comp_data_valid2),
    .s_axis_b_tdata(comp_dataB2),


    .m_axis_result_tvalid(comp_result_valid2),
    .m_axis_result_tdata(comp_result_data2)
);

endmodule
