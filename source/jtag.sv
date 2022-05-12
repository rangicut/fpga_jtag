//////////////////////////////////////////////////
//~:(
//@module: jtag.sv
//@author: Yafizov Airat
//@date: 12.05.2022
//@version: 1.0.0
//@description: jtag_interface
//~:)
//////////////////////////////////////////////////

module jtag
    #(
    parameter DATA_INSTRACTION = 10,  //instruction content
    parameter DATA_DATA = 8,  //data fifo
    parameter FIFO_DEPTH = 16  
    )

    (
    //SYSTEM
    input logic clk,
    input logic rst,
    //INPUT_CONTROL
    input logic [15:0] len, //transaction length 
    input logic op,  //type of transaction, 1-data, 0-instruction
    input logic work,  //permission to work
    //OUTPUT_CONTROL
    output logic busy,
    //INPUT_JTAG
    input logic tdo,
    //OUTPUT_JTAG
    output logic tdi,
    output logic tck,
    output logic tms,
    //OUTPUT_FIFO_instraction
    output logic [(DATA_INSTRACTION-1):0] wdata_instraction,
    output logic wr_instraction,
    input logic full_instraction,
    //INPUT_FIFO_intraction
    input logic  [(DATA_INSTRACTION-1):0] rdata_instraction,
    output logic rd_instraction,
    input logic empty_instraction,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_instraction,
    //OUTPUT_FIFO_data
    output logic [(DATA_DATA-1):0] wdata_data,
    output logic wr_data,
    input logic full_data,
    //INPUT_FIFO_data
    input logic  [(DATA_DATA-1):0] rdata_data,
    output logic rd_data,
    input logic empty_data,
    input logic [($clog2(FIFO_DEPTH) - 1):0] usedw_data
    );

//////////////////////////////////////////////////
//Local types
//////////////////////////////////////////////////

typedef enum logic [2:0] {ST_IDLE, ST_INSTRACTION, ST_TDI, ST_TDO, ST_PRE_TDO, ST_PRE_TDI, ST_PRE_INSTRACTION} state_type;

//////////////////////////////////////////////////
//Local params
//////////////////////////////////////////////////

// delay and frequency divider
localparam FREQUENCY_DIVIDER = 1;
localparam DELAY= FREQUENCY_DIVIDER * 2;

//initial constants
localparam DATA_TMS = 4;
localparam GO_SHIFT_IR = 4'b1100;
localparam GO_SHIFT_DR = 4'b0100;
localparam GO_EXIT = 4'b1100;

//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////
state_type state;
logic count_enable;
logic [15:0] count;  //counter
//shift registers
logic [(DATA_TMS - 1) :0] shift_tms;
logic [(DATA_TMS - 1) :0] next_shift_tms;
logic [(DATA_INSTRACTION - 1) :0] shift_instraction;
logic [(DATA_INSTRACTION - 1) :0] next_shift_instraction;




//////////////////////////////////////////////////
//counter
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (rst) begin
            count <= 0;
        end
    else if ((FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + 2 * DELAY) == count) begin
            count <= 0;
        end
    else if (count_enable == 1) begin
            count <= count + 1;
        end
    else begin
        count <= 0;
    end
end

//////////////////////////////////////////////////
//Shift register
//////////////////////////////////////////////////
always_ff @ (negedge clk) begin
    if (rst) begin
        next_shift_instraction <= 0;
        next_shift_tms <= 0;
    end
    else begin
        next_shift_instraction <= shift_instraction;
        next_shift_tms <= shift_tms;
    end
end

//////////////////////////////////////////////////
//tms and tdi retiming
//////////////////////////////////////////////////

assign tms = next_shift_tms [(DATA_TMS - 1)];
assign tdi = next_shift_instraction [(DATA_INSTRACTION - 1)];

//////////////////////////////////////////////////
//transactions state machine
//////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if (rst) begin
        shift_instraction <= 0;
        shift_tms <= 0;
        state <= ST_IDLE;
        count_enable <= 0;
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
            ST_INSTRACTION : begin // sending instruction status (transactions are reported on the counter)
                if ((FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + 2 * DELAY) == count) begin 
                    rd_instraction <= 0;
                    state <= ST_IDLE;
                    busy <= 0;
                    count_enable <= 0;
                end
                else if (count == (DELAY - FREQUENCY_DIVIDER * 2)) begin
                    shift_tms [(DATA_TMS - 1):0] <= GO_SHIFT_IR;
                end
                else if ((count > (DELAY - 1)) && (count < (FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + DELAY)) 
                && (count[FREQUENCY_DIVIDER - 1] == 0)) begin 
                    if (count < ((DATA_TMS) * FREQUENCY_DIVIDER * 2 + DELAY)) begin
                        if (count == ((DATA_TMS - 1) * FREQUENCY_DIVIDER * 2 + DELAY)) begin
                            shift_tms <= {next_shift_tms[(DATA_TMS - 2):0], 1'b0};
                            shift_instraction [(DATA_INSTRACTION - 1):0] <= rdata_instraction [(DATA_INSTRACTION - 1):0];
                            rd_instraction <= 1;
						end
                        else begin
                            shift_tms <= {next_shift_tms[(DATA_TMS - 2):0], 1'b0};
                            rd_instraction <= 0;
                        end
                    end
                    else if (count < ((DATA_TMS + len) * FREQUENCY_DIVIDER * 2 + DELAY)) begin
                        if (count == ((DATA_TMS + len - 1) * FREQUENCY_DIVIDER * 2 + DELAY)) begin 
                            shift_tms [(DATA_TMS - 1):0] <= GO_EXIT;
                            shift_instraction <= {next_shift_instraction [(DATA_INSTRACTION - 2):0], 1'b0};
                            rd_instraction <= 0;
						end
                        else begin
                            shift_instraction <= {next_shift_instraction [(DATA_INSTRACTION - 2):0], 1'b0};
                            rd_instraction <= 0;
                        end
                    end
                    else if (count < ((DATA_TMS * 2 + len)  * FREQUENCY_DIVIDER * 2 + DELAY)) begin
                        shift_tms <= {next_shift_tms[(DATA_TMS - 2):0],1'b0};
                        rd_instraction <= 0;
                    end
                end 
                else begin
                    rd_instraction <= 0;
                end 
            end
            //////////////////////////////////////////////////
            ST_TDO : begin // data receiving status (transactions are reported on the counter)
                if ((FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + 2 * DELAY) == count) begin 
                    rd_instraction <= 0;
                    state <= ST_IDLE;
                    busy <= 0;
                    count_enable <= 0;
                end
                else if (count == (DELAY - FREQUENCY_DIVIDER * 2)) begin
                    shift_tms [(DATA_TMS - 1):0] <= GO_SHIFT_DR;
                end
                else if ((count > (DELAY - 1)) && (count < (FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + DELAY))
                && (count[FREQUENCY_DIVIDER - 1] == 0)) begin 
                    if (count < ((DATA_TMS)  * FREQUENCY_DIVIDER * 2 + DELAY)) begin
                        shift_tms <= {next_shift_tms[(DATA_TMS - 2):0], 1'b0};
                    end
                    else if (count == ((DATA_TMS + len - 1)  * FREQUENCY_DIVIDER * 2 + DELAY)) begin 
                        shift_tms [(DATA_TMS - 1):0] <= GO_EXIT;
                    end
                    else if (count < ((DATA_TMS * 2 + len)  * FREQUENCY_DIVIDER * 2 + DELAY)) begin
                        shift_tms <= {next_shift_tms[(DATA_TMS - 2):0], 1'b0};
                    end
                end 
            end
            //////////////////////////////////////////////////
            ST_PRE_TDO : begin  
                state <= ST_TDO;
                count_enable <= 1;
            end
            //////////////////////////////////////////////////
            ST_PRE_INSTRACTION : begin  
                state <= ST_INSTRACTION;
                count_enable <= 1;
            end
            //////////////////////////////////////////////////
            default : begin 
                state <= ST_IDLE;
            end
         endcase
    end
end

//////////////////////////////////////////////////
//tck impulse generation logic
//////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if(rst) begin
        tck <= 0;
    end 
     else if (count == DELAY) begin
                tck <= 1;
        end
        else if ((count[FREQUENCY_DIVIDER - 1] == 0) && (count > (DELAY)) && 
        (count < (FREQUENCY_DIVIDER * 2 * len + FREQUENCY_DIVIDER * 4 * DATA_TMS + DELAY))) begin
                tck <= 1;
        end 
        else begin 
            tck <= 0;
        end
end


//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////
