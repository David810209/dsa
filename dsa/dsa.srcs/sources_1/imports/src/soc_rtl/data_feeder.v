
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

(* keep = "true",  mark_debug = "true" *) reg data_valid;
(* keep = "true",  mark_debug = "true" *) reg next_data;
(* keep = "true",  mark_debug = "true" *) wire result_valid;
(* keep = "true",  mark_debug = "true" *) reg [XLEN-1:0] feeder_dataA;
(* keep = "true",  mark_debug = "true" *)reg [XLEN-1:0] feeder_dataB;
(* keep = "true",  mark_debug = "true" *)reg [XLEN-1:0] feeder_dataC;
(* keep = "true",  mark_debug = "true" *)wire [XLEN-1:0] fp_result_data;
(* keep = "true",  mark_debug = "true" *)reg [XLEN-1:0] result_reg;

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
        if(we_i && addr_i == 32'hC410_0000)begin
            feeder_dataA <= data_i;
            next_data <= 1;
        end
        else if(we_i && addr_i == 32'hC420_0000)begin
            feeder_dataB <= data_i;
            feeder_dataC <= result_reg;
            data_valid <= 1;
        end
    end
    else if(data_valid) begin
            next_data <= 0;
            data_valid <= 0;
    end
end

reg [1:0] S, S_next;
localparam S_IDLE = 2'b00, S_CALC = 2'b01;

always @(posedge clk_i)
begin
    if(rst_i)begin
        S <= S_IDLE;
    end
    else begin
        S <= S_next;
    end
end

always @(*)
begin
    S_next = S;
    case(S)
        S_IDLE:begin
            if(data_valid && next_data)begin
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
    else if(!we_i && addr_i == 32'hC430_0000 && send == 0)begin
            result_reg <= 0;
            data_o <= result_reg;
            send <= 1;
    end
end
//assign ready_o = S == S_IDLE;

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