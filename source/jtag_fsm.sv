//////////////////////////////////////////////////
//~:(
//@module: jtag_fsm.sv
//@author: Yafizov Airat
//@date: 18.05.2022
//@version: 1.0.0
//@description: jtag_fsm
//~:)
//////////////////////////////////////////////////

module spi_fsm
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
    input logic  [(DATA_INSTRUCTION-1):0] rdata_instruction,
    output logic rd_instruction,
    input logic empty_instruction,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_instruction,
    //FIFO_data
    output logic [(DATA_FIFO-1):0] wdata_data,
    output logic wr_data,
    input logic full_data,
    input logic  [(DATA_FIFO-1):0] rdata_data,
    output logic rd_data,
    input logic empty_data,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_data
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum {ST_IDLE, ST_WR_INSTRUCTION, 
ST_WR_DATA} state_type;

//initial constants
localparam ID_INSTRUCTION = 10'b0000000110;

//////////////////////////////////////////////////
//local registers
//////////////////////////////////////////////////

state_type state;
//сигналы разрешения
logic [5:0] index;


//////////////////////////////////////////////////
//Architecture
////////////////////////////////////////////////// 

//state machine
always_ff @(posedge clk) begin
    if (rst) begin
        index <= 0;
        wr_data <= 0; wr_instruction <= 0;
        rd_data <= 0; rd_instruction <= 0;
        state <= ST_IDLE;
        op <=0;
        work <=0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                work <= 0;
                op <= 0;
                wr_data <= 0; wr_instruction <= 0;
                rd_data <= 0; rd_instruction <= 0;
                index <=0;
            end
            //////////////////////////////////////////////////
            /*ST_WR_INSTRUCTION : begin  
                if (index == 3) begin
                    wr <= 0;
                    work <= 1;
                    op <= 0;
                    state <= ST_PREPARATION;
                    flag_read_int_ir <= 0;
                    flag_read_int_ir_cap <= 1;
                    len <= 32;
                end 
                else if (index == 2) begin
                    wr <= 1;
                    wdata <= {BSB_REGULAR_REG, 1'b0, 2'b0};
                    index <= index + 1;
                end    
                else if (index == 1) begin
                    wr <= 1;
                    wdata <= ADDR_IMR [7:0];
                    index <= index + 1;
                end 
                else if (index == 0) begin
                    wr <= 1;
                    wdata <= ADDR_IMR [15:8]; 
                    index <= index + 1;
                end
            end
            //////////////////////////////////////////////////
            ST_WR_DATA : begin  
                        state <= ST_PREPARATION;
                        flag_read_int_sir <= 1;
                        flag_read_int_ir_cap <= 0;
                        rd <= 1;
                        read_int_ir <= rdata;
            end*/
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