
`timescale 1ns / 1ps

`include "aquila_config.vh"

module cnn_top #(
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
    output [XLEN-1 : 0]     data_o
);

/*
in soc_top.v
cnn_top cnn_top
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
*/

wire conv_top_en = (addr_i[31:20] == 12'hC43) && en_i;
wire calculator_en = (addr_i[31:20] == 12'hC44)&& en_i; 
assign ready_o = S == S_CONV ? conv_ready : calculator_ready;
assign data_o = S == S_CONV ?  conv_data : calculator_data;
reg [2:0] S, S_next;
localparam S_CONV = 0, S_CALCULATOR = 1;
always @(posedge clk_i)
begin
    if(rst_i) S <= S_CONV;
    else  S <= S_next;
end

always @(*)
begin
    S_next = S;
    case(S)
        S_CONV: begin
            if(calculator_en) S_next = S_CALCULATOR;
        end
        S_CALCULATOR: begin
            if(conv_top_en) S_next = S_CONV;
        end
    endcase
end

wire conv_ready;
wire [XLEN-1 : 0] conv_data;
conv_layer conv_layer
(
    // System signals
    .clk_i(clk_i),
    .rst_i(rst_i),

    // Device bus signals
    .en_i(conv_top_en),
    .we_i(we_i),
    .addr_i(addr_i),
    .data_i(data_i),
    .ready_o(conv_ready),
    .data_o(conv_data)
);

wire calculator_ready;
wire [XLEN-1 : 0] calculator_data;
calculator calculator
(
    // System signals
    .clk_i(clk_i),
    .rst_i(rst_i),

    // Device bus signals
    .en_i(calculator_en),
    .we_i(we_i),
    .addr_i(addr_i),
    .data_i(data_i),
    .ready_o(calculator_ready),
    .data_o(calculator_data)
);

endmodule
