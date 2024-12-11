
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

reg data_valid;
wire result_valid;
reg [XLEN-1:0] feeder_dataA;
reg [XLEN-1:0] feeder_dataB;
reg [XLEN-1:0] feeder_dataC;
wire [XLEN-1:0] fp_result_data;
reg [XLEN-1:0] result_reg;
reg next_data;

always @(posedge clk_i)
begin
    if(rst_i)begin
        feeder_dataA <= 0;
        feeder_dataB <= 0;
        feeder_dataC <= 0;
        data_valid <= 0;
        next_data <= 0;
    end
    else if(en_i)begin
        if(we_i && addr_i == 32'hC450_0000)begin
            feeder_dataA <= data_i;
            next_data <= 1;
        end
        else if(we_i && addr_i == 32'hC460_0000)begin
            feeder_dataB <= data_i;
            feeder_dataC <= result_reg;
            data_valid <= 1;
        end
        else if(!we_i)begin
            data_valid <= 0;
        end
    end
    else begin
        if(data_valid)begin
            data_valid <= 0;
            next_data <= 0;
        end
    end
end

reg [1:0] S, S_next;
localparam S_IDLE = 2'b00,  S_CALC = 2'b01;

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
            if(data_valid)begin
                S_next = S_CALC;
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
    else if(!we_i && (addr_i == 32'hC470_0000) && send == 0)begin
            result_reg <= 0;
            data_o <= result_reg;
            send <= 1;
    end
end


assign ready_o = 1;
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


endmodule