// ============================================================
// switch_allocator.sv
// ------------------------------------------------------------
// Builds one round-robin arbiter for each output port.
//
// The request matrix encodes which input ports are asking for a
// given output. Each output port is granted to at most one input
// in a fair, round-robin order.
// ============================================================
module switch_allocator #(
    parameter int NUM_PORTS = 5
)(
    input  logic clk,
    input  logic rst,

    input  logic [NUM_PORTS-1:0] request [NUM_PORTS],

    output logic [NUM_PORTS*NUM_PORTS-1:0] grant_flat
);

    genvar o;

    generate

        for (o = 0; o < NUM_PORTS; o = o + 1) begin : OUTPUT_ARBITER

            rr_arbiter #(
                .NUM_INPUTS(NUM_PORTS)
            ) arbiter_inst (

                .clk(clk),
                .rst(rst),

                .request(request[o]),

                .grant(
                    grant_flat[
                        o*NUM_PORTS +: NUM_PORTS
                    ]
                ),

                .grant_index()

            );

        end

    endgenerate

endmodule