// ============================================================
// input_buffer.sv
// ------------------------------------------------------------
// Per-port input buffer for the router.
//
// This module wraps a generic FIFO and exposes the standard
// valid/ready handshake used by the NoC. It can accept a flit,
// buffer it, and later expose the head flit to the routing and
// switch-allocation logic.
// ============================================================
module input_buffer #(
    parameter int FLIT_WIDTH = 48,
    parameter int FIFO_DEPTH = 4
)(
    input logic clk,
    input logic rst,

    input  logic                  in_valid,
    input  logic [FLIT_WIDTH-1:0] in_flit,
    output logic                  in_ready,

    input  logic pop,

    output logic                  out_valid,
    output logic [FLIT_WIDTH-1:0] out_flit,

    output logic [$clog2(FIFO_DEPTH+1)-1:0] occupancy
);

    logic full;
    logic empty;

    noc_fifo #(
        .WIDTH(FLIT_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) fifo_inst (

        .clk(clk),
        .rst(rst),

        .wr_en(in_valid && in_ready),
        .din(in_flit),

        .rd_en(pop),

        .dout(out_flit),

        .full(full),
        .empty(empty),

        .count(occupancy)

    );

    assign in_ready  = !full;
    assign out_valid = !empty;
    always @(posedge clk) begin

    #1;

    $display(
        "INPUT_BUFFER DEBUG: occupancy=%0d count=%0d empty=%b full=%b dout=%012h",
        occupancy,
        fifo_inst.count,
        empty,
        full,
        out_flit
    );

end

endmodule