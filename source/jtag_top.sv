//////////////////////////////////////////////////
//~:(
//@module: jtag_top.sv
//@author: Yafizov Airat
//@date: 13.05.22
//@version: 1.0.0
//@description: jtag_top
//~:)
//////////////////////////////////////////////////

module jtag_top
    #(
    parameter DATA_INSTRUCTION = 6,
    parameter DATA_FIFO = 8,
    parameter FIFO_DEPTH = 16
    )

    (
    //SYSTEM
    input logic clknotpll,
    //JTAG
    input logic tdo,
    output logic tdi,
    output logic tck,
    output logic tms
    );

//////////////////////////////////////////////////
//local signal
//////////////////////////////////////////////////

logic clk;
logic rst;

//count
logic [31:0] countrst = 0;

//fifo 1 signals
logic [(DATA_INSTRUCTION - 1):0] wdata_instruction;
logic [(DATA_INSTRUCTION - 1):0] rdata_instruction;
logic wr_instruction;
logic rd_instruction;
logic full_instruction;
logic empty_instruction;
logic [($clog2(FIFO_DEPTH) - 1):0] usedw_instruction;

//fifo 2 signals
logic [(DATA_FIFO - 1):0] wdata_data;
logic [(DATA_FIFO - 1):0] rdata_data;
logic wr_data;
logic rd_data;
logic full_data;
logic empty_data;
logic [($clog2(FIFO_DEPTH) - 1):0] usedw_data;

//control signals
logic op;
logic work;
logic busy;
logic end_op;
logic conf_op;
logic [7:0] len;

//////////////////////////////////////////////////
//reset counter for debugging
//////////////////////////////////////////////////
/*always_ff @(posedge clk) begin
    if (countrst == 0) begin
        rst <= 0;
        countrst <= countrst + 1;
    end
    else if (countrst < 500000000) begin
        countrst <= countrst + 1;
    end
    else if (countrst < 500000001) begin
        countrst <= countrst + 1;
        rst <= 1;
    end
    else if (countrst == 500000001) begin
        countrst <= 500000002;
        rst <= 0;
    end
end*/

//////////////////////////////////////////////////
//reset counter for modeling
//////////////////////////////////////////////////
always_ff @(posedge clk) begin
    if (countrst == 0) begin
        rst <= 0;
        countrst <= countrst + 1;
    end
    else if (countrst < 50) begin
        countrst <= countrst + 1;
    end
    else if (countrst < 51) begin
        countrst <= countrst + 1;
        rst <= 1;
    end
    else if (countrst == 51) begin
        countrst <= 52;
        rst <= 0;
    end
end

//////////////////////////////////////////////////
//buffer fifo
//INPUT: DATA AND PERMISSIN
//OUTPUT: BUFFER AND ITS STATUS
//////////////////////////////////////////////////


fifo #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_WIDTH(DATA_INSTRUCTION))
    fifo_inst1 (
        .clk(clk), .rst(rst),
        .wdata(wdata_instruction), .wr(wr_instruction), 
        .full(full_instruction), .rdata(rdata_instruction), 
        .rd(rd_instruction), .empty(empty_instruction),
        .usedw(usedw_instruction)
    );

fifo #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_WIDTH(DATA_FIFO))
    fifo_inst2 (
        .clk(clk), .rst(rst),
        .wdata(wdata_data), .wr(wr_data), .full(full_data),
        .rdata(rdata_data), .rd(rd_data), .empty(empty_data),
        .usedw(usedw_data)
    );

jtag #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_INSTRUCTION(DATA_INSTRUCTION), .DATA_FIFO(DATA_FIFO))
    jtag_inst (
        .clk(clk), .rst(rst),
        .empty_data(empty_data),
        .rdata_instruction(rdata_instruction), .rd_instruction(rd_instruction), 
        .empty_instruction(empty_instruction), .rd_data(rd_data),
        .work(work), .op(op), .busy(busy), .rdata_data(rdata_data), 
        .tdo(tdo), .tdi(tdi), .tck(tck), .tms(tms), .len(len), .end_op(end_op), .conf_op(conf_op)
    );

jtag_fsm #(.FIFO_DEPTH(FIFO_DEPTH), .DATA_INSTRUCTION(DATA_INSTRUCTION), .DATA_FIFO(DATA_FIFO))
    jtag_fsm_inst (
        .clk(clk), .rst(rst),
        .wdata_instruction(wdata_instruction), .wr_instruction(wr_instruction), 
        .full_instruction(full_instruction), .full_data(full_data),
        .wdata_data(wdata_data), .usedw_instruction(usedw_instruction),
		.wr_data(wr_data), .usedw_data(usedw_data),
        .work(work), .op(op), .busy(busy), .len(len), .end_op(end_op), .conf_op(conf_op)
    );

pll pll_inst (
        .inclk0(clknotpll), .areset(0),
        .c0(clk)
    ); 

//////////////////////////////////////////////////
endmodule
//////////////////////////////////////////////////