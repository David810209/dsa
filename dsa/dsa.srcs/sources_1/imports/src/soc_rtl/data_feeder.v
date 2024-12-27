
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
32'hC400_0000 = trigger load weight
32'hC400_0004 = weight data input

//---input image data--------------
32'hC410_0000 = trigger load input image data
32'hC410_0004 = input image data input

//---output image data--------------
32'hC420_0000 = trigger refresh output image (output image data size)
32'hC420_0004 = return calculation result
//calculation data
32'hC430_0000 = in_.width
32'hC430_0004 = out_.width
32'hC430_0008 = weight_width
32'hC430_000c = trigger calculation & check calculation done
32'hc430_0010 = in_.depth
32'hc430_0014 = out_.depth

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
//load weight data
/////////////////////////////////////////////////
reg ready_reg;
reg ready_w_reg;
always @(posedge clk_i)begin
    if(rst_i)begin
        ready_w_reg <= 0;
    end
    else if(en_i && we_i )begin
        ready_w_reg <= 1;
    end
    else if(ready_w_reg)begin
        ready_w_reg <= 0;
    end
end
reg [15:0] load_weight_cnt;
reg [15:0] total_weight;
reg [15:0] inner_weight_num;
(* ram_style="block" *) reg [XLEN-1:0] weight_data[4095:0];
reg written;

always @(posedge clk_i) begin
    if(rst_i)begin
        load_weight_cnt <= 0;
        total_weight <= 0;
        written <= 0;

        inner_weight_num <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC400_0000) begin
        total_weight <= data_i;
        inner_weight_num <= weight_width * weight_width;
        load_weight_cnt <= 0;
        written <= 0;
    end
    else if(S == S_LOAD_WEIGHT)begin
        if(load_weight_cnt == total_weight)begin
            load_weight_cnt <= 0;
        end
        else
        if(we_i && addr_i == 32'hC400_0004 && !written)begin
            weight_data[load_weight_cnt] <= data_i;
            load_weight_cnt <= load_weight_cnt + 1;
            written <= 1;
        end
        else if(!we_i)begin
        written <= 0;
    end
    end
    
end

////////////////////////////////////////////
//load image data
/////////////////////////////////////////////////
/*
ppi=0
for(int i = 0;i<24;i++){
for(int j = 0;j < 24;j++){ ppi++;}
ppi += 4;
}
ppi = 676;
*/

reg [15:0] load_i_img_cnt;
reg [15:0] total_i_img;
(* ram_style="block" *) reg [XLEN-1:0] i_img[1023:0];
reg i_img_written;

always @(posedge clk_i) begin
    if(rst_i)begin
        load_i_img_cnt <= 0;
        total_i_img <= 0;
        i_img_written <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC410_0000) begin
        total_i_img <= data_i;
        load_i_img_cnt <= 0;
        i_img_written <= 0;
    end
    else if(S == S_LOAD_I_IMG)begin
        if(load_i_img_cnt == total_i_img)begin
            load_i_img_cnt <= 0;
        end
        else
        if(we_i && addr_i == 32'hC410_0004 && !i_img_written)begin
            i_img[load_i_img_cnt] <= data_i;
            load_i_img_cnt <= load_i_img_cnt + 1;
            i_img_written <= 1;
        end
        else if(!we_i)begin
        i_img_written <= 0;
    end
    end
    
end

////////////////////////////////////////////
//output image data
/////////////////////////////////////////////////
reg [15:0] total_o_img;
(* ram_style="block" *)  reg [XLEN-1:0] o_img[2047:0];  // 24*24
reg [15:0] output_img_cnt;

reg [XLEN-1:0] dataA2;
reg [XLEN-1:0] dataB2;
wire [XLEN-1:0] add_result_data2;
wire add_result_valid2;
reg add_data_valid2;

reg [15:0] relu_idx;
integer j;
reg [15:0] out_idx;
reg start_to_clean;
reg clean_done;
reg [15:0] clean_cnt;
reg comp_data_valid;
reg relu_done;

always @(posedge clk_i) begin
    if(rst_i)begin
        total_o_img <= 0;
        out_idx <= 0;
        dataA2 <= 0;
        dataB2 <= 0;
        add_data_valid2 <= 0;
        start_to_clean <= 0;
        clean_cnt <= 0;
        clean_done <= 0;
        relu_idx <= 0;
        relu_done <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC420_0000) begin
        total_o_img <= data_i;
        start_to_clean <= 1;
        clean_cnt <= 0 ;
    end
    else if(start_to_clean)begin
        if(clean_cnt == total_o_img)begin
            start_to_clean <= 0;
            clean_done <= 1;
        end
        else begin 
            o_img[clean_cnt] <= 0;
            clean_cnt <= clean_cnt + 1;
        end
    end
    else if(trigger_calc)begin
        out_idx <= 0;
    end
    else if(change_out_idx) begin
        out_idx <= out_channel_idx * out_width * out_width;
    end
    else if(C == C_STORE_RESULT && fma_result_valid)begin
        dataA2 <= o_img[out_idx];
        dataB2 <= fma_result_data;
        add_data_valid2 <= 1;
    end
    else if(C == C_STORE_RESULT && add_result_valid2)begin
        o_img[out_idx] <= add_result_data2;
        add_data_valid2 <= 0;
        out_idx <= out_idx + 1;
    end
    else if(C == C_RELU && comp_result_valid)begin
        if(comp_result_data)begin
            o_img[relu_idx - 1] <= 0;
        end
        if(relu_idx == total_o_img)begin
            relu_idx <= 0;
            relu_done <= 1;
        end
        else begin
            relu_idx <= relu_idx + 1;
            relu_done <= 0;
        end
    end
    else if(C == C_IDLE)begin
        relu_done <= 0;
    end
     if(clean_done)begin
        clean_done <= 0;
    end
end

////////////////////////////////////////////
//conv 3d calculation
/////////////////////////////////////////////////
reg [15:0] in_channel_idx;
reg [15:0] out_channel_idx;
reg [15:0] out_width;
reg [15:0] in_width;
reg [15:0] weight_width;
reg [15:0] in_depth;
reg [15:0] out_depth;
wire [15:0] const1 = in_width - weight_width;
wire [15:0] const2 = in_width - out_width;
reg [15:0] idx_x, idx_y;
reg [15:0] img_idx;
wire this_calc_done = fma_data_valid && (inner_cnt == 25);
wire next_weight = (inner_cnt == 24) && fma_result_valid && idx_x == out_width - 1 && idx_y == out_width - 1;
wire inner_loop_done = idx_x == out_width - 1 ;
wire trigger_calc = en_i && we_i && addr_i == 32'hC430_000c;
wire trigger_next_calc =  (idx_x == 0 && idx_y == out_width && add_result_valid2) && (out_channel_idx != out_depth) ;

always @(posedge clk_i) begin
    if(rst_i)begin
        out_width <= 0;
        idx_x <= 0;
        idx_y <= 0;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0000) begin
        in_width <= data_i;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0004) begin
        out_width <= data_i;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0008) begin
        weight_width <= data_i;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0010) begin
        in_depth <= data_i;
    end
    else if(en_i && we_i && addr_i == 32'hC430_0014) begin
        out_depth <= data_i;
    end
    else if(trigger_calc || trigger_next_calc || C == C_IDLE) begin
        idx_x <= 0;
        idx_y <= 0;
    end
    else if(this_calc_done && (idx_x != 0 || idx_y != out_width))begin
        if(idx_x == out_width-1)begin
            idx_x <= 0;
            idx_y <= idx_y + 1;
        end
        else idx_x <= idx_x + 1;
    end
end

reg fma_data_valid;
wire fma_result_valid;
reg [XLEN-1:0] fma_dataA;
reg [XLEN-1:0] fma_dataB;
reg [XLEN-1:0] fma_dataC;
wire [XLEN-1:0] fma_result_data;
reg [15:0] fma_calculation_cnt;
reg [15:0] inner_cnt;
reg [15:0] window_counter;
reg [15:0] widx;
always @(posedge clk_i)
begin
    if(rst_i)begin
        fma_dataA <= 0;
        fma_dataB <= 0;
        fma_dataC <= 0;
        fma_data_valid <= 0;
        fma_calculation_cnt <= 0;
        inner_cnt <= 0;
        window_counter <= 0;
        img_idx <= 0;
        widx <= 0;
        in_channel_idx <= 0;
        out_channel_idx <= 0;
    end
    else begin
        if(C == C_IDLE)begin
            in_channel_idx <= 0;
            out_channel_idx <= 0;
            fma_calculation_cnt <= 0;
            inner_cnt <= 0;
        end
        else if(out_channel_idx == out_depth)begin
            out_channel_idx <= out_channel_idx;
        end
        else if(in_channel_idx == in_depth)begin
            in_channel_idx <= 0;
            out_channel_idx <= out_channel_idx + 1;
        end
        else if(inner_cnt == inner_weight_num)begin
            inner_cnt <= 0;
        end
        if((C_next == C_CALC && fma_result_valid)|| trigger_calc ||trigger_next_calc || (C == C_STORE_RESULT && C_next == C_CALC))begin
            fma_dataA <= weight_data[fma_calculation_cnt + inner_cnt];
            fma_dataB <= i_img[img_idx + widx];
            fma_dataC <= (C == C_STORE_RESULT || trigger_calc || trigger_next_calc) ? 0 : fma_result_data;
            fma_data_valid <= 1;
            inner_cnt <= inner_cnt + 1;
            if(trigger_calc)begin
                widx <= 1;
                window_counter <= 1;
                img_idx <= 0;
                inner_cnt <= 1;
                fma_calculation_cnt <= 0;
            end
            else if(next_weight) begin
                if(in_channel_idx == in_depth - 1) img_idx <= const2 * -1 - 1;
                else img_idx <= img_idx + widx - const2;
                widx <= 1;
                window_counter <= 1;
                in_channel_idx <= in_channel_idx + 1;
                fma_calculation_cnt <= fma_calculation_cnt + 25;
            end
            else if(window_counter == weight_width-1)begin
                window_counter <= 0;
                widx <= widx + 1 + const1;
            end
            else begin 
                window_counter <= window_counter + 1;
                widx <= widx + 1;
             end
        end
        if(this_calc_done)begin
            widx <= 0;
            window_counter <= 0;
            if(inner_loop_done)begin
                img_idx <= img_idx + const2 + 1;
            end
            else begin
                img_idx <= img_idx + 1;
            end
        end
        if(fma_data_valid)begin
            fma_data_valid <= 0;
        end
    end
end

reg change_out_idx;
always @(posedge clk_i) begin
    if(rst_i) change_out_idx <= 0;
    else if(trigger_next_calc) change_out_idx <= 1;
    else if(change_out_idx == 1) change_out_idx <= 0;
end

////////////////////////////////////////////
//for FMA data feeding
/////////////////////////////////////////////////
reg data_valid;
wire result_valid;
reg [XLEN-1:0] feeder_dataA;
reg [XLEN-1:0] feeder_dataB;
reg [XLEN-1:0] feeder_dataC;
wire [XLEN-1:0] fp_result_data;
reg [XLEN-1:0] result_reg;
reg [15:0] calculation_cnt;

always @(posedge clk_i)
begin
    if(rst_i)begin
        feeder_dataA <= 0;
        feeder_dataB <= 0;
        feeder_dataC <= 0;
        data_valid <= 0;
        calculation_cnt <= 0;
    end
    else if(en_i)begin
        if(we_i && addr_i == 32'hC440_0018)begin
            feeder_dataA <= data_i;
        end
        else if(we_i && addr_i == 32'hC440_001c)begin
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
//for FP comp (relu)
/////////////////////////////////////////////////
reg [XLEN-1:0] comp_dataA;
reg [XLEN-1:0] comp_dataB;
wire [7:0] comp_result_data;
wire comp_result_valid;
reg [XLEN-1:0] comp_result_reg;

always @(posedge clk_i)
begin
    if(rst_i)begin
        comp_dataA <= 0;
        comp_dataB <= 0;
        comp_data_valid <= 0;
    end
    else if(comp_data_valid == 0) begin
        comp_dataA <= o_img[relu_idx];
        comp_dataB <= 0;
        comp_data_valid <= 1;
    end
    else if(comp_data_valid)begin
        comp_data_valid <= 0;
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
        ready_reg <= 0;
        add_result_reg <= 0;
        data_o <= 0;
        send <= 0;
        output_img_cnt <= 0;
        comp_result_reg <= 0;
    end
    else if(trigger_calc)begin
        output_img_cnt <= 0;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC420_0004 && send == 0))begin
            data_o <= o_img[output_img_cnt];
            ready_reg <= 1;
            if(output_img_cnt == total_o_img)begin
                output_img_cnt <= 0;
            end
            else begin
            output_img_cnt <= output_img_cnt + 1;
            send <= 1;
            end
    end
    else if(en_i && !we_i && addr_i == 32'hC430_000c)begin
        data_o <= C == C_IDLE;
        ready_reg <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0008) && send == 0)begin
            result_reg <= 0;
            data_o <= add_result_valid ? add_result_data :  add_result_reg;
            send <= 1;
            ready_reg <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0014) && send == 0)begin
            data_o <= mul_result_reg;
            ready_reg <= 1;
            send <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0028 && send == 0))begin
            data_o <= comp_result_valid ? ( comp_result_data ? 0 : comp_dataA) : 
                                         ( comp_result_reg ? 0 : comp_dataA);
            ready_reg <= 1;
            send <= 1;
    end
    else if(en_i &&  !we_i && (addr_i == 32'hC440_0020) && send == 0)begin
            result_reg <= 0;
            data_o <= result_reg;
            ready_reg <= 1;
            send <= 1;
    end
    else if(send)begin
        send <= 0;
    end
    if(ready_reg)begin
        ready_reg <= 0;
    end
    if(result_valid)begin
        result_reg <= fp_result_data;
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
    if(comp_result_valid)begin
        comp_result_reg <= comp_result_data;
        send <= 0;
    end
end

////////////////////////////////////////////
//FSM management
/////////////////////////////////////////////////
reg [2:0] S, S_next;
localparam S_IDLE = 0, S_LOAD_WEIGHT = 1, S_CALC = 2, S_CALC_ADD = 3,
                     S_CALC_mul = 4, S_LOAD_I_IMG = 5;

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
            else if(en_i && we_i && addr_i == 32'hC410_0000)begin
                S_next = S_LOAD_I_IMG;
            end
            else if(data_valid)begin
                S_next = S_CALC;
            end
            else if(add_data_valid)begin
                S_next = S_CALC_ADD;
            end
            else if(mul_data_valid) begin
                S_next = S_CALC_mul;
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
        S_CALC_mul:begin
            if(mul_data_valid)begin
                S_next = S_IDLE;
            end
        end
        S_LOAD_I_IMG:begin
            if(load_i_img_cnt == total_i_img)begin
                S_next = S_IDLE;
            end
        end
    endcase
end

reg [2:0] C, C_next;
localparam C_IDLE = 0,C_CALC=1, C_STORE_RESULT=2, C_RELU = 3;

always @(posedge clk_i)
begin
    if(rst_i) C <= C_IDLE;
    else  C <= C_next;
end

always @(*)
begin
    C_next = C;
    case(C)
        C_IDLE:begin
          if(trigger_calc)begin
              C_next = C_CALC;
          end
        end

        C_CALC:begin
            if(this_calc_done)begin
                C_next = C_STORE_RESULT;
            end
            else begin
                C_next = C_CALC;
            end
        end
        C_STORE_RESULT:begin
            if(out_channel_idx == out_depth && in_channel_idx == 0 && add_result_valid2)begin
                C_next = C_RELU;
            end
            else if(add_result_valid2)begin
                C_next = C_CALC;
            end
        end
        C_RELU:begin
            if(relu_done)begin
                C_next = C_IDLE;
            end
        end
       
    endcase
end

// assign ready_o = (~start_to_clean) && (ready_reg || ready_w_reg || clean_done);
assign ready_o = ~start_to_clean && C != C_RELU;

////////////////////////////////////////////
//fIP Management
/////////////////////////////////////////////////
// FMA IP
FP_FMA fma(
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

FP_FMA fma2(
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

// FP ADD IP
FP_ADD fp_add2(
    .aclk(clk_i),
    .s_axis_a_tvalid(add_data_valid2),
    .s_axis_a_tdata(dataA2),
    .s_axis_b_tvalid(add_data_valid2),
    .s_axis_b_tdata(dataB2),

    .m_axis_result_tvalid(add_result_valid2),
    .m_axis_result_tdata(add_result_data2)
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

//FP COMPARE IP (LESS THAN)
floating_point_0 fpcomp(
    .aclk(clk_i),
    .s_axis_a_tvalid(comp_data_valid),
    .s_axis_a_tdata(comp_dataA),

    .s_axis_b_tvalid(comp_data_valid),
    .s_axis_b_tdata(comp_dataB),


    .m_axis_result_tvalid(comp_result_valid),
    .m_axis_result_tdata(comp_result_data)
);

endmodule
