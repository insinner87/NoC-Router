# Router Project Documentation

This project implements a small network-on-chip (NoC) router in SystemVerilog. The design includes input buffering, FIFO storage, routing logic, a round-robin switch allocator, and a simple crossbar-based output selection path.

The main goals are:
- accept flits from multiple input ports,
- store them in input FIFOs,
- route each flit toward a destination,
- arbitrate output-port access,
- forward the selected flit to the correct output.

## 1) Project structure

Core RTL files:
- `rtl/router/router.sv` — top-level router module; connects FIFOs, route logic, allocator, and crossbar.
- `rtl/router/input_buffer.sv` — per-port input buffer wrapper around the FIFO.
- `rtl/router/fifo.sv` — the actual FIFO implementation (`noc_fifo`).
- `rtl/router/routing_unit.sv` — determines the output port using destination coordinates.
- `rtl/router/switch_allocator.sv` — builds one arbiter per output port.
- `rtl/router/arbiter.sv` — round-robin arbiter logic.
- `rtl/router/flit.sv` — flit constants and port encoding package.
- `rtl/router/dummy_tx.sv` — simple transaction source that creates flits.
- `rtl/router/dummy_rx.sv` — simple sink that accepts flits.

Testbenches:
- `rtl/router/router_tb2.sv` — the main self-checking verification bench; this is the most important bench for functional validation.
- `rtl/router/router_tb.sv` — older or alternate testbench.
- `rtl/router/router_tb3.sv` — another variant.
- `rtl/router/router_tb4.sv` — explicit local-routing testbench.

Recommended keep set:
- `router.sv`
- `input_buffer.sv`
- `fifo.sv`
- `routing_unit.sv`
- `switch_allocator.sv`
- `arbiter.sv`
- `flit.sv`
- `router_tb2.sv`

Optional / historical:
- `router_tb.sv`
- `router_tb3.sv`
- `router_tb4.sv`
- `dummy_tx.sv`
- `dummy_rx.sv`

These extra files are useful for experimentation, but `router_tb2.sv` is the one that cleanly proves the main router behavior.

## 2) How the router works

### 2.1 Flit format
The flit is 48 bits wide. The router expects the destination to be encoded in the top bits:
- `[47:44]` = destination X
- `[43:40]` = destination Y

The rest of the flit contains source coordinates and payload information.

### 2.2 Input buffering
Each input port has an `input_buffer` instance. It wraps a FIFO and exposes:
- `in_valid` / `in_ready` handshake,
- `in_flit` as the input word,
- `pop` as the read request,
- `out_valid` / `out_flit` as the buffered output,
- `occupancy` for debug/congestion visibility.

### 2.3 Routing
`routing_unit` decides where a flit should go based on current router coordinates and destination coordinates. The routing policy is:
- if `dest_x > current_x` → EAST
- if `dest_x < current_x` → WEST
- else if `dest_y > current_y` → NORTH
- else if `dest_y < current_y` → SOUTH
- else → LOCAL

### 2.4 Request matrix and arbiter
The router builds a request matrix where each output port requests from multiple input ports. Then `switch_allocator` instantiates one round-robin arbiter per output. Each arbiter grants access to one input, preventing multiple simultaneous holders from the same output.

### 2.5 Crossbar output selection
The final stage selects, per output port, the flit from the winning input and drives that flit to the correct output bus. A valid bit is also set for that output only when a grant exists.

## 3) The real bug and its fix

The real failure was in the output path of the router.

Problem:
- The router was building output data in a packed bus style but then reading it using a pattern that Icarus-Verilog treated as `x` (unknown) values.
- This caused the output flit to look like `xxxxxxxxxxxx` even though the valid signal was asserted and the FIFO had valid data.

Root cause:
- The output assignment pattern did not match the simulator’s supported packed/unpacked bus semantics.
- The fix was to drive the output bus slice-by-slice using the correct bit range, for example:

```systemverilog
out_flit[cross_o*FLIT_WIDTH +: FLIT_WIDTH] = fifo_flit[cross_k];
```

and in the testbench to read it as:

```systemverilog
out_flit[output_port*FLIT_WIDTH +: FLIT_WIDTH]
```

This is the exact fix that was validated.

## 4) The command to run the correct bench

From PowerShell:

```powershell
Set-Location "C:\Users\legen\Desktop\Router\rtl\router"

& "D:\iverilog\bin\iverilog.exe" `
  -g2012 -Wall `
  -o tb2.out `
  router_tb2.sv router.sv input_buffer.sv fifo.sv switch_allocator.sv routing_unit.sv arbiter.sv flit.sv dummy_tx.sv dummy_rx.sv

& "D:\iverilog\bin\vvp.exe" tb2.out
```

This runs the main self-checking TB2 bench for the router.

## 5) How to interpret the output

The output from a successful run will look like this:

```text
[PASS] RESET / INITIAL STATE
[PASS] INPUT READY asserted
[PASS] FIFO DATA CORRECT : 000000aaaac0
[PASS] ROUTING : input 0 route=0
[PASS] GRANT : output 0 <- input 0
[PASS] OUT_VALID asserted : output 0
[PASS] OUTPUT FLIT correct : output 0
[PASS] FIFO emptied after output transfer
...
PASS : 40
FAIL : 0
```

Meaning:
- `[PASS]` means the check succeeded.
- `[FAIL]` means the DUT failed that specific verification step.
- `PASS : 40` means 40 checks passed.
- `FAIL : 0` means no checks failed.

The warning lines about `timescale` are not a functional problem. They are just warnings from Icarus about files inheriting a timescale from another file. They do not mean the design is broken.

## 6) What the final successful benchmark means

A successful `PASS : 40` and `FAIL : 0` result means:
- reset behavior is correct,
- input handshake works,
- FIFO writes and reads are correct,
- routing decisions match the expected output port,
- request matrix and arbiter grant logic are valid,
- output flit data reaches the correct output port,
- the FIFO is correctly popped after transfer,
- the router behaves as expected for the tested transactions.

## 7) Recommended cleanup

This project is already close to a clean RTL structure. The most important files to keep are the core router modules and the main self-checking testbench. The other testbench variants are useful for separate experiments, but they are not required for the main functional verification.

## 8) Summary

The design is valid and the key functional testbench passes once the output flit assignment bug is fixed. The smallest, most important validation command is the one in section 4, and the key success signal is:

```text
PASS : 40
FAIL : 0
```

That is the correct target result for the router implementation.
