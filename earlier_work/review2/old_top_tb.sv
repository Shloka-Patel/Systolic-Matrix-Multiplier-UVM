// top_tb.sv
module top_tb;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    bit clk = 0;
    always #5 clk = ~clk;

    matrix_if vif(clk);

    matrix_multiplier dut (
        .clk  (clk),
        .rst  (vif.rst),
        .A    (vif.A),
        .B    (vif.B),
        .C    (vif.C),
        .done (vif.done)
    );

    initial begin
        uvm_config_db#(virtual matrix_if)::set(null, "*", "vif", vif);
        run_test("matrix_test");
    end
endmodule 

