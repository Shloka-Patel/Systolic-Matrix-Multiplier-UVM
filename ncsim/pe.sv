// pe.sv -- Processing Element (MAC) for an output-stationary systolic array
// Every enabled clock edge:  acc <= acc + a_in*b_in ;  a and b are passed on (registered)
module pe #(
    parameter int W  = 8,          // operand width
    parameter int AW = 2*W + 4     // accumulator width
)(
    input  logic          clk,
    input  logic          rst,     // async reset
    input  logic          clr,     // synchronous clear (start of a new multiply)
    input  logic          en,      // accumulate / shift enable
    input  logic [W-1:0]  a_in,
    input  logic [W-1:0]  b_in,
    output logic [W-1:0]  a_out,   // goes to the PE on the right
    output logic [W-1:0]  b_out,   // goes to the PE below
    output logic [AW-1:0] acc      // running dot-product = C[i][j]
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            a_out <= '0;
            b_out <= '0;
            acc   <= '0;
        end else if (clr) begin
            a_out <= '0;
            b_out <= '0;
            acc   <= '0;
        end else if (en) begin
            a_out <= a_in;
            b_out <= b_in;
            acc   <= acc + AW'(a_in) * AW'(b_in);
        end
    end
endmodule
