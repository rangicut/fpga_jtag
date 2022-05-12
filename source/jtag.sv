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
    parameter DATA_INSTRACTION = 10,
    parameter DATA_FIFO = 8,
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //CONTROL
    input logic [15:0] len,
    input logic op, //type of transaction, 1-data, 0-instruction
    input logic work,
    output logic busy,
    //JTAG
    input logic tdo,
    output logic tdi,
    output logic tck,
    output logic tms,
    //FIFO_instraction
    output logic [(DATA_INSTRACTION-1):0] wdata_instraction,
    output logic wr_instraction,
    input logic full_instraction,
    input logic  [(DATA_INSTRACTION-1):0] rdata_instraction,
    output logic rd_instraction,
    input logic empty_instraction,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_instraction,
    //FIFO_data
    output logic [(DATA_DATA-1):0] wdata_data,
    output logic wr_data,
    input logic full_data,
    input logic  [(DATA_DATA-1):0] rdata_data,
    output logic rd_data,
    input logic empty_data,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_data
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum {ST_IDLE, ST_INSTRACTION, ST_TDI, ST_TDO, ST_PRE_TDO, ST_PRE_TDI, ST_PRE_INSTRACTION} state_type;

//frequency divider
localparam FREQUENCY_DIVIDER = 1;

//initial constants
localparam DATA_TMS = 4;
localparam GO_SHIFT_IR = 4'b1100;
localparam GO_SHIFT_DR = 4'b0100;
localparam GO_EXIT = 4'b1100;

//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////

state_type state;
state_type state_reserved;
logic [3:0] count;  //counter
//shift registers
logic [(DATA_TMS - 1) :0] shift_tms;
logic [(DATA_INSTRACTION - 1) :0] shift_instraction;

//////////////////////////////////////////////////
//tms and tdi retiming
//////////////////////////////////////////////////

assign tms = shift_tms [(DATA_TMS - 1)];
assign tdi = shift_instraction [(DATA_INSTRACTION - 1)];

//////////////////////////////////////////////////
//Control FSM
//////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if(rst) begin
        shift_instraction <= 0;
        shift_tms <= 0;
        state <= ST_IDLE;
        rd_data <=0; rd_instraction <=0; 
        busy <=0;
    end 
    else begin
        case (state)
            //////////////////////////////////////////////////
            ST_IDLE : begin
                shift_instraction <= 0;
                shift_tms <= 0;
                rd_data <=0; rd_instraction <=0; 
                if ((work == 1) && (op == 0)) begin
                    state <= ST_PRE_INSTRACTION;
                    busy <= 1;
                end 
                if ((work == 1) && (op == 1)) begin
                    state <= ST_PRE_TDO;
                    busy <= 1;
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