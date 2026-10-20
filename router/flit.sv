// ============================================================
// flit.sv
// ------------------------------------------------------------
// Constants used by the router flit format and port numbering.
//
// The flit is a 48-bit packet word carrying destination, source,
// payload, and control bits. The port constants are used by the
// routing logic and the crossbar decision logic.
// ============================================================
package noc_pkg;

    parameter int FLIT_WIDTH = 48;

    parameter int X_WIDTH = 4;
    parameter int Y_WIDTH = 4;

    // Port encoding
    parameter logic [2:0] PORT_LOCAL = 3'd0;
    parameter logic [2:0] PORT_NORTH = 3'd1;
    parameter logic [2:0] PORT_SOUTH = 3'd2;
    parameter logic [2:0] PORT_EAST  = 3'd3;
    parameter logic [2:0] PORT_WEST  = 3'd4;

endpackage