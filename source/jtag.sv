//////////////////////////////////////////////////
//~:(
//@module: jtag.sv
//@author: Yafizov Airat
//@date: 12.05.2022
//@version: 
//@description: jtag_interface
//~:)
//////////////////////////////////////////////////

module jtag
    #(
    parameter DATA_INSTRUCTION = 6,
    parameter DATA_FIFO = 8,
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //CONTROL
    input logic op, //type of transaction, 1-data, 0-instruction
    input logic work,
    output logic busy,
    //JTAG
    input logic tdo,
    output logic tdi,
    output logic tck,
    output logic tms,
    //FIFO_instruction
    input logic  [(DATA_INSTRUCTION - 1):0] rdata_instruction,
    output logic rd_instruction,
    input logic empty_instruction,
    //FIFO_data
    input logic  [(DATA_FIFO - 1):0] rdata_data,
    output logic rd_data,
    input logic empty_data
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [3:0] {ST_IDLE, ST_TMS, ST_INSTRUCTION, ST_DATA, ST_DELAY, ST_RES} state_type;

//initial constants
localparam FREQUENCY_DIVIDER = 5;
localparam DATA_TMS = 5;
localparam RESET_TAP = 5'b11111;
localparam GO_SHIFT_IR = 5'b01100;
localparam GO_SHIFT_DR = 5'b00100;
localparam GO_EXIT = 5'b11000;



//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////

state_type state;
state_type state_reserved;
logic flag_exit;
logic enable_tck;
logic [3:0] count;
logic [7:0] count_transaction;
//shift registers
logic [(DATA_TMS - 1) :0] shift_tms;
logic [(DATA_FIFO - 1) :0] shift_instruction;

//////////////////////////////////////////////////
//tms and tdi retiming
//////////////////////////////////////////////////

assign tms = shift_tms [(DATA_TMS - 1)];
assign tdi = shift_instruction [DATA_FIFO - 1];

//////////////////////////////////////////////////
//Control FSM
//////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if(rst) begin
        flag_exit <= 0;
        enable_tck <= 0;
        tck <= 0;
        count <= 0;
        count_transaction <= 0;
        shift_instruction <= 0;
        shift_tms <= RESET_TAP;
        state <= ST_RES;
        state_reserved <= ST_IDLE;
        rd_data <= 0; 
        rd_instruction <= 0; 
        busy <= 1;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                flag_exit <= 0;
                enable_tck <= 0;
                tck <= 0;
                busy <= 0;
                count <= 0;
                count_transaction <= 0;
                shift_instruction <= 0;
                shift_tms <= 0;
                rd_data <= 0; 
                rd_instruction <= 0; 
                if (work == 1) begin
                    state <= ST_DELAY;
                    state_reserved <= ST_TMS;
                    busy <= 1;
                    if (op == 0) begin
                        shift_tms <= GO_SHIFT_IR;
                    end
                    else begin
                        shift_tms <= GO_SHIFT_DR;
                    end
                end 
            end
            //////////////////////////////////////////////////
            ST_RES : begin
                tck <= 0;
                count <= 0;
                if (count_transaction == 0) begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_RES;
                    count_transaction <= count_transaction + 1;
                end
                else if (count_transaction == DATA_TMS) begin
                    enable_tck <= 0;
                    state <= ST_DELAY;
                    state_reserved <= ST_IDLE;
                    shift_tms <= {shift_tms [(DATA_TMS - 2):0], 1'b0};
                end
                else begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_RES;
                    count_transaction <= count_transaction + 1;
                    shift_tms <= {shift_tms [(DATA_TMS - 2):0], 1'b0};
                end
            end
            //////////////////////////////////////////////////
            ST_INSTRUCTION : begin
                tck <= 0;
                count <= 0;
                rd_instruction <= 0; 
                if (count_transaction == 0) begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_INSTRUCTION;
                    count_transaction <= count_transaction + 1;
                end
                else if (count_transaction == (DATA_INSTRUCTION - 1)) begin
                    state <= ST_DELAY;
                    state_reserved <= ST_TMS;
                    count_transaction <= 0;
                    flag_exit <= 1;
                    shift_tms <= GO_EXIT;
                    enable_tck <= 0;
                    shift_instruction <= {shift_instruction [(DATA_FIFO - 2):0], 1'b0};
                end
                else begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_INSTRUCTION;
                    count_transaction <= count_transaction + 1;
                    //shift_instruction <= {1'b0, shift_instruction [(DATA_INSTRUCTION - 1):1]};
                    shift_instruction <= {shift_instruction [(DATA_FIFO - 2):0], 1'b0};
                end
            end
            //////////////////////////////////////////////////
            ST_DATA : begin
                tck <= 0;
                count <= 0;
                if (count_transaction == 0) begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_DATA;
                    count_transaction <= count_transaction + 1;
                    rd_data <= 0;
                end
                else if (count_transaction == ((DATA_FIFO * 4) - 1)) begin
                    state <= ST_DELAY;
                    state_reserved <= ST_TMS;
                    count_transaction <= 0;
                    flag_exit <= 1;
                    shift_tms <= GO_EXIT;
                    enable_tck <= 0;
                    rd_data <= 0;
                    shift_instruction <= {shift_instruction [(DATA_FIFO - 2):0], 1'b0};
                end
                else if (((!count_transaction [0]) && (!count_transaction [1]) && (!count_transaction [2])) == 1) begin
                    state <= ST_DELAY;
                    state_reserved <= ST_DATA;
                    shift_instruction [(DATA_FIFO - 1):0] <= rdata_data [(DATA_FIFO - 1):0];
                    enable_tck <= 1;
                    rd_data <= 1;
                    count_transaction <= count_transaction + 1;
                end
                else begin
                    enable_tck <= 1;
                    rd_data <= 0;
                    state <= ST_DELAY;
                    state_reserved <= ST_DATA;
                    count_transaction <= count_transaction + 1;
                    //shift_instruction <= {2'b0, tdo, shift_instruction [(DATA_FIFO - 1):1]};
                    shift_instruction <= {shift_instruction [(DATA_FIFO - 2):0], 1'b0};
                end
            end
            //////////////////////////////////////////////////
            ST_TMS : begin
                tck <= 0;
                count <= 0;
                if (count_transaction == 0) begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_TMS;
                    count_transaction <= count_transaction + 1;
                end
                else if (count_transaction == DATA_TMS) begin
                    if (op == 0) begin
                        flag_exit <= 0;
                        enable_tck <= 0;
                        state <= ST_DELAY;
                        count_transaction <= 0;
                        if (flag_exit == 1) begin
                            state_reserved <= ST_IDLE;
                        end 
                        else begin
                            state_reserved <= ST_INSTRUCTION;
                            rd_instruction <= 1; 
                            shift_instruction [(DATA_FIFO - 1):0] <= {rdata_instruction [(DATA_INSTRUCTION - 1):0], 2'b0};
                        end
                    end 
                    else begin
                        flag_exit <= 0;
                        enable_tck <= 0;
                        state <= ST_DELAY;
                        count_transaction <= 0;
                        if (flag_exit == 1) begin
                            state_reserved <= ST_IDLE;
                        end 
                        else begin
                            state_reserved <= ST_DATA;
                            shift_instruction [(DATA_FIFO - 1):0] <= rdata_data [(DATA_FIFO - 1):0];
                            rd_data <= 1;
                        end
                    end
                end
                else begin
                    enable_tck <= 1;
                    state <= ST_DELAY;
                    state_reserved <= ST_TMS;
                    count_transaction <= count_transaction + 1;
                    shift_tms <= {shift_tms [(DATA_TMS - 2):0], 1'b0};
                end
            end
            //////////////////////////////////////////////////
            ST_DELAY : begin
                rd_data <= 0;
                rd_instruction <= 0;
                if (count < (FREQUENCY_DIVIDER - 1)) begin
                    count <= count + 1;
                end
                else if (count < (FREQUENCY_DIVIDER * 2 - 2)) begin
                    count <= count + 1;
                    if (enable_tck == 1) begin
                        tck <= 1;
                    end
                end
                else begin
                    state <= state_reserved;
                    if (enable_tck == 1) begin
                        tck <= 1;
                        enable_tck <= 0;
                    end
                end
            end
            //////////////////////////////////////////////////
            default : begin 
                state <= ST_IDLE;
            end
        endcase
    end
end

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////