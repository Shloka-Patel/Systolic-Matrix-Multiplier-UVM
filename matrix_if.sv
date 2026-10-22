// matrix_if.sv -- bundles every DUT signal. Parameterized: same file for N = 2, 4, 8 ...
interface matrix_if #(parameter int N = 4, parameter int W = 8) (input logic clk);
    localparam int CW = 2*W + $clog2(N);

    logic          rst;
    logic          start;
    logic          busy;
    logic          done;
    logic [W-1:0]  A [0:N-1][0:N-1];
    logic [W-1:0]  B [0:N-1][0:N-1];
    logic [CW-1:0] C [0:N-1][0:N-1];
endinterface
