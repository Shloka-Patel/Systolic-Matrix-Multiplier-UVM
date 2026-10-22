// matmul_sva.sv -- SystemVerilog Assertions for the systolic matrix multiplier.
// Kept OUT of the RTL (bound from outside) so the synthesizable files stay clean for Vivado.
// Add this file to the irun command; no change to the RTL is needed.
module matmul_sva #(
    parameter int N = 4
)(
    input logic clk,
    input logic rst,
    input logic start,
    input logic busy,
    input logic done
);
    localparam int LAT = 3*N - 1;               // clocks from the start edge to done=1

    int unsigned fail_cnt  = 0;
    int unsigned start_cnt = 0;
    int unsigned done_cnt  = 0;

    // A1: reset clears the status flags
    a_reset: assert property (@(posedge clk) rst |-> (!done && !busy))
        else begin fail_cnt++; $error("[SVA] a_reset: done/busy not cleared by reset"); end

    // A2: an accepted start makes the block busy (and not done) on the next clock
    a_start_busy: assert property (@(posedge clk) disable iff (rst) (start && !busy) |=> (busy && !done))
        else begin fail_cnt++; $error("[SVA] a_start_busy: start did not make busy=1,done=0"); end

    // A3: EXACT latency -- done stays low for 3N-2 clocks, then rises on clock 3N-1
    a_latency: assert property (@(posedge clk) disable iff (rst)
                                (start && !busy) |=> (!done)[*(LAT-1)] ##1 done)
        else begin fail_cnt++; $error("[SVA] a_latency: done did not rise exactly %0d clocks after start", LAT); end

    // A4: busy and done are never high together
    a_excl: assert property (@(posedge clk) disable iff (rst) !(busy && done))
        else begin fail_cnt++; $error("[SVA] a_excl: busy and done both high"); end

    // A5: done is held (result stable) until the next start
    a_done_hold: assert property (@(posedge clk) disable iff (rst) (done && !start) |=> done)
        else begin fail_cnt++; $error("[SVA] a_done_hold: done dropped without a start"); end

    // A6: protocol rule on the environment -- never pulse start while busy
    a_no_start_busy: assert property (@(posedge clk) disable iff (rst) busy |-> !start)
        else begin fail_cnt++; $error("[SVA] a_no_start_busy: start asserted while busy"); end

    // coverage of the interesting scenarios (also used to count transactions)
    // plain clocked counters (independent of cover-property action blocks)
    logic done_q = 1'b0;
    always @(posedge clk) begin
        done_q <= done;
        if (!rst) begin
            if (start && !busy)  start_cnt++;
            if (done && !done_q) done_cnt++;
        end
    end
    c_start: cover property (@(posedge clk) disable iff (rst) (start && !busy));
    c_done:  cover property (@(posedge clk) disable iff (rst) $rose(done));
    c_back2back: cover property (@(posedge clk) disable iff (rst) $rose(done) ##[1:3] start);

    final begin
        $display("[SVA] SUMMARY  N=%0d : %0d computations started, %0d completed, %0d assertion failures",
                 N, start_cnt, done_cnt, fail_cnt);
        if (fail_cnt == 0) $display("[SVA] ALL ASSERTIONS HELD");
        else               $display("[SVA] ASSERTION FAILURES -- see $error messages above");
    end
endmodule

bind systolic_matmul matmul_sva #(.N(N)) u_sva (
    .clk(clk), .rst(rst), .start(start), .busy(busy), .done(done)
);
