// matmul_flat.sv -- BASELINE for comparison: every product computed in parallel, 1 cycle.
// Needs N^3 multipliers (the systolic array needs only N^2). Same handshake as systolic_matmul.
module matmul_flat #(
    parameter int N  = 4,
    parameter int W  = 8,
    parameter int CW = 2*W + $clog2(N)
)(
    input  logic          clk,
    input  logic          rst,
    input  logic          start,
    input  logic [W-1:0]  A [0:N-1][0:N-1],
    input  logic [W-1:0]  B [0:N-1][0:N-1],
    output logic [CW-1:0] C [0:N-1][0:N-1],
    output logic          busy,
    output logic          done
);
    assign busy = 1'b0;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    C[i][j] <= '0;
        end else begin
            done <= 1'b0;
            if (start) begin
                for (int i = 0; i < N; i++) begin
                    for (int j = 0; j < N; j++) begin
                        logic [CW-1:0] s;
                        s = '0;
                        for (int k = 0; k < N; k++)
                            s = s + CW'(A[i][k]) * CW'(B[k][j]);
                        C[i][j] <= s;
                    end
                end
                done <= 1'b1;
            end
        end
    end
endmodule
