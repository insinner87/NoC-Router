// ============================================================
// router.sv
// ------------------------------------------------------------
// Top-level five-port router.
//
// Each input port has its own FIFO. Routing logic computes the
// desired output, the allocator grants access to output ports,
// and the crossbar forwards the selected flit to the output bus.
// ============================================================
module noc_router #(
    parameter int FLIT_WIDTH = 48,
    parameter int FIFO_DEPTH = 4,
    parameter int ADDR_WIDTH = 4,

    parameter logic [ADDR_WIDTH-1:0] X_ADDR = '0,
    parameter logic [ADDR_WIDTH-1:0] Y_ADDR = '0
)(
    input logic clk,
    input logic rst,

    // ----------------------------------------
    // INPUT PORTS
    // ----------------------------------------

    input  logic [4:0] in_valid,

    input logic [FLIT_WIDTH-1:0] in_flit [5],

    output logic [4:0] in_ready,


    // ----------------------------------------
    // OUTPUT PORTS
    // ----------------------------------------

    output logic [4:0] out_valid,

    output logic [5*FLIT_WIDTH-1:0] out_flit,

    input logic [4:0] out_ready,


    // ----------------------------------------
    // DEBUG / CONGESTION INFORMATION
    // ----------------------------------------

    output logic [$clog2(FIFO_DEPTH+1)-1:0]
        fifo_occupancy [5]

);

    // ----------------------------------------
    // FIFO OUTPUTS
    // ----------------------------------------

    logic [4:0] fifo_valid;

    logic [FLIT_WIDTH-1:0] fifo_flit [5];

    logic [4:0] fifo_pop;


    // ----------------------------------------
    // ROUTING
    // ----------------------------------------

    logic [2:0] route [5];


    // ----------------------------------------
    // SWITCH REQUESTS
    // request[output][input]
    // ----------------------------------------

    logic [4:0] request [5];

    // 5 outputs × 5 inputs = 25 grants
    logic [24:0] grant_flat;
logic [FLIT_WIDTH*5-1:0] fifo_flit_flat;

    // ----------------------------------------
    // LOOP VARIABLES
    // ----------------------------------------

    integer r;

    integer cross_o;
    integer cross_k;

    integer pop_p;
    integer pop_o;


    // ========================================
    // FIVE INPUT BUFFERS
    // ========================================

    genvar i;

    generate

        for (i = 0; i < 5; i = i + 1) begin : INPUT_BUFFER_GEN

            input_buffer #(
                .FLIT_WIDTH(FLIT_WIDTH),
                .FIFO_DEPTH(FIFO_DEPTH)
            ) input_buffer_inst (

                .clk(clk),
                .rst(rst),

                .in_valid(in_valid[i]),
                .in_flit(in_flit[i]),

                .in_ready(in_ready[i]),

                .pop(fifo_pop[i]),

                .out_valid(fifo_valid[i]),
                .out_flit(fifo_flit[i]),

                .occupancy(fifo_occupancy[i])

            );

        end

    endgenerate
    genvar f;

generate
    for (f = 0; f < 5; f = f + 1) begin : FIFO_FLAT_GEN

        assign fifo_flit_flat[
            f*FLIT_WIDTH +: FLIT_WIDTH
        ] = fifo_flit[f];

    end
endgenerate 


    // ========================================
    // ROUTING UNITS
    // ========================================

    generate

        for (i = 0; i < 5; i = i + 1) begin : ROUTING_GEN

            routing_unit #(
                .ADDR_WIDTH(ADDR_WIDTH)
            ) routing_inst (

                .current_x(X_ADDR),
                .current_y(Y_ADDR),

                // Destination X
                .dest_x(
                    fifo_flit[i][47:44]
                ),

                // Destination Y
                .dest_y(
                    fifo_flit[i][43:40]
                ),

                .route(route[i])

            );

        end

    endgenerate


    // ========================================
    // REQUEST MATRIX
    // request[output][input]
    // ========================================

    always_comb begin

        for (r = 0; r < 5; r = r + 1)
            request[r] = 5'b00000;

        for (r = 0; r < 5; r = r + 1) begin

            if (fifo_valid[r])
                request[route[r]][r] = 1'b1;

        end

    end


    // ========================================
    // SWITCH ALLOCATOR
    // ========================================

    switch_allocator #(
        .NUM_PORTS(5)
    ) switch_allocator_inst (

        .clk(clk),
        .rst(rst),

        .request(request),

        .grant_flat(grant_flat)

    );


    // ========================================
    // CROSSBAR
    // ========================================

   always_comb begin

    out_valid = 5'b00000;

    for (cross_o = 0;
         cross_o < 5;
         cross_o = cross_o + 1) begin

        out_flit[cross_o*FLIT_WIDTH +: FLIT_WIDTH] = '0;

        for (cross_k = 0;
             cross_k < 5;
             cross_k = cross_k + 1) begin

            if (grant_flat[cross_o*5 + cross_k]) begin

                out_valid[cross_o] =
                    fifo_valid[cross_k];

                out_flit[
                    cross_o*FLIT_WIDTH +: FLIT_WIDTH
                ] =
                    fifo_flit[cross_k];

            end

        end

    end

end

    // ========================================
    // FIFO POP
    // ========================================

    always_comb begin

        fifo_pop = 5'b00000;

        for (pop_p = 0;
             pop_p < 5;
             pop_p = pop_p + 1) begin

            for (pop_o = 0;
                 pop_o < 5;
                 pop_o = pop_o + 1) begin

                if (grant_flat[pop_o*5 + pop_p] &&
                    out_ready[pop_o] &&
                    out_valid[pop_o]) begin

                    fifo_pop[pop_p] = 1'b1;

                end

            end

        end

    end

endmodule