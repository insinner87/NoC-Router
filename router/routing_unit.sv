// ============================================================
// routing_unit.sv
// ------------------------------------------------------------
// Converts a destination coordinate into a router output port.
//
// The router is modeled as a 2D mesh node. Flits carry their
// destination X/Y values, and this unit selects the first
// direction that reduces the remaining Manhattan distance.
// ============================================================
module routing_unit #(
    parameter int ADDR_WIDTH = 4
)(
    input logic [ADDR_WIDTH-1:0] current_x,
    input logic [ADDR_WIDTH-1:0] current_y,

    input logic [ADDR_WIDTH-1:0] dest_x,
    input logic [ADDR_WIDTH-1:0] dest_y,

    output logic [2:0] route
);

    localparam logic [2:0] LOCAL = 3'd0;
    localparam logic [2:0] NORTH = 3'd1;
    localparam logic [2:0] SOUTH = 3'd2;
    localparam logic [2:0] EAST  = 3'd3;
    localparam logic [2:0] WEST  = 3'd4;

    always_comb begin

        if (dest_x > current_x)
            route = EAST;

        else if (dest_x < current_x)
            route = WEST;

        else if (dest_y > current_y)
            route = NORTH;

        else if (dest_y < current_y)
            route = SOUTH;

        else
            route = LOCAL;

    end

endmodule