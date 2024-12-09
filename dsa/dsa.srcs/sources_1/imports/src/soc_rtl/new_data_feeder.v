
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

//weight data
reg [4:0] load_weight_cnt;
reg [XLEN-1:0] total_weight;
reg [XLEN-1:0] weight_data[24:0];
initial begin
    integer  i;
    for(i = 0; i < 25; i = i + 1)begin
        weight_data[i] = 0;
    end
end
always @(posedge clk_i) begin
    if(rst_i)begin
        load_weight_cnt <= 0;
        total_weight <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC400_0000) begin
        total_weight <= data_i;
    end
    else if(S == S_LOAD_WEIGHT)begin
        if(load_weight_cnt == total_weight)begin
            load_weight_cnt <= 0;
        end
        else
        if(we_i && addr_i == 32'hC410_0000)begin
            weight_data[load_weight_cnt] <= data_i;
            load_weight_cnt <= load_weight_cnt + 1;
        end
    end
end



reg [1:0] S, S_next;
localparam S_IDLE = 2'b00, S_LOAD_WEIGHT = 2'b01, S_CALC = 2'b10;

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
    endcase
end


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