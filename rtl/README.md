# A beginner's guide to this five-port NoC router

This README explains the router as if you are seeing hardware routers for the
first time. It covers what the router does, how the separate SystemVerilog
files fit together, how one flit travels through the design, and how to run the
example in the testbench.

You do not need to understand every line of Verilog before following the main
idea. Start with the picture and example, then use the module descriptions to
connect that idea back to the source code.

## 1. What are we building?

**NoC** means **Network-on-Chip**. It is a way for different parts of a chip
to send data to one another. A NoC usually contains multiple routers connected
by links. This project implements just **one router**, not the whole network.

This router has five input ports and five output ports:

```text
             North (1)
                |
                v
 West (4) --> +-------+ --> East (3)
              |Router |
 Local (0) -->|       |
              +-------+
                |
                v
             South (2)
```

The arrows in this picture mean "connected to a port." In the RTL, every port
has both an input interface and an output interface. For example, the Local
input receives flits from the local processing element, while the Local
output sends flits toward it.

The router looks inside each waiting flit, reads its destination, and forwards
that flit to the matching output. The payload is not changed.

## 2. A few words used in the code

| Word | Plain-language meaning |
| --- | --- |
| **bit** | A digital value: `0` or `1`. |
| **clock** | A repeating timing signal. This router normally changes stored state on its rising edge. |
| **flit** | A small unit of data sent through a router. Here one flit is one complete packet. |
| **FIFO** | A queue: First In, First Out. The oldest stored flit comes out first. |
| **input** | The side where a flit enters this router. |
| **output** | The side where a flit leaves this router. |
| **destination** | The output port number written inside a flit. |
| **payload** | The useful data carried in the flit besides its destination. |
| **valid/ready handshake** | A transfer happens when `valid` and `ready` are both high at a rising clock edge. |
| **backpressure** | A receiver temporarily says "not ready"; the sender must wait without losing data. |
| **arbitration** | Choosing one requester when multiple inputs want the same output. |
| **crossbar** | The data switch that connects a chosen input to a chosen output. |

## 3. The flit format used here

The default flit has 48 bits:

```text
bit number:  47 46 45 | 44 ................................. 0
             destination |              payload
```

The three top bits, `flit[47:45]`, tell the router which output to use. The
remaining 45 bits, `flit[44:0]`, are payload and pass through unchanged.

| Destination bits | Decimal value | Output port |
| --- | ---: | --- |
| `3'b000` | 0 | Local |
| `3'b001` | 1 | North |
| `3'b010` | 2 | South |
| `3'b011` | 3 | East |
| `3'b100` | 4 | West |
| `3'b101`, `3'b110`, `3'b111` | 5, 6, 7 | Invalid |

The words "input" and "destination" answer different questions:

- **Input:** Which side did this flit arrive from?
- **Destination:** Which side should this flit leave from?

For example, a flit can arrive at the Local input and have East as its
destination. It waits in the Local input's FIFO, then leaves at the East
output.

### Making an example flit

The testbench has a helper function:

```systemverilog
make_flit(destination, payload)
```

For example:

```systemverilog
make_flit(3'd3, 45'd203)
```

means:

- destination `3'd3` = East;
- payload `45'd203` = the number 203 stored in the payload bits.

In hexadecimal, that complete 48-bit flit is `48'h6000000000CB`:

- destination `3'd3` contributes `3 << 45` = `48'h600000000000`;
- payload 203 contributes `48'h0000000000CB`;
- together the flit is `48'h6000000000CB`.

## 4. Ready and valid: how two modules agree on a transfer

The router uses a common hardware rule called **ready/valid**. There is a
ready/valid pair on every input and every output.

### At an input

Suppose you want to send a flit on input 0:

1. Put the flit on `in_flit[0]`.
2. Set `in_valid[0]` to `1` to say "my flit is available."
3. Wait until `in_ready[0]` is also `1`.
4. At the next rising clock edge where both are `1`, the router accepts the
   flit into that input's FIFO.

The sender must keep `in_valid` high and the data unchanged while waiting for
`in_ready`. If the FIFO is full, `in_ready` becomes `0`; the sender waits
instead of overwriting an older flit.

### At an output

The router uses the same idea with `out_valid` and `out_ready`:

1. `out_valid[3]` means "the router is offering a flit on East."
2. The receiver sets `out_ready[3]` to `1` when it can accept a flit.
3. The transfer completes on a rising clock edge when both are `1`.
4. If `out_ready[3]` is `0`, the router keeps offering the same flit. It is
   not removed from the input FIFO until the transfer actually happens.

In short:

```text
transfer this cycle = valid AND ready at a rising clock edge
```

## 5. How the separate files fit together

The files make one router by assigning each job to a small module:

| File | Job |
| --- | --- |
| `noc_pkg.sv` | Shared settings: number of ports, default flit width, FIFO depth, and port numbers. |
| `fifo.sv` | Stores several flits and returns them in arrival order. |
| `input_buffer.sv` | One FIFO plus the ready/valid connection for one input port. |
| `round_robin_arbiter.sv` | Chooses one input among requesters for one output, fairly. It keeps a choice stable if that output is stalled. |
| `switch_allocator.sv` | Reads FIFO-head destinations, builds requests, flags invalid destinations, and instantiates one arbiter per output. |
| `crossbar.sv` | Copies each granted flit to its output and asks the source FIFO to remove it when the output accepts it. |
| `router_5port.sv` | Top-level module that wires all five buffers, the allocator, and the crossbar together. This is the module to instantiate in a larger design. |
| `router_5port_tb.sv` | Simulation-only testbench that drives example traffic and checks the answers automatically. |
| `Five_Port_NoC_Router_Beginner_Guide.pptx` | Companion presentation for the router design. It is not needed to compile or simulate the RTL. |
| `router_5port_test` | A previously compiled Icarus Verilog simulation output, not source code. It can be regenerated by compiling the testbench. |

### Why are there five FIFOs?

There is one FIFO on every input. If Local and North both receive flits, they
have separate waiting lines. The FIFO on one input does not overwrite or
reorder the data stored in another input's FIFO.

Each FIFO has a default depth of four, so it can hold up to four waiting
flits. A flit at the front (also called the **head**) is the one the router
tries to route next.

### Why do we need an allocator?

Imagine two input FIFOs both have a flit for East. East has only one output
wire, so it cannot send both flits at the exact same time. The switch allocator
asks East's arbiter to select one input. The other flit stays safely in its
FIFO until it gets a turn.

There is one arbiter for each output. That means Local and East can each select
a flit at the same time, as long as they select different inputs. This is how
the router can make multiple transfers in parallel.

### What does the crossbar do?

The allocator decides **which input wins**. The crossbar then moves the
winner's actual data to the correct output. These are separate jobs:

```text
allocator: "Input 0 gets to use East."
crossbar:  copy input 0's flit bits to the East output.
```

The crossbar also ensures the FIFO is popped only after the output's
ready/valid handshake. A decision or grant by itself does not discard data.

## 6. One complete example: Local input to East output

The testbench includes this exact kind of example in **TEST 2**. It sends a
flit into input 0 (Local) whose destination field is 3 (East):

```systemverilog
expected = make_flit(3'd3, 45'd203);
source = 0;
send_flit(source, expected);
expect_transfer(3, expected);
```

`source = 0` is the **input**. The `3` in `make_flit` and `expect_transfer`
is the **destination output**. The payload is 203.

Here is what happens:

### Step 1: The testbench creates the flit

`make_flit(3'd3, 45'd203)` packs a 3-bit East destination and a 45-bit
payload into the 48-bit word:

```text
flit[47:45] = 3'b011 (East, number 3)
flit[44:0]  = 203    (payload)
whole flit  = 48'h6000000000CB
```

### Step 2: It presents that word on Local input

`send_flit(0, expected)` puts the word on `in_flit[0]` and sets
`in_valid[0]`. The testbench keeps it there until `in_ready[0]` is high at a
rising edge. That edge writes the flit into the Local input FIFO.

The **source input** does not choose the destination automatically. The
destination bits inside the flit do that.

### Step 3: The allocator reads the FIFO head

After the write, the FIFO exposes its oldest flit to the router. The switch
allocator reads the top three destination bits. Because they are `3`, it
raises a request from input 0 to output 3 (East).

### Step 4: East's arbiter chooses an input

If no other input is competing for East, input 0 is granted immediately. If
other inputs are also asking for East, the round-robin arbiter chooses one,
and the flits that did not win remain in their FIFOs.

### Step 5: The crossbar shows the flit on East

The grant tells the crossbar to copy the Local FIFO head onto `out_flit[3]`.
Now `out_valid[3]` indicates that East has a flit available.

### Step 6: The receiver accepts it

The testbench normally has `out_ready[3] = 1`. Therefore, on a rising edge
where `out_valid[3]` is also `1`, the transfer completes. The crossbar pops
the Local FIFO, and the arbiter updates its round-robin priority.

The payload is unchanged. The flit went **from Local input to East output**;
the router did not turn it into a different flit.

## 7. How the example is represented in the testbench

The testbench is not hardware inside the router. It is a separate simulation
program that pretends to be senders and receivers:

- it toggles a simulated clock;
- it drives the router's input signals;
- it waits for handshakes;
- it checks that output signals contain the expected values;
- it calls `$fatal` to stop with a failure if a check is wrong.

The `send_flit` task behaves like a careful upstream sender. It asserts
`in_valid`, presents stable data, and waits for `in_ready` at a rising edge.
The `expect_transfer` task checks `out_valid` and output data, then waits for
the rising edge that accepts the flit.

In **TEST 2**, the testbench loops through all five destinations. For
destination 3 (East), it specifically picks source 0 (Local), so it checks
the Local-to-East example above. The testbench compares the entire 48-bit
output flit, not just the destination field. That checks that the right
payload also arrived intact.

The other test groups check:

1. **FIFO, arbitration, and a stalled grant:** multiple inputs request Local.
   The test checks that a stalled flit stays selected, then that other
   requesters get turns.
2. **All five routes:** each legal destination, including Local input to East.
3. **Parallel transfers:** two flits for different outputs transfer in the
   same cycle.
4. **Backpressure and FIFO capacity:** an output is blocked, its first flit
   remains stable, the FIFO fills, and a read/write together makes room.
5. **Invalid destination:** destination 7 is dropped and reported instead of
   blocking its FIFO forever.

The testbench prints a `PASS` after each group. If anything is wrong, `$fatal`
prints a `FAIL` message and stops the simulation. A successful run ends with
something like:

```text
TEST 1: FIFO, round-robin arbitration, and stable stalled grant
  PASS
TEST 2: all five destination routes
  PASS
TEST 3: simultaneous transfers on separate outputs
  PASS
TEST 4: output backpressure and input FIFO capacity
  PASS
TEST 5: invalid destination is discarded and reported
  PASS
ALL TESTS PASSED (15 checked transfers/conditions)
```

## 8. Run the testbench yourself

Install Icarus Verilog (`iverilog` and `vvp`) if you do not already have it.
Open PowerShell in the folder containing these `.sv` files (the `rtl` folder
in this project), then compile the design and testbench:

```powershell
iverilog -g2012 -s router_5port_tb -o router_5port_test.vvp noc_pkg.sv fifo.sv input_buffer.sv round_robin_arbiter.sv switch_allocator.sv crossbar.sv router_5port.sv router_5port_tb.sv
```

What these options mean:

- `iverilog` starts the simulator/compiler.
- `-g2012` enables SystemVerilog 2012 language features.
- `-s router_5port_tb` says the testbench is the simulation's top-level module.
- `-o router_5port_test.vvp` names the compiled simulation program.
- The rest of the command lists the package, hardware modules, and testbench.

If compilation succeeds, run the simulation:

```powershell
vvp .\router_5port_test.vvp
```

The simulation output is the test report. Look for `ALL TESTS PASSED`. If
Icarus prints `FAIL` or `$fatal`, the named check did not pass. The compiled
`router_5port_test.vvp` file is generated output; the `.sv` files are the
source. If you run the commands from the parent folder instead, prefix each
source filename with `rtl\` and use `-o rtl\router_5port_test.vvp`, then run
`vvp .\rtl\router_5port_test.vvp`.

## 9. Important limits of this small router

- It is one router, not a complete multi-router NoC.
- It routes one-flit packets. There is no packet header/body/tail sequence.
- Destinations are direct port numbers, not `x/y` coordinates.
- Invalid destinations 5, 6, and 7 are dropped and reported.
- The default flit width is 48 bits and the default input FIFO depth is four.
- The design uses active-low asynchronous reset `rst_n`.
- A larger router or a different packet format would need corresponding RTL
  and testbench changes.

## 10. A useful way to read the RTL

Try following the example through the files in this order:

1. In `router_5port_tb.sv`, find **TEST 2** and the `send_flit` /
   `expect_transfer` calls.
2. In `router_5port.sv`, follow `in_flit[0]` into generated input buffer 0.
3. In `input_buffer.sv`, see how a successful input handshake becomes a FIFO
   write.
4. In `fifo.sv`, see how the written flit becomes the oldest queue item.
5. In `switch_allocator.sv`, see how the destination bits create an East
   request.
6. In `round_robin_arbiter.sv`, see how that request becomes a grant.
7. In `crossbar.sv`, see how the granted flit appears on East and how a
   successful output handshake pops the input FIFO.

That is the complete journey: **sender -> input FIFO -> destination decode ->
arbitration -> crossbar -> receiver**.
