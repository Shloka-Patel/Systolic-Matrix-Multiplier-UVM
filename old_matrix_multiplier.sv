// matrix_multiplier.sv
module matrix_multiplier (
    input  logic clk,
    input  logic rst,
    input  logic [7:0]  A [0:1][0:1],
    input  logic [7:0]  B [0:1][0:1],
    output logic [15:0] C [0:1][0:1],
    output logic done
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            C[0][0] <= 0; C[0][1] <= 0;
            C[1][0] <= 0; C[1][1] <= 0;
            done <= 0;
        end else begin
            C[0][0] <= A[0][0]*B[0][0] + A[0][1]*B[1][0];
            C[0][1] <= A[0][0]*B[0][1] + A[0][1]*B[1][1];
            C[1][0] <= A[1][0]*B[0][0] + A[1][1]*B[1][0];
            C[1][1] <= A[1][0]*B[0][1] + A[1][1]*B[1][1];
            done <= 1;
        end
    end
endmodule