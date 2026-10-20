// ============================================================
// arbiter.sv
// ------------------------------------------------------------
// Round-robin arbiter used by the switch allocator.
//
// The pointer tracks which input should win next. After a grant
// is issued, the pointer advances so the next request is treated
// fairly in a rotating order.
// ============================================================
module rr_arbiter #(
    parameter int NUM_INPUTS = 5
)(
    input  logic clk,
    input  logic rst,

    input  logic [NUM_INPUTS-1:0] request,

    output logic [NUM_INPUTS-1:0] grant,

    output logic [$clog2(NUM_INPUTS)-1:0] grant_index
);

    localparam int PTR_WIDTH =
        (NUM_INPUTS <= 2) ? 1 : $clog2(NUM_INPUTS);

    logic [PTR_WIDTH-1:0] pointer;

    // Indicates whether an input has already been selected
    logic found;

    integer i;
    integer index;

    // ============================================================
    // COMBINATIONAL ROUND-ROBIN ARBITRATION
    // ============================================================

    always @* begin

        grant       = '0;
        grant_index = '0;
        found       = 1'b0;

        for (i = 0; i < NUM_INPUTS; i = i + 1) begin

            index = pointer + i;

            if (index >= NUM_INPUTS)
                index = index - NUM_INPUTS;

            if (!found && request[index]) begin

                grant[index] = 1'b1;

                grant_index =
                    index[PTR_WIDTH-1:0];

                found = 1'b1;

            end

        end

    end

    // ============================================================
    // ROUND-ROBIN POINTER UPDATE
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            pointer <= '0;
        end

        else if (found) begin

            if (grant_index == NUM_INPUTS-1)
                pointer <= '0;
            else
                pointer <= grant_index + 1'b1;

        end

    end

endmodule