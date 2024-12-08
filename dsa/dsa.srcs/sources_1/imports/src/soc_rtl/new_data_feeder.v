`timescale 1ns / 1ps

`include "aquila_config.vh"

module data_feeder #(
    parameter XLEN = 32, BUFFER_LEN = 8
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
    output reg [XLEN-1 : 0] data_o
);

reg [1:0] S, S_next;
localparam S_IDLE = 2'b00, S_LOAD = 2'b01, S_WAIT = 2'b10;

reg [31:0] total_data_num;
reg [31:0] curr_data_num;
reg [$clog2(BUFFER_LEN)-1:0] write_addr; // 增加处理逻辑
reg [$clog2(BUFFER_LEN)-1:0] curr_read_addr;

// 状态机：总控
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) S <= S_IDLE;
    else S <= S_next;
end
// 0xC400_0000 : start pointer (total_data_num)
// 0xC410_0000 : data pointer (send data1)
// 0xC420_0000 : data pointer (send data2)
// 0xC430_0000 : end pointer (get result data)
always @(*) begin
    S_next = S;
    case (S)
        S_IDLE: begin
            if (en_i && we_i && addr_i == 32'hC400_0000) S_next = S_LOAD;
        end
        S_LOAD: begin
            if (curr_data_num == total_data_num) S_next = S_WAIT;
        end
        S_WAIT: begin
            if (en_i && ~we_i && addr_i == 32'hC430_0000) S_next = S_IDLE;
        end
        default: S_next = S_IDLE;
    endcase
end

// 写入 total_data_num
always @(posedge clk_i) begin
    if (rst_i) total_data_num <= 0;
    else if (en_i && we_i && addr_i == 32'hC400_0000) total_data_num <= data_i;
end

// 管理 write_addr
always @(posedge clk_i) begin
    if (rst_i) begin
        write_addr <= 0;
    end else if (en_i && we_i && (addr_i == 32'hC410_0000 || addr_i == 32'hC420_0000)) begin
        write_addr <= write_addr + 1; // 每次写入递增
        if (write_addr == BUFFER_LEN - 1) begin
            write_addr <= 0; // 环形缓冲
        end
    end
end

// 缓冲区
wire [XLEN-1:0] b1_data_o;
wire [XLEN-1:0] b2_data_o;

distri_ram #(.ENTRY_NUM(BUFFER_LEN), .XLEN(XLEN))
buffer_1 (
    .clk_i(clk_i),
    .we_i((addr_i == 32'hC410_0000) && en_i && we_i),
    .write_addr_i(write_addr), // 使用 write_addr 写入地址
    .read_addr_i(curr_read_addr),
    .data_i(data_i),
    .data_o(b1_data_o)
);

distri_ram #(.ENTRY_NUM(BUFFER_LEN), .XLEN(XLEN))
buffer_2 (
    .clk_i(clk_i),
    .we_i((addr_i == 32'hC420_0000) && en_i && we_i),
    .write_addr_i(write_addr), // 使用 write_addr 写入地址
    .read_addr_i(curr_read_addr),
    .data_i(data_i),
    .data_o(b2_data_o)
);

// 浮点运算单元
reg feeder_valid;
reg [XLEN-1:0] feeder_dataA;
reg [XLEN-1:0] feeder_dataB;
reg [XLEN-1:0] feeder_dataC;
wire fp_result_valid;
wire [XLEN-1:0] fp_result_data;

floating_point_0 floating_point_unit (
    .aclk(clk_i),
    .s_axis_a_tvalid(feeder_valid),
    .s_axis_a_tdata(feeder_dataA),
    .s_axis_b_tvalid(feeder_valid),
    .s_axis_b_tdata(feeder_dataB),
    .s_axis_c_tvalid(feeder_valid),
    .s_axis_c_tdata(feeder_dataC),
    .m_axis_result_tvalid(fp_result_valid),
    .m_axis_result_tdata(fp_result_data)
);

// 计算状态机
reg [1:0] C, C_next;
localparam C_IDLE = 2'b00, C_CAL = 2'b01, C_DONE = 2'b10;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) C <= C_IDLE;
    else C <= C_next;
end

always @(*) begin
    C_next = C;
    case (C)
        C_IDLE: begin
            if (curr_data_num < total_data_num) C_next = C_CAL;
        end
        C_CAL: begin
            if (fp_result_valid) C_next = C_DONE;
        end
        C_DONE: begin
            if (S == S_WAIT) C_next = C_IDLE;
        end
        default: C_next = C_IDLE;
    endcase
end

// 准备数据
always @(posedge clk_i) begin
    if (rst_i) begin
        feeder_dataA <= 0;
        feeder_dataB <= 0;
        feeder_dataC <= 0;
        feeder_valid <= 0;
    end else if (C == C_CAL) begin
        feeder_valid <= 1;
        feeder_dataA <= b1_data_o;
        feeder_dataB <= b2_data_o;
        feeder_dataC <= (curr_data_num == 0) ? 0 : fp_result_data;
    end else begin
        feeder_valid <= 0;
    end
end

// 结果管理
always @(posedge clk_i) begin
    if (rst_i) begin
        curr_data_num <= 0;
        curr_read_addr <= 0;
    end else if (C == C_CAL && feeder_valid) begin
        curr_read_addr <= curr_read_addr + 1;
        curr_data_num <= curr_data_num + 1;
    end else if (S == S_WAIT && addr_i == 32'hC430_0000 && en_i && ~we_i) begin
        data_o <= fp_result_data;
    end
end

assign data_ready_o = (S == S_WAIT && addr_i == 32'hC430_0000);

endmodule
