// matrix_if.sv
interface matrix_if (input bit clk);
    logic rst;
    logic [7:0]  A [0:1][0:1];
    logic [7:0]  B [0:1][0:1];
    logic [15:0] C [0:1][0:1];
    logic done;
endinterface 

