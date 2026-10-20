// ============================================================
// fifo.sv
// ------------------------------------------------------------
// Generic synchronous FIFO used by the router input buffers.
//
// The FIFO stores flits in a circular memory buffer and tracks
// its head/tail positions with read and write pointers. The
// count field is used to detect full/empty conditions and to
// drive occupancy reporting.
// ============================================================
module noc_fifo #(
    parameter int WIDTH = 48,
    parameter int DEPTH = 4
)(
    input  logic clk,
    input  logic rst,

    input  logic             wr_en,
    input  logic [WIDTH-1:0] din,

    input  logic             rd_en,
    output logic [WIDTH-1:0] dout,

    output logic full,
    output logic empty,

    output logic [$clog2(DEPTH+1)-1:0] count
);

    localparam int PTR_WIDTH =
        (DEPTH <= 2) ? 1 : $clog2(DEPTH);

    logic [WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_ptr;
    logic [PTR_WIDTH-1:0] rd_ptr;

    always_ff @(posedge clk) begin

        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end

        else begin

            if (wr_en && !full) begin

                mem[wr_ptr] <= din;

                if (wr_ptr == DEPTH-1)
                    wr_ptr <= '0;
                else
                    wr_ptr <= wr_ptr + 1'b1;

            end

            if (rd_en && !empty) begin

                if (rd_ptr == DEPTH-1)
                    rd_ptr <= '0;
                else
                    rd_ptr <= rd_ptr + 1'b1;

            end

            case ({wr_en && !full, rd_en && !empty})

                2'b10:
                    count <= count + 1'b1;

                2'b01:
                    count <= count - 1'b1;

                default:
                    count <= count;

            endcase

        end

    end

    // Asynchronous read of current FIFO head.
    assign dout = mem[rd_ptr];

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

endmodule