
`timescale 1ns / 1ps

`include "aquila_config.vh"

module pooling_layer #(
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
    output reg [XLEN-1 : 0]     data_o,

    input [5:0]             in_width,
    input [5:0]             in_depth
);

////////////////////////////////////////////
//FSM management
/////////////////////////////////////////////////
reg [2:0] S, S_next;
localparam S_IDLE = 0,S_SEND_IN = 1, S_ACCUM_IN = 2,S_ACCUM = 3,  S_MUL = 4, S_RESULT = 5;

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
            if(we_i)begin
                S_next = S_SEND_IN;
            end
        end
        S_SEND_IN:begin
            if(load_i_img_cnt == in_size)begin
                S_next = S_ACCUM_IN;
            end
        end
        S_ACCUM_IN:begin
            if(inner_cnt == 3)begin
                S_next = S_ACCUM;
            end
        end
        S_ACCUM:begin
            if(accum_result_tlast)begin
                S_next = S_MUL;
            end
        end
        S_MUL:begin
            if(out_idx == out_size)begin
                S_next = S_RESULT;
            end
            else if(mul_result_valid)begin
                S_next = S_ACCUM_IN;
            end
        end
        S_RESULT:begin
            if(output_img_cnt == out_size - 1)begin
                S_next = S_IDLE;
            end
        end
    endcase
end

assign ready_o = S == S_IDLE || S == S_RESULT;

wire [15:0] in_size = in_width * in_width * in_depth;
wire [15:0] out_size = in_size / 4;

wire [5:0] out_width = in_width / 2;

////////////////////////////////////////////
//load image data
/////////////////////////////////////////////////

reg [15:0] load_i_img_cnt;
(* ram_style="block" *) reg [XLEN-1:0] i_img[2047:0];
always @(posedge clk_i) begin
    if(rst_i)begin
        load_i_img_cnt <= 0;
    end
    else if(we_i)begin
            i_img[load_i_img_cnt] <= data_i;
            load_i_img_cnt <= load_i_img_cnt + 1;
    end
    else  if(load_i_img_cnt == in_size)begin
            load_i_img_cnt <= 0;
        end
end

////////////////////////////////////////////
//output image data
/////////////////////////////////////////////////
(* ram_style="block" *)  reg [XLEN-1:0] o_img[511:0];  
reg [15:0] output_img_cnt;
reg [15:0] out_idx;

always @(posedge clk_i) begin
    if(rst_i)begin
        out_idx <= 0;
    end
    else if(S == S_IDLE)begin
        out_idx <= 0;
    end
    else if(S == S_MUL)begin
        if(mul_result_valid)begin
            o_img[out_idx] <= mul_result_data;
            out_idx <= out_idx + 1;
        end
    end
end
////////////////////////////////////////////
//pooling calculation
/////////////////////////////////////////////////
//FP ACCUM IP
reg [XLEN-1:0] accum_dataA ;
wire [XLEN-1:0] accum_result_data;
reg [XLEN-1:0] accum_result_reg;
wire accum_result_valid;
reg accum_data_valid;
reg accum_tlast;
wire accum_result_tlast;
reg [15:0] img_idx;
reg [2:0] inner_cnt;
reg [5:0] i_idx;

//FP MUL CALCULATOR
reg [XLEN-1:0] mul_dataA;
reg [XLEN-1:0] mul_dataB;
wire [XLEN-1:0] mul_result_data;
wire mul_result_valid;
reg mul_data_valid;

always @(posedge clk_i)
begin
    if(rst_i)begin
        accum_dataA <= 0;
        accum_data_valid <= 0;
        img_idx <= 0;
        accum_tlast <= 0;
        mul_data_valid <= 0;
        inner_cnt <= 0;
        i_idx <= 0;
        accum_result_reg <= 0;
    end
    else if(S == S_IDLE)begin
        i_idx <= 0;
        img_idx <= 0;
    end
    else if(S == S_ACCUM_IN)begin
        if(inner_cnt == 0)begin
            accum_dataA <= i_img[img_idx];
            accum_data_valid <= 1;
            inner_cnt <= 1;
        end
        else if(inner_cnt == 1)begin
            accum_dataA <= i_img[img_idx + 1];
            inner_cnt <= 2;
        end
        else if(inner_cnt == 2)begin
            accum_dataA <= i_img[img_idx + in_width];
            inner_cnt <= 3;
        end
        else if(inner_cnt == 3)begin
            accum_dataA <= i_img[img_idx + in_width + 1];
            accum_tlast <= 1;
            inner_cnt <= 0;
            if(i_idx == out_width - 1)begin
                img_idx <= img_idx + in_width + 2 >= in_size ? 0 : img_idx + in_width + 2;
                i_idx <= 0;
            end
            else begin
                i_idx <= i_idx + 1;
                img_idx <= img_idx + 2 >= in_size ? 0 : img_idx + 2;
            end
        end
    end
    else if(S == S_ACCUM)begin
        if(accum_result_tlast) accum_result_reg <= accum_result_data;
         if(accum_tlast) accum_tlast <= 0;
         if(accum_data_valid) accum_data_valid <= 0;
    end
    else if(S == S_MUL)begin
        if(!mul_data_valid && !mul_result_valid)begin
            mul_dataA <= accum_result_reg;
            mul_dataB <= 32'h3E800000; //0.25
            mul_data_valid <= 1;
        end
    end
    if(mul_data_valid)begin
            mul_data_valid <= 0;
        end
end

////////////////////////////////////////////
//result management
/////////////////////////////////////////////////
wire done = S == S_RESULT;
reg send;
always @(posedge clk_i)
begin
    if(rst_i)begin
        data_o <= 0;
        send <= 0;
        output_img_cnt <= 0;
    end
    else if(en_i && !we_i && addr_i == 32'hC420_0004)begin
        data_o <= done;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC420_0000 && send == 0))begin
            data_o <= o_img[output_img_cnt];
            if(output_img_cnt == out_size - 1)begin
                output_img_cnt <= 0;
            end
            else begin
            output_img_cnt <= output_img_cnt + 1;
            send <= 1;
            end
    end
    else if(send)begin
        send <= 0;
    end
end

////////////////////////////////////////////
//fIP Management
/////////////////////////////////////////////////
//FP ACCUM IP
FP_ACCUM fpaccum(
    .aclk(clk_i),
    .s_axis_a_tvalid(accum_data_valid),
    .s_axis_a_tdata(accum_dataA),
    .s_axis_a_tlast(accum_tlast),

    .m_axis_result_tvalid(accum_result_valid),
    .m_axis_result_tdata(accum_result_data),
    .m_axis_result_tlast(accum_result_tlast)
);
//FP MULTIPLY IP
FP_MUL fpmul(
    .aclk(clk_i),
    .s_axis_a_tvalid(mul_data_valid),
    .s_axis_a_tdata(mul_dataA),
    .s_axis_b_tvalid(mul_data_valid),
    .s_axis_b_tdata(mul_dataB),

    .m_axis_result_tvalid(mul_result_valid),
    .m_axis_result_tdata(mul_result_data)
);

endmodule
