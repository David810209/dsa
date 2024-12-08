`timescale 1ns / 1ps
// =============================================================================
//  Program : soc_tb.v
//  Author  : Chun-Jen Tsai
//  Date    : Feb/24/2020
// -----------------------------------------------------------------------------
//  Description:
//  This is the top-level Aquila testbench.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"

`define SIM_CLK_RATE 100_000_000

module soc_tb #( parameter XLEN = 32, parameter CLSIZE = `CLP )();

reg  sys_reset = 1;
reg  sys_clock = 0;

wire usr_reset;
wire ui_clk, ui_rst;
wire clk, rst;

// uart
wire                uart_rx = 1; /* When the UART rx line is idle, it carries '1'. */
wire                uart_tx;

// --------- External memory interface -----------------------------------------
// Instruction memory ports
wire                IMEM_strobe;
wire [XLEN-1 : 0]   IMEM_addr;
wire                IMEM_done;
wire [CLSIZE-1 : 0] IMEM_data;

// Data memory ports
wire                DMEM_strobe;
wire [XLEN-1 : 0]   DMEM_addr;
wire                DMEM_rw;
wire [CLSIZE-1 : 0] DMEM_wt_data;
wire                DMEM_done;
wire [CLSIZE-1 : 0] DMEM_rd_data;

// --------- I/O device interface ----------------------------------------------
// Device bus signals
wire                dev_strobe;
wire [XLEN-1 : 0]   dev_addr;
wire                dev_we;
wire [XLEN/8-1 : 0] dev_be;
wire [XLEN-1 : 0]   dev_din;
wire [XLEN-1 : 0]   dev_dout;
wire                dev_ready;

// DSA device signals (Not used for HW#0 ~ HW#4)
wire                dsa_sel;
wire [XLEN-1 : 0]   dsa_dout;
wire                dsa_ready;

// uart
wire                uart_sel;
wire [XLEN-1 : 0]   uart_dout;
wire                uart_ready;

// External reset signal
assign usr_reset = sys_reset;

// --------- System Clock Generator --------------------------------------------
assign clk = sys_clock;

always
  #((1_000_000_000/`SIM_CLK_RATE)/2) sys_clock <= ~sys_clock; // 100 MHz

// -----------------------------------------------------------------------------
// For the Aquila Core, the reset (rst) will lasts for 5 cycles to clear
//   all the pipeline registers.
//
localparam RST_CYCLES=5;
reg [RST_CYCLES-1 : 0] rst_count = {RST_CYCLES{1'b1}};
assign rst = rst_count[RST_CYCLES-1];

always @(posedge clk)
begin
    if (usr_reset)
        rst_count <= {RST_CYCLES{1'b1}};
    else
        rst_count <= {rst_count[RST_CYCLES-2 : 0], 1'b0};
end

// Simulate a clock-domain for DRAM
assign ui_clk = sys_clock;
assign ui_rst = rst_count[RST_CYCLES-1];
wire [XLEN-1 : 0] aquila_pc;
// -----------------------------------------------------------------------------
//  Aquila processor core.
//
aquila_top Aquila_SoC
(
    .clk_i(clk),
    .rst_i(rst),          // level-sensitive reset signal.
    .base_addr_i(32'b0),  // initial program counter.

    // External instruction memory ports.
    .M_IMEM_strobe_o(IMEM_strobe),
    .M_IMEM_addr_o(IMEM_addr),
    .M_IMEM_done_i(IMEM_done),
    .M_IMEM_data_i(IMEM_data),

    // External data memory ports.
    .M_DMEM_strobe_o(DMEM_strobe),
    .M_DMEM_addr_o(DMEM_addr),
    .M_DMEM_rw_o(DMEM_rw),
    .M_DMEM_data_o(DMEM_wt_data),
    .M_DMEM_done_i(DMEM_done),
    .M_DMEM_data_i(DMEM_rd_data),

    // I/O device ports.
    .M_DEVICE_strobe_o(dev_strobe),
    .M_DEVICE_addr_o(dev_addr),
    .M_DEVICE_rw_o(dev_we),
    .M_DEVICE_byte_enable_o(dev_be),
    .M_DEVICE_data_o(dev_din),
    .M_DEVICE_data_ready_i(dev_ready),
    .M_DEVICE_data_i(dev_dout),

    .to_tb_pc_o(aquila_pc)
);

// -----------------------------------------------------------------------------
//  Device address decoder.
//
//       [0] 0xC000_0000 - 0xC0FF_FFFF : UART device
//       [1] 0xC400_0000 - 0xC4FF_FFFF : DSA device
assign uart_sel  = (dev_addr[XLEN-1:XLEN-8] == 8'hC0);
assign dsa_sel   = (dev_addr[XLEN-1:XLEN-8] == 8'hC2);
assign dev_dout  = (uart_sel)? uart_dout : (dsa_sel)? dsa_dout : {XLEN{1'b0}};
assign dev_ready = (uart_sel)? uart_ready : (dsa_sel)? dsa_ready : {XLEN{1'b0}};

// ----------------------------------------------------------------------------
//  UART Controller with a simple memory-mapped I/O interface.
//
`define BAUD_RATE	115200

wire simulation_finished;
wire simulation_tmp =aquila_pc == 32'h0000_0608;

uart #(.BAUD(`SIM_CLK_RATE/`BAUD_RATE))
UART(
    .clk(clk),
    .rst(rst),

    .EN(dev_strobe & uart_sel),
    .ADDR(dev_addr[3:2]),
    .WR(dev_we),
    .BE(dev_be),
    .DATAI(dev_din),
    .DATAO(uart_dout),
    .READY(uart_ready),

    .RXD(uart_rx),
    .TXD(uart_tx),

    .simulation_done(simulation_finished)
);

// ----------------------------------------------------------------------------
//  Print simulation termination message.
//
always @(posedge clk)
begin
    if (simulation_tmp) begin
        $display();
        $display("Simulation finished.");
        $finish();
    end
end

// ----------------------------------------------------------------------------
//  Reset logic simulation.
//
reg reset_trigger;

initial begin
  forever begin
    @ (posedge reset_trigger);
    sys_reset = 1;
    @ (posedge clk);
    @ (posedge clk);
    sys_reset = 0;
  end
end

initial
begin: TEST_CASE
  #10 reset_trigger = 1;
  @(negedge sys_reset)
  reset_trigger = 0;
end

//-------------------------------------------------------------------------
//inner product
//-------------------------------------------------------------------------
assign dsa_ready = (S != S_CALC);
reg [XLEN - 1: 0] result_data_o;
assign dsa_dout = result_data_o;

reg [XLEN - 1: 0] feeder_dataA0, feeder_dataA1, feeder_dataA2;
reg [XLEN - 1: 0] feeder_dataB0, feeder_dataB1, feeder_dataB2;

reg data_valid;

always @(posedge clk)
begin
    if(rst)begin
        feeder_dataA0 <= 32'b0;
        feeder_dataA1 <= 32'b0;
        feeder_dataA2 <= 32'b0;
        feeder_dataB0 <= 32'b0;
        feeder_dataB1 <= 32'b0;
        feeder_dataB2 <= 32'b0;
        data_valid <= 1'b0;
    end
    else if(dev_strobe & dsa_sel)begin
        if(dev_addr == 32'hC200_0000)begin
            if(dev_we)begin
                feeder_dataA0 <= dev_din;
            end
            else begin
                result_data_o <= feeder_dataA0;
            end
        end
        else if(dev_addr == 32'hC200_0004)begin
            if(dev_we)begin
                feeder_dataA1 <= dev_din;
            end
            else begin
                result_data_o <= feeder_dataA1;
            end
        end
        else if(dev_addr == 32'hC200_0008)begin
            if(dev_we)begin
                feeder_dataA2 <= dev_din;
            end
            else begin
                result_data_o <= feeder_dataA2;
            end
        end
        else if(dev_addr == 32'hC200_000C)begin
            if(dev_we)begin
                feeder_dataB0 <= dev_din;
            end
            else begin
                result_data_o <= feeder_dataB0;
            end
        end
        else if(dev_addr == 32'hC200_0010)begin
            if(dev_we)begin
                feeder_dataB1 <= dev_din;
            end
            else begin
                result_data_o <= feeder_dataB1;
            end
        end
        else if(dev_addr == 32'hC200_0014)begin
            if(dev_we)begin
                feeder_dataB2 <= dev_din;
                data_valid <= 1'b1;
            end
            else begin
                result_data_o <= feeder_dataB2;
            end
        end
        else if(dev_addr == 32'hC200_0018 && result_valid)begin
            result_data_o <= result_data;
        end
        else if(data_valid)begin
            data_valid <= 1'b0;
        end
    end
end

reg [1:0] S, S_next;
localparam S_IDLE = 2'b00, S_CALC = 2'b01, S_WAIT = 2'b10;

always @(posedge clk)
begin
    if(rst)begin
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
            if(data_valid)begin
                S_next = S_CALC;
            end
        end
        S_CALC:begin
            if(result_valid)begin
                S_next = S_WAIT;
            end
        end
        S_WAIT:begin
            if(dev_addr == 32'hC200_0018)begin
                S_next = S_IDLE;
            end
        end
    endcase
end

reg [XLEN - 1: 0] result_data;
reg result_valid;

always @(posedge clk) begin
    if(rst)begin
        result_data <= 32'b0;
        result_valid <= 1'b0;
    end
    else
    if(data_valid)begin
        result_data <= feeder_dataA0 * feeder_dataB0 +
                      feeder_dataA1 * feeder_dataB1 + 
                      feeder_dataA2 * feeder_dataB2;
        result_valid <= 1'b1;
    end
    if(S == S_IDLE)begin
        result_valid <= 1'b0;
    end
end

endmodule

