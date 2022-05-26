//////////////////////////////////////////////////
//~:(
//@module: jtag_fsm.sv
//@author: Yafizov Airat
//@date: 18.05.2022
//@version: 1.0.0
//@description: jtag_fsm
//~:)
//////////////////////////////////////////////////

module jtag_fsm
    #(
    parameter DATA_INSTRUCTION = 10,
    parameter DATA_FIFO = 8,
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //CONTROL
    output logic op,
    output logic work,
    input logic busy,
    //FIFO_instruction
    output logic [(DATA_INSTRUCTION-1):0] wdata_instruction,
    output logic wr_instruction,
    input logic full_instruction,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_instruction,
    //FIFO_data
    output logic [(DATA_FIFO-1):0] wdata_data,
    output logic wr_data,
    input logic full_data,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_data
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [3:0] {ST_IDLE, ST_WR_INSTRUCTION, 
ST_WR_DATA, ST_DELAY} state_type;

//initial constants
localparam ID_INSTRUCTION = 10'b0000000110;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
//сигналы разрешения
logic [5:0] index;
logic [3:0] initial_index;

//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        index <= 0;
        wr_data <= 0; 
        wr_instruction <= 0;
        state <= ST_IDLE;
        op <=0;
        work <=0;
        initial_index <= 0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                work <= 0;
                wr_data <= 0; 
                wr_instruction <= 0;
                index <=0;
                if ((initial_index == 0) && (busy == 0)) begin
                    state <= ST_WR_INSTRUCTION;
                    initial_index <= initial_index + 1;
                end
                if ((initial_index == 1) && (busy == 0)) begin
                    state <= ST_WR_DATA;
                    initial_index <= initial_index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_WR_INSTRUCTION : begin  
                if (index == 1) begin
                    wr_instruction <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_DELAY;
                end 
                else if (index == 0) begin
                    wr_instruction <= 1;
                    wdata_instruction <= ID_INSTRUCTION; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_WR_DATA : begin  
                if (index == 3) begin
                    wr_data <= 0;
                    work <= 1;
                    op <= 1;
                    state <= ST_DELAY;
                end 
                else if (index == 2) begin
                    wr_data <= 1;
                    wdata_data <= 8'b11000100; 
                    index <= index + 1;
                end
                else if (index == 1) begin
                    wr_data <= 1;
                    wdata_data <= 8'b11000100; 
                    index <= index + 1;
                end
                else if (index == 0) begin
                    wr_data <= 1;
                    wdata_data <= 8'b11000100; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_DELAY : begin
                state <= ST_IDLE;
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