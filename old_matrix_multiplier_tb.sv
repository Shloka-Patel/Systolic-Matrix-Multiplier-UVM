`timescale 1ns/1ps

module matrix_multiplier_tb;

    reg [7:0] A [0:1][0:1];
    reg [7:0] B [0:1][0:1];

    wire [15:0] C [0:1][0:1];

    // Instantiate the matrix multiplier
    matrix_multiplier uut (
        .A(A),
        .B(B),
        .C(C)
    );

    initial begin

        // Matrix A
        // 1  2
        // 3  4
        A[0][0] = 1;
        A[0][1] = 2;
        A[1][0] = 3;
        A[1][1] = 4;

        // Matrix B
        // 5  6
        // 7  8
        B[0][0] = 5;
        B[0][1] = 6;
        B[1][0] = 7;
        B[1][1] = 8;

        // Wait for calculation
        #10;

        // Display result
        $display("Matrix A:");
        $display("%d  %d", A[0][0], A[0][1]);
        $display("%d  %d", A[1][0], A[1][1]);

        $display("Matrix B:");
        $display("%d  %d", B[0][0], B[0][1]);
        $display("%d  %d", B[1][0], B[1][1]);

        $display("Matrix C = A * B:");
        $display("%d  %d", C[0][0], C[0][1]);
        $display("%d  %d", C[1][0], C[1][1]);

        $finish;
    end

endmodule