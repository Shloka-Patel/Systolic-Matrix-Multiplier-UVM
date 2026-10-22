// top_tb.sv -- clock, interface, DUT, and test launch
//   compile with  +define+N_SIZE=<N>   (default 4);  add +define+WAVES to record a SimVision database
module top_tb;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import matrix_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;                       // 100 MHz

    matrix_if #(.N(N), .W(W)) vif (.clk(clk));

    systolic_matmul #(.N(N), .W(W)) dut (
        .clk  (clk),
        .rst  (vif.rst),
        .start(vif.start),
        .A    (vif.A),
        .B    (vif.B),
        .C    (vif.C),
        .busy (vif.busy),
        .done (vif.done)
    );

`ifdef WAVES
    initial begin
        $shm_open("waves.shm");
        $shm_probe("AS", top_tb);
    end
`endif

    initial begin
        uvm_config_db#(vif_t)::set(null, "*", "vif", vif);
        run_test("matrix_full_test");           // +UVM_TESTNAME=... on the command line overrides this
    end

    initial begin                               // watchdog: a hung DUT must never hang the lab PC
        #50000000;
        $display("WATCHDOG: simulation exceeded its time limit -- DUT never asserted done?");
        $finish;
    end
endmodule
