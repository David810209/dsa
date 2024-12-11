
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
//weight data
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
        if(we_i && addr_i == 32'hC410_0000 && !written)begin
            weight_data[load_weight_cnt] <= data_i;
            load_weight_cnt <= load_weight_cnt + 1;
            written <= 1;
        end
        else if(!we_i)begin
        written <= 0;
    end
    end
    
end

reg data_valid;
wire result_valid;
(* keep = "true",  mark_debug = "true" *)reg [XLEN-1:0] feeder_dataA;
reg [XLEN-1:0] feeder_dataB;
reg [XLEN-1:0] feeder_dataC;
wire [XLEN-1:0] fp_result_data;
reg [XLEN-1:0] result_reg;
reg [4:0] calculation_cnt;
reg next_data;

always @(posedge clk_i)
begin
    if(rst_i)begin
        feeder_dataA <= 0;
        feeder_dataB <= 0;
        feeder_dataC <= 0;
        data_valid <= 0;
        calculation_cnt <= 0;
        next_data <= 0;
    end
    else if(en_i)begin
        if(calculation_cnt == total_weight)begin
            calculation_cnt <= 0;
        end
        else if(we_i && addr_i == 32'hC420_0000 && !data_valid)begin
            feeder_dataA <= weight_data[calculation_cnt];
            feeder_dataB <= data_i;
            feeder_dataC <= result_reg;
            data_valid <= 1;
            calculation_cnt <= calculation_cnt + 1;
        end
        else if(we_i && addr_i == 32'hC450_0000)begin
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

//for FP add
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
        if(addr_i == 32'hC430_0000 && !add_data_valid)begin
            dataA <= result_reg;
            dataB <= data_i;
            add_data_valid <= 1;
        end
        else if(addr_i == 32'hC430_0014)begin
            dataA <= data_i;
        end
        else if(addr_i == 32'hC430_0018 && !add_data_valid)begin
            dataB <= data_i;
            add_data_valid <= 1;
        end
    end
    else if(add_data_valid) begin
        add_data_valid <= 0;
    end
end

//for FP mux
reg [XLEN-1:0] mux_dataA;
reg [XLEN-1:0] mux_dataB;
wire [XLEN-1:0] mux_result_data;
wire mux_result_valid;
reg mux_data_valid;
reg [XLEN-1:0] mux_result_reg;

always @(posedge clk_i)
begin
    if(rst_i)begin
        mux_dataA <= 0;
        mux_dataB <= 0;
        mux_data_valid <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0008)begin
        mux_dataA <= data_i;
    end
    else if(en_i && we_i && addr_i == 32'hC430_000c && !mux_data_valid)begin
        mux_dataB <= data_i;
        mux_data_valid <= 1;
    end
    else if(mux_data_valid) begin
        mux_data_valid <= 0;
    end
end



reg send;
always @(posedge clk_i)
begin
    if(rst_i)begin
        result_reg <= 0;
        add_result_reg <= 0;
        data_o <= 0;
        send <= 0;
    end
    else if(result_valid)begin
        result_reg <= fp_result_data;
        send <= 0;
    end
    else if(add_result_valid)begin
        add_result_reg <= add_result_data;
        send <= 0;
    end
    else if(mux_result_valid)begin
        mux_result_reg <= mux_result_data;
        send <= 0;
    end
    else if(!we_i && (addr_i == 32'hC430_0004) && send == 0)begin
            result_reg <= 0;
            data_o <= add_result_reg;
            send <= 1;
    end
    else if(!we_i && (addr_i == 32'hC430_0010) && send == 0)begin
            data_o <= mux_result_reg;
            send <= 1;
    end
    else if(!we_i && (addr_i == 32'hC470_0000) && send == 0)begin
            result_reg <= 0;
            data_o <= result_reg;
            send <= 1;
    end
end



reg [2:0] S, S_next;
localparam S_IDLE = 0, S_LOAD_WEIGHT = 1, S_CALC = 2, S_CALC_ADD = 3, S_CALC_MUX = 4;

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
            else if(data_valid)begin
                S_next = S_CALC;
            end
            else if(add_data_valid)begin
                S_next = S_CALC_ADD;
            end
            else if(mux_data_valid) begin
                S_next = S_CALC_MUX;
            end
        end
        S_LOAD_WEIGHT:begin
            if(load_weight_cnt == total_weight)begin
                S_next = S_IDLE;
            end
        end
        S_CALC:begin
            if(result_valid)begin
                S_next = S_IDLE;
            end
        end
        S_CALC_ADD:begin
            if(add_data_valid)begin
                S_next = S_IDLE;
            end
        end
        S_CALC_MUX:begin
            if(mux_data_valid)begin
                S_next = S_IDLE;
            end
        end
    endcase
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


FP_ADD fp_add(
    .s_axis_a_tvalid(add_data_valid),
    .s_axis_a_tdata(dataA),
    .s_axis_b_tvalid(add_data_valid),
    .s_axis_b_tdata(dataB),

    .m_axis_result_tvalid(add_result_valid),
    .m_axis_result_tdata(add_result_data)
);

FP_MUX fpmux(
    .aclk(clk_i),
    .s_axis_a_tvalid(mux_data_valid),
    .s_axis_a_tdata(mux_dataA),
    .s_axis_b_tvalid(mux_data_valid),
    .s_axis_b_tdata(mux_dataB),

    .m_axis_result_tvalid(mux_result_valid),
    .m_axis_result_tdata(mux_result_data)
);

endmodule