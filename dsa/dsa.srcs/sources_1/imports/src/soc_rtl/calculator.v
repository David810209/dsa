
`timescale 1ns / 1ps

`include "aquila_config.vh"

module calculator #(
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
*/

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

always @(posedge clk_i)
begin
    if(rst_i)begin
        fma_dataA <= 0;
        fma_dataB <= 0;
        fma_dataC <= 0;
        fma_data_valid <= 0;
    end
    else if(en_i)begin
        if(we_i && addr_i == 32'hC440_0018)begin
            fma_dataA <= data_i;
        end
        else if(we_i && addr_i == 32'hC440_001c)begin
            fma_dataB <= data_i;
            fma_dataC <= result_reg;
            fma_data_valid <= 1;
        end
        else if(!we_i)begin
            fma_data_valid <= 0;
        end
    end
    else begin
        if(fma_data_valid)begin
            fma_data_valid <= 0;
        end
    end
end


////////////////////////////////////////////
//for FP add
/////////////////////////////////////////////////
reg [XLEN-1:0] dataA;
reg [XLEN-1:0] dataB;
wire [XLEN-1:0] add_result_data;
wire add_result_valid;
reg add_data_valid;
reg [XLEN-1:0] add_result_reg;

always @(posedge clk_i)
begin
    if(rst_i)begin
        dataA <= 0;
        dataB <= 0;
        add_data_valid <= 0;
    end
    else if(en_i && we_i)begin
        if(addr_i == 32'hC440_0000)begin
            dataA <= data_i;
        end
        else if(addr_i == 32'hC440_0004 && !add_data_valid)begin
            dataB <= data_i;
            add_data_valid <= 1;
        end
    end
    else if(add_data_valid) begin
        add_data_valid <= 0;
    end
end

////////////////////////////////////////////
//for FP multiply
/////////////////////////////////////////////////
reg [XLEN-1:0] mul_dataA;
reg [XLEN-1:0] mul_dataB;
wire [XLEN-1:0] mul_result_data;
wire mul_result_valid;
reg mul_data_valid;
reg [XLEN-1:0] mul_result_reg;

always @(posedge clk_i)
begin
    if(rst_i)begin
        mul_dataA <= 0;
        mul_dataB <= 0;
        mul_data_valid <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC440_000c)begin
        mul_dataA <= data_i;
    end
    else if(en_i && we_i && addr_i == 32'hC440_0010 && !mul_data_valid)begin
        mul_dataB <= data_i;
        mul_data_valid <= 1;
    end
    else if(mul_data_valid) begin
        mul_data_valid <= 0;
    end
end
////////////////////////////////////////////
//result management
/////////////////////////////////////////////////
reg send;
always @(posedge clk_i)
begin
    if(rst_i)begin
        result_reg <= 0;
        add_result_reg <= 0;
        mul_result_reg <= 0;
        data_o <= 0;
        send <= 0;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0008) && send == 0)begin
            result_reg <= 0;
            data_o <= add_result_valid ? add_result_data :  add_result_reg;
            send <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0014) && send == 0)begin
            data_o <= mul_result_reg;
            send <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0020) && send == 0)begin
            result_reg <= 0;
            data_o <= result_reg;
            send <= 1;
    end
    else if(send)begin
        send <= 0;
    end
    if(fma_result_valid)begin
        result_reg <= fma_result_data;
        send <= 0;
    end
    if(add_result_valid)begin
        add_result_reg <= add_result_data;
        send <= 0;
    end
    if(mul_result_valid)begin
        mul_result_reg <= mul_result_data;
        send <= 0;
    end
end

assign ready_o = 1;

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


// FP ADD IP
FP_ADD fp_add(
    .aclk(clk_i),
    .s_axis_a_tvalid(add_data_valid),
    .s_axis_a_tdata(dataA),
    .s_axis_b_tvalid(add_data_valid),
    .s_axis_b_tdata(dataB),

    .m_axis_result_tvalid(add_result_valid),
    .m_axis_result_tdata(add_result_data)
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
