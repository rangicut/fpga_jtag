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
    parameter DATA_INSTRUCTION = 6,
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
    output logic [7:0] len,
    output logic end_op,
    output logic conf_op,
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
ST_WR_DATA, ST_DELAY, ST_ID} state_type;

//initial constants
localparam ID_INSTRUCTION = 6'b100100;
localparam CFG_IN_INSTRUCTION = 6'b101000;
localparam JSTART_INSTRUCTION = 6'b001100;

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
        end_op <= 0;
        conf_op <= 0;
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
                    state <= ST_ID;
                    initial_index <= initial_index + 1;
                end
                if ((initial_index == 2) && (busy == 0)) begin
                    state <= ST_WR_INSTRUCTION;
                    initial_index <= initial_index + 1;
                end
                if ((initial_index == 3) && (busy == 0)) begin
                    state <= ST_WR_DATA;
                    initial_index <= initial_index + 1;
                end
                if ((initial_index == 4) && (busy == 0)) begin
                    state <= ST_WR_INSTRUCTION;
                    initial_index <= initial_index + 1;
                end
                if ((initial_index == 5) && (busy == 0)) begin
                    end_op <= 1;
                    initial_index <= initial_index + 1;
                end
                if ((initial_index == 6) && (busy == 0)) begin
                    end_op <= 0;
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
                    index <= index + 1;
                    case (initial_index)
                        1: wdata_instruction <= ID_INSTRUCTION;
                        3: wdata_instruction <= CFG_IN_INSTRUCTION; 
                        5: wdata_instruction <= JSTART_INSTRUCTION; 
                        default : wdata_instruction = 0;
                    endcase
                end
            end
            //////////////////////////////////////////////////
            ST_ID : begin  
                if (index == 4) begin
                    wr_data <= 0;
                    work <= 1;
                    op <= 1;
                    len <= 32;
                    state <= ST_DELAY;
                    conf_op <= 0;
                end
                else if (index == 3) begin
                    wr_data <= 1;
                    wdata_data <= 0; 
                    index <= index + 1; 
                end
                else if (index == 2) begin
                    wr_data <= 1;
                    wdata_data <= 0; 
                    index <= index + 1;
                end
                else if (index == 1) begin
                    wr_data <= 1;
                    wdata_data <= 0; 
                    index <= index + 1;
                end
                else if (index == 0) begin
                    wr_data <= 1;
                    wdata_data <= 0; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_WR_DATA : begin  
                    work <= 1;
                    op <= 1;
                    len <= 16;
                    state <= ST_DELAY;
                    conf_op <= 1;
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