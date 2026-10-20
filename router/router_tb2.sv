// ============================================================
// router_tb2.sv
// ------------------------------------------------------------
// Main self-checking router testbench.
//
// This bench exercises the router through a small set of
// transactions: input handshake, FIFO fill, route assignment,
// request and grant generation, output data validation, and
// FIFO pop behavior. It is the primary verification bench for
// the design and reports PASS/FAIL summaries at the end.
// ============================================================
`timescale 1ns/1ps

module router_tb;

    localparam int FLIT_WIDTH = 48;
    localparam int FIFO_DEPTH = 4;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    logic clk;
    logic rst;

    // ============================================================
    // INPUT PORTS
    // ============================================================

    logic [4:0] in_valid;
    logic [FLIT_WIDTH-1:0] in_flit [5];
    logic [4:0] in_ready;

    // ============================================================
    // OUTPUT PORTS
    // ============================================================

    logic [4:0] out_valid;
    logic [5*FLIT_WIDTH-1:0] out_flit;
    logic [4:0] out_ready;

    // ============================================================
    // FIFO OCCUPANCY
    // ============================================================

    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_occupancy [5];

    // ============================================================
    // TEST COUNTERS
    // ============================================================

    integer pass_count;
    integer fail_count;

    // ============================================================
    // EXPECTED FLITS
    // ============================================================

    logic [FLIT_WIDTH-1:0] local_flit;
    logic [FLIT_WIDTH-1:0] east_flit;
    logic [FLIT_WIDTH-1:0] north_flit;

    // ============================================================
    // CLOCK
    // ============================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ============================================================
    // DUT
    // ============================================================

    noc_router #(
        .FLIT_WIDTH (FLIT_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .ADDR_WIDTH (4),
        .X_ADDR     (4'd0),
        .Y_ADDR     (4'd0)
    ) DUT (

        .clk            (clk),
        .rst            (rst),

        .in_valid       (in_valid),
        .in_flit        (in_flit),
        .in_ready       (in_ready),

        .out_valid      (out_valid),
        .out_flit       (out_flit),
        .out_ready      (out_ready),

        .fifo_occupancy (fifo_occupancy)
    );

    // ============================================================
    // PASS TASK
    // ============================================================

    task automatic PASS(input string msg);
        begin
            $display("[PASS] %s", msg);
            pass_count = pass_count + 1;
        end
    endtask

    // ============================================================
    // FAIL TASK
    // ============================================================

    task automatic FAIL(input string msg);
        begin
            $display("[FAIL] %s", msg);
            fail_count = fail_count + 1;
        end
    endtask

    // ============================================================
    // CHECK INPUT HANDSHAKE
    // ============================================================

    task automatic check_input_handshake(
        input int port
    );
        begin

            if (in_valid[port] && in_ready[port]) begin

                PASS($sformatf(
                    "INPUT HANDSHAKE : port %0d",
                    port
                ));

            end
            else begin

                FAIL($sformatf(
                    "INPUT HANDSHAKE : port %0d VALID=%b READY=%b",
                    port,
                    in_valid[port],
                    in_ready[port]
                ));

            end

        end
    endtask

    // ============================================================
    // CHECK FIFO
    // ============================================================

    task automatic check_fifo(
        input int port
    );
        begin

            if (DUT.fifo_valid[port]) begin

                PASS($sformatf(
                    "FIFO contains flit : input %0d",
                    port
                ));

            end
            else begin

                FAIL($sformatf(
                    "FIFO empty : input %0d",
                    port
                ));

            end

        end
    endtask

    // ============================================================
    // CHECK ROUTING
    // ============================================================

    task automatic check_route(
        input int port,
        input int expected_route
    );
        begin

            if (DUT.route[port] == expected_route) begin

                PASS($sformatf(
                    "ROUTING : input %0d route=%0d",
                    port,
                    expected_route
                ));

            end
            else begin

                FAIL($sformatf(
                    "ROUTING : input %0d expected=%0d actual=%0d",
                    port,
                    expected_route,
                    DUT.route[port]
                ));

            end

        end
    endtask

    // ============================================================
    // CHECK REQUEST
    // ============================================================

    task automatic check_request(
        input int output_port,
        input int input_port
    );
        begin

            if (DUT.request[output_port][input_port]) begin

                PASS($sformatf(
                    "REQUEST : output %0d <- input %0d",
                    output_port,
                    input_port
                ));

            end
            else begin

                FAIL($sformatf(
                    "REQUEST MISSING : output %0d <- input %0d",
                    output_port,
                    input_port
                ));

            end

        end
    endtask

    // ============================================================
    // CHECK GRANT
    // ============================================================

    task automatic check_grant(
    input int output_port,
    input int input_port
);
    int grant_index;

    begin

        grant_index = output_port * 5 + input_port;

        if (DUT.grant_flat[grant_index]) begin

            PASS($sformatf(
                "GRANT : output %0d <- input %0d",
                output_port,
                input_port
            ));

        end
        else begin

            FAIL($sformatf(
                "GRANT MISSING : output %0d <- input %0d",
                output_port,
                input_port
            ));

        end

    end
endtask

    // ============================================================
    // CHECK OUTPUT SIGNALS
    // ============================================================

    task automatic check_output(
        input int output_port,
        input logic [FLIT_WIDTH-1:0] expected_flit
    );
        begin

            // ----------------------------------------------------
            // OUT_VALID
            // ----------------------------------------------------

            if (out_valid[output_port]) begin

                PASS($sformatf(
                    "OUTPUT VALID : port %0d",
                    output_port
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT VALID MISSING : port %0d",
                    output_port
                ));

            end


            // ----------------------------------------------------
            // OUT_READY
            // ----------------------------------------------------

            if (out_ready[output_port]) begin

                PASS($sformatf(
                    "OUTPUT READY : port %0d",
                    output_port
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT READY LOW : port %0d",
                    output_port
                ));

            end


            // ----------------------------------------------------
            // OUTPUT HANDSHAKE
            // ----------------------------------------------------

            if (out_valid[output_port] &&
                out_ready[output_port]) begin

                PASS($sformatf(
                    "OUTPUT HANDSHAKE : port %0d",
                    output_port
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT HANDSHAKE MISSING : port %0d",
                    output_port
                ));

            end


            // ----------------------------------------------------
            // OUTPUT FLIT
            // ----------------------------------------------------

            if (out_flit[output_port*FLIT_WIDTH +: FLIT_WIDTH] == expected_flit) begin

                PASS($sformatf(
                    "OUTPUT FLIT CORRECT : port %0d data=%h",
                    output_port,
                    out_flit[output_port*FLIT_WIDTH +: FLIT_WIDTH]
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT FLIT WRONG : port %0d expected=%h actual=%h",
                    output_port,
                    expected_flit,
                    out_flit[output_port*FLIT_WIDTH +: FLIT_WIDTH]
                ));

            end

        end
    endtask

    // ============================================================
    // CHECK FIFO POP
    // ============================================================

    task automatic check_fifo_pop(
        input int port
    );
        begin

            if (DUT.fifo_pop[port]) begin

                PASS($sformatf(
                    "FIFO POP : input %0d",
                    port
                ));

            end
            else begin

                FAIL($sformatf(
                    "FIFO POP MISSING : input %0d",
                    port
                ));

            end

        end
    endtask


    // ============================================================
    // TEST ONE ROUTING TRANSACTION
    // ============================================================

    task automatic test_transaction(

        input string test_name,

        input logic [FLIT_WIDTH-1:0] test_flit,

        input int expected_route,

        input int expected_output

    );

        begin

            $display("");
            $display("----------------------------------------------");
            $display("%s", test_name);
            $display("----------------------------------------------");


            // ====================================================
            // STEP 1
            // Drive input while clock is LOW
            // ====================================================

            @(negedge clk);

            in_valid[0] = 1'b1;
            in_flit[0]  = test_flit;


            // ====================================================
            // STEP 2
            // Check READY before handshake
            // ====================================================

            #1;

            if (in_ready[0]) begin

                PASS("INPUT READY asserted");

            end
            else begin

                FAIL("INPUT READY not asserted");

            end


            // ====================================================
            // STEP 3
            // Actual input handshake occurs here
            // ====================================================

            @(posedge clk);

            #1;

            check_input_handshake(0);


            // ====================================================
            // STEP 4
            // Stop driving VALID
            // ====================================================

            @(negedge clk);

            in_valid[0] = 1'b0;


            // ====================================================
            // STEP 5
            // Allow router combinational logic to settle
            // ====================================================

            #1;


            // ====================================================
            // STEP 6
            // FIFO
            // ====================================================

            check_fifo(0);
            if (DUT.fifo_flit[0] == test_flit) begin
    PASS($sformatf(
        "FIFO DATA CORRECT : %h",
        DUT.fifo_flit[0]
    ));
end
else begin
    FAIL($sformatf(
        "FIFO DATA WRONG : expected=%h actual=%h",
        test_flit,
        DUT.fifo_flit[0]
    ));
end

            // ====================================================
            // STEP 7
            // ROUTING
            // ====================================================

            check_route(
                0,
                expected_route
            );


            // ====================================================
            // STEP 8
            // REQUEST
            // ====================================================

            check_request(
                expected_output,
                0
            );
$display("");
$display("========== ARBITER DEBUG ==========");

$display("REQUEST[0] = %b",
         DUT.request[0]);

$display("GRANT_FLAT = %025b",
         DUT.grant_flat);

$display("ARB0 REQUEST = %b",
         DUT.switch_allocator_inst
            .OUTPUT_ARBITER[0]
            .arbiter_inst.request);

$display("ARB0 GRANT = %b",
         DUT.switch_allocator_inst
            .OUTPUT_ARBITER[0]
            .arbiter_inst.grant);

$display("ARB0 POINTER = %b",
         DUT.switch_allocator_inst
            .OUTPUT_ARBITER[0]
            .arbiter_inst.pointer);

$display("ARB0 INDEX = %b",
         DUT.switch_allocator_inst
            .OUTPUT_ARBITER[0]
            .arbiter_inst.grant_index);

$display("==================================");

            // ====================================================
            // STEP 9
            // GRANT
            // ====================================================

            check_grant(
                expected_output,
                0
            );


            // ====================================================
            // STEP 10
            // OUTPUT MUST BE VALID
            // ====================================================

            if (out_valid[expected_output]) begin

                PASS($sformatf(
                    "OUT_VALID asserted : output %0d",
                    expected_output
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUT_VALID missing : output %0d",
                    expected_output
                ));

            end


            // ====================================================
            // STEP 11
            // OUTPUT DATA
            // ====================================================

            if (out_flit[expected_output*FLIT_WIDTH +: FLIT_WIDTH] == test_flit) begin

                PASS($sformatf(
                    "OUTPUT FLIT correct : output %0d",
                    expected_output
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT FLIT wrong : output %0d expected=%h actual=%h",
                    expected_output,
                    test_flit,
                    out_flit[expected_output*FLIT_WIDTH +: FLIT_WIDTH]
                ));

            end


            // ====================================================
            // STEP 12
            // OUTPUT READY
            // ====================================================

            if (out_ready[expected_output]) begin

                PASS($sformatf(
                    "OUTPUT READY asserted : output %0d",
                    expected_output
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT READY missing : output %0d",
                    expected_output
                ));

            end


            // ====================================================
            // STEP 13
            // OUTPUT HANDSHAKE
            // ====================================================

            if (out_valid[expected_output] &&
                out_ready[expected_output]) begin

                PASS($sformatf(
                    "OUTPUT HANDSHAKE ready : output %0d",
                    expected_output
                ));

            end
            else begin

                FAIL($sformatf(
                    "OUTPUT HANDSHAKE missing : output %0d",
                    expected_output
                ));

            end


            // ====================================================
            // STEP 14
            // FIFO POP
            // ====================================================

            check_fifo_pop(0);


            // ====================================================
            // STEP 15
            // Actual output transfer clock edge
            // ====================================================

            @(posedge clk);

            #1;

            // Transaction should now have been consumed.

            if (!DUT.fifo_valid[0]) begin

                PASS("FIFO emptied after output transfer");

            end
            else begin

                FAIL("FIFO still contains flit after output transfer");

            end

        end

    endtask


    // ============================================================
    // MAIN TEST
    // ============================================================

    initial begin

        pass_count = 0;
        fail_count = 0;


        // ========================================================
        // INITIAL VALUES
        // ========================================================

        rst = 1'b1;

        in_valid = 5'b00000;

        out_ready = 5'b11111;

        for (int i = 0; i < 5; i = i + 1)
            in_flit[i] = '0;


        // ========================================================
        // HEADER
        // ========================================================

        $display("");
        $display("==============================================");
        $display("        NoC ROUTER SELF-CHECKING TB");
        $display("==============================================");
        $display("");


        // ========================================================
        // RESET
        // ========================================================

        repeat (2)
            @(posedge clk);

        #1;

        if ((in_ready == 5'b11111) &&
            (DUT.fifo_valid == 5'b00000)) begin

            PASS("RESET / INITIAL STATE");

        end
        else begin

            FAIL("RESET / INITIAL STATE");

        end

        rst = 1'b0;


        // ========================================================
        // DEFINE TEST FLITS
        // ========================================================

        // Router coordinate = (0,0)

        // --------------------------------------------------------
        // LOCAL
        // DEST = (0,0)
        // --------------------------------------------------------

        local_flit = {
            4'd0,       // DEST X
            4'd0,       // DEST Y
            8'd0,       // SOURCE X
            8'd0,       // SOURCE Y
            16'hAAAA,   // DATA
            1'b1,       // HEAD
            1'b1,       // TAIL
            6'd0
        };


        // --------------------------------------------------------
        // EAST
        // DEST = (1,0)
        // --------------------------------------------------------

        east_flit = {
            4'd1,       // DEST X
            4'd0,       // DEST Y
            8'd0,       // SOURCE X
            8'd0,       // SOURCE Y
            16'hBBBB,   // DATA
            1'b1,       // HEAD
            1'b1,       // TAIL
            6'd0
        };


        // --------------------------------------------------------
        // NORTH
        // DEST = (0,1)
        // --------------------------------------------------------

        north_flit = {
            4'd0,       // DEST X
            4'd1,       // DEST Y
            8'd0,       // SOURCE X
            8'd0,       // SOURCE Y
            16'hCCCC,   // DATA
            1'b1,       // HEAD
            1'b1,       // TAIL
            6'd0
        };


        // ========================================================
        // TEST 1
        // ========================================================

        test_transaction(
            "TEST 1 : LOCAL ROUTING",
            local_flit,
            0,
            0
        );


        // ========================================================
        // WAIT
        // ========================================================

        repeat (2)
            @(posedge clk);


        // ========================================================
        // TEST 2
        // ========================================================

        test_transaction(
            "TEST 2 : EAST ROUTING",
            east_flit,
            3,
            3
        );


        // ========================================================
        // WAIT
        // ========================================================

        repeat (2)
            @(posedge clk);


        // ========================================================
        // TEST 3
        // ========================================================

        test_transaction(
            "TEST 3 : NORTH ROUTING",
            north_flit,
            1,
            1
        );


        // ========================================================
        // FINAL RESULT
        // ========================================================

        repeat (2)
            @(posedge clk);


        $display("");
        $display("==============================================");
        $display("             VERIFICATION RESULT");
        $display("==============================================");

        $display("PASS : %0d", pass_count);
        $display("FAIL : %0d", fail_count);


        if (fail_count == 0) begin

            $display("");
            $display("*************** ALL TESTS PASSED ************");

        end
        else begin

            $display("");
            $display("*************** TESTS FAILED ****************");

        end


        $display("==============================================");
        $display("");

        $finish;

    end


    // ============================================================
    // WAVEFORM
    // ============================================================

    initial begin

        $dumpfile("router.vcd");

        $dumpvars(0, router_tb);

    end

endmodule