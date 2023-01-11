`timescale 1ns / 1ps

module data_acquire(
    input clk_i,
    input reset_n_i,
    
//ADC interface
    output  adc_data_req_o,
    input   adc_data_rdy_i,
    input [11:0] adc_data_i,
    
//Module output interface
    input           syncro_i,
    output [11:0]   data_o,
    output          data_rdy_o
);

reg reset_n;
reg syncro;
reg syncro_negedge;
reg syncro_d1;
wire syncro_re;
reg [3:0] counter;

reg adc_data_rdy, adc_data_rdy_d1;
wire adc_data_rdy_re;
reg adc_data_req;

reg signed [14:0] accum;
reg signed [11:0] accum_mean;
wire signed [11:0] adc_data;
reg data_rdy;

reg [5:0] state;
localparam ST_IDLE       = 6'b100000;
localparam ST_WAIT       = 6'b010000;
localparam ST_ADC_REQ    = 6'b001000;
localparam ST_ADC_REQ2   = 6'b000100;
localparam ST_ADC_WAIT   = 6'b000010;
localparam ST_OUT        = 6'b000001;


always @(negedge clk_i) begin
    syncro_negedge <= syncro_i;
end

always @(posedge clk_i) begin
    reset_n <= reset_n_i;

    syncro <= syncro_i|syncro_negedge;
    syncro_d1 <= syncro;

    adc_data_rdy <= adc_data_rdy_i;
    adc_data_rdy_d1 <= adc_data_rdy;
end
assign syncro_re = syncro&~syncro_d1;
assign adc_data_rdy_re = adc_data_rdy&~adc_data_rdy_d1;

assign adc_data = adc_data_i;


always @(posedge clk_i) begin
    // reset note:
    // Xilinx recommends to use syncronouse reset, may be different for other vendors
    if (reset_n == 0) begin
        state <= ST_IDLE;
        counter <= 0;
        adc_data_req <= 0;
        data_rdy <= 0;
    end
    else begin
        case (state)
            ST_IDLE: begin
                if (syncro_re == 1) begin
                    state <= ST_WAIT;
                    data_rdy <= 0;
                end

                counter <= 0;
                adc_data_req <= 0;                
            end

            ST_WAIT: begin
                // counter corrections:
                // -1 clk: syncro signal registering
                // -1 clk: switch from idle to wait state
                // -1 clk: switch from wait to adc_req state
                if (counter == 11 - 3) begin
                    state <= ST_ADC_REQ;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end

            ST_ADC_REQ: begin
                state <= ST_ADC_REQ2;
                adc_data_req <= 1;
            end

            ST_ADC_REQ2: begin
                if (adc_data_rdy == 0) begin
                    state <= ST_ADC_WAIT;
                end
            end

            ST_ADC_WAIT: begin
                if (adc_data_rdy_re == 1) begin
                    if (counter < 7) begin
                        state <= ST_ADC_REQ;
                    end else begin
                        state <= ST_OUT;
                    end
                    counter <= counter + 1;
                end
                adc_data_req <= 0;
            end

            ST_OUT : begin
                data_rdy <= 1;
                state <= ST_IDLE;
            end

        endcase
    end
    
end

assign adc_data_req_o = adc_data_req;
assign data_rdy_o = data_rdy;


always @(posedge clk_i) begin
    if (syncro_re == 1 && state == ST_IDLE) begin
        accum <= 0;
        accum_mean <= 0;
    end
    else begin
        if (adc_data_rdy_re == 1) begin
            accum <= accum + adc_data;
        end
        // NOTE: +accum[2] to compensate rounding error
        accum_mean <= accum[14:3] + accum[2];
    end
    
end
assign data_o = accum_mean;

endmodule
