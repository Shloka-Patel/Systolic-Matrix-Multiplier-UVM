// systolic_matmul.sv -- parameterized N x N output-stationary systolic matrix multiplier
//   C = A x B      A,B : N x N, W-bit unsigned     C : N x N, CW-bit (cannot overflow)
//
//   Handshake : pulse `start` for ONE clock with A,B valid.
//               `busy` is high while computing; `done` goes high when C is valid
//               and stays high until the next `start`.
//   Latency   : 3N-1 clock edges from the `start` edge to the first cycle with done=1
//               (3N-2 compute cycles + 1 to register the final accumulate)
module systolic_matmul #(
    parameter int N  = 4,
    parameter int W  = 8,
    parameter int CW = 2*W + $clog2(N)   // N products of 2W bits each cannot overflow this
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
    localparam int LAST = 3*N - 3;              // last cycle in which a PE accumulates
    localparam int TW   = $clog2(3*N) + 1;      // counter width

    typedef enum logic [1:0] {S_IDLE = 2'd0, S_RUN = 2'd1, S_DONE = 2'd2} state_t;
    state_t         state;
    logic [TW-1:0]  t;
    logic [W-1:0]   A_reg [0:N-1][0:N-1];
    logic [W-1:0]   B_reg [0:N-1][0:N-1];

    wire run = (state == S_RUN);
    wire clr = (state != S_RUN) && start;       // clears PEs on the same edge A,B are latched
    assign busy = run;
    assign done = (state == S_DONE);

    // ---------------- controller ----------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            t     <= '0;
        end else begin
            case (state)
                S_IDLE, S_DONE: begin
                    if (start) begin
                        state <= S_RUN;
                        t     <= '0;
                    end
                end
                S_RUN: begin
                    if (t == TW'(LAST)) state <= S_DONE;
                    else                t     <= t + 1'b1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    // latch the operands on the start edge
    always_ff @(posedge clk) begin
        if (state != S_RUN && start) begin
            A_reg <= A;
            B_reg <= B;
        end
    end

    // ---------------- skewed feeders ----------------
    // row i of A enters PE[i][0] delayed by i cycles; column j of B enters PE[0][j] delayed by j
    logic [W-1:0] a_feed [0:N-1];
    logic [W-1:0] b_feed [0:N-1];
    always_comb begin
        for (int i = 0; i < N; i++) begin
            if (run && (int'(t) >= i) && ((int'(t) - i) < N)) begin
                a_feed[i] = A_reg[i][int'(t) - i];
                b_feed[i] = B_reg[int'(t) - i][i];
            end else begin
                a_feed[i] = '0;
                b_feed[i] = '0;
            end
        end
    end

    // ---------------- PE grid ----------------
    logic [W-1:0] a_wire [0:N-1][0:N];     // a_wire[i][j] = A input of PE[i][j]
    logic [W-1:0] b_wire [0:N][0:N-1];     // b_wire[i][j] = B input of PE[i][j]

    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : g_feed_a
            assign a_wire[gi][0] = a_feed[gi];
        end
        for (gj = 0; gj < N; gj++) begin : g_feed_b
            assign b_wire[0][gj] = b_feed[gj];
        end
        for (gi = 0; gi < N; gi++) begin : g_row
            for (gj = 0; gj < N; gj++) begin : g_col
                pe #(.W(W), .AW(CW)) u_pe (
                    .clk  (clk),
                    .rst  (rst),
                    .clr  (clr),
                    .en   (run),
                    .a_in (a_wire[gi][gj]),
                    .b_in (b_wire[gi][gj]),
                    .a_out(a_wire[gi][gj+1]),
                    .b_out(b_wire[gi+1][gj]),
                    .acc  (C[gi][gj])
                );
            end
        end
    endgenerate
endmodule
