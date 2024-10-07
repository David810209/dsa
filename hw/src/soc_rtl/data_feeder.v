
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
    output                  data_ready_o,
    output reg [XLEN-1 : 0]     data_o,

    // Floating point unit signals
    input                   result_valid_i,
    input [XLEN-1 : 0]      result_data_i,
    output reg              valid_o,
    output reg [XLEN-1 : 0] dataA_o,
    output reg [XLEN-1 : 0] dataB_o,
    output reg [XLEN-1 : 0] dataC_o
);

reg wait_output_flag;
reg out_ready;
reg inA_ready;
reg inB_ready;
reg inC_ready;
assign data_ready_o = inA_ready | inB_ready | inC_ready | out_ready;

reg calculating_flag;



always @(posedge clk_i)
begin
    if(rst_i)begin
        out_ready <= 0;
        wait_output_flag <= 0;
        calculating_flag <= 0;  
    end
    else if(valid_o)begin
        calculating_flag <= 1;
    end
    else if(calculating_flag && result_valid_i)begin
        wait_output_flag <= 1;
        calculating_flag <= 0;
    end

    else if(wait_output_flag && addr_i == 32'hC430_0000)begin
        out_ready <= 1;
        wait_output_flag <= 0;
    end

    else if(out_ready)begin
        out_ready <= 0;
    end
    data_o <= result_data_i;
end

always @(posedge clk_i)
begin
    if(rst_i)begin
        dataA_o <= 32'b0;
        dataB_o <= 32'b0;
        dataC_o <= 32'b0;
        valid_o <= 1'b0;
        inA_ready <= 1'b0;
        inB_ready <= 1'b0;
        inC_ready <= 1'b0;
    end
    else if(en_i && we_i)begin
        if(addr_i == 32'hC400_0000)begin
            dataA_o <= data_i;
            inA_ready <= 1'b1;
        end
        else if(addr_i == 32'hC410_0000)begin
            dataB_o <= data_i;
            inB_ready <= 1'b1;
        end
        else if(addr_i == 32'hC420_0000)begin
            dataC_o <= data_i;
            inC_ready <= 1'b1;
            valid_o <= 1'b1;
        end
    end
    else if(valid_o)begin
        valid_o <= 1'b0;
        inA_ready <= 1'b0;
        inB_ready <= 1'b0;
        inC_ready <= 1'b0;
    end
    else begin
        inA_ready <= 0;
        inB_ready <= 0;
        inC_ready <= 0;
    end
end

//profiler
(* mark_debug = "true" *) reg [32-1 : 0] data_input_cycle;
(* mark_debug = "true" *) reg [32-1 : 0] data_result_cycle;
(* mark_debug = "true" *) reg [32-1 : 0] data_cal_cycle;

always @(posedge clk_i)begin
    if(rst_i)begin
        data_input_cycle <= 32'b0;
        data_cal_cycle <= 32'b0;
        data_result_cycle <= 32'b0;
    end
    else begin
        if(en_i && we_i && (addr_i == 32'hC400_0000 || addr_i == 32'hC410_0000  || addr_i == 32'hC420_0000 ))begin
            data_input_cycle <= data_input_cycle + 1;
        end
        else if(calculating_flag) begin
            data_cal_cycle <= data_cal_cycle + 1;
        end
        else if(wait_output_flag) begin
            data_result_cycle <= data_result_cycle + 1;
        end
    end
end


endmodule