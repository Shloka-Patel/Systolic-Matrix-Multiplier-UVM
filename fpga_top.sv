// fpga_top.sv -- Basys3 demo: one fully-connected neural-network layer on the systolic array
//
//   Inputs : clk (100 MHz), btnC = START, btnU = RESET, sw[15:0]
//   Outputs: led[15:0]    (led[15] = DONE, lights when the result is valid)
//
//   MODE 0  (sw[15] = 0)  KNOWN-ANSWER TEST  -- the proof that the hardware is correct
//        Weights W and the 4 stored samples X come from ai_demo_data.svh (made by ai_demo.py).
//        Press btnC once, wait for led[15]. Then
//            sw[1:0] = class (row)   sw[3:2] = sample (column)
//        led[14:0] shows the score  S = (W x X)[class][sample]   (binary).
//        Compare with the table printed by ai_demo.py.
//   MODE 1  (sw[15] = 1)  LIVE INFERENCE
//        sw[2:0], sw[5:3], sw[8:6], sw[11:9] = the 4 input features (each 0..7, scaled x8).
//        Press btnC. led[3:0] = one-hot PREDICTED CLASS, led[15] = DONE.
//   (Press btnC again after changing sw[15] -- the result shown is always for the last START.)
module fpga_top #(
    parameter int DEB_CYCLES = 1_000_000,         // button debounce, ~10 ms @ 100 MHz
    parameter bit SW_INV     = 1'b1,              // 1 if slide switches read 0 when UP on your board
    parameter bit LED_INV    = 1'b0               // 1 if LEDs are active-low on your board
)(
    input  logic        clk,
    input  logic        btnC,
    input  logic        btnU,
    input  logic [15:0] sw_pin,
    output logic [15:0] led_pin
);
    `include "ai_demo_data.svh"

    localparam int N  = 4;
    localparam int W  = 8;
    localparam int CW = 2*W + $clog2(N);

    // ---------------- input conditioning ----------------
    // Buttons: the idle level (button NOT pressed) is captured right after power-up, so the
    // design works whether the board's buttons are active-high or active-low.
    logic [1:0] btnc_s = 2'b00;
    logic [1:0] btnu_s = 2'b00;
    logic [3:0] initcnt = 4'd0;
    logic       idle_c = 1'b0, idle_u = 1'b0;
    wire        initdone = initcnt[3];
    always_ff @(posedge clk) begin
        btnc_s <= {btnc_s[0], btnC};
        btnu_s <= {btnu_s[0], btnU};
        if (!initdone) begin
            initcnt <= initcnt + 1'b1;
            idle_c  <= btnc_s[1];
            idle_u  <= btnu_s[1];
        end
    end
    wire c_pressed = initdone & (btnc_s[1] ^ idle_c);
    wire u_pressed = initdone & (btnu_s[1] ^ idle_u);
    wire rst = ~initdone | u_pressed;

    logic [15:0] sw;
    assign sw = sw_pin ^ {16{SW_INV}};

    logic [$clog2(DEB_CYCLES+1)-1:0] cnt = '0;
    logic btn_stable = 1'b0;
    logic btn_prev   = 1'b0;
    always_ff @(posedge clk) begin
        if (c_pressed == btn_stable)  cnt <= '0;
        else if (cnt == DEB_CYCLES)   begin btn_stable <= c_pressed; cnt <= '0; end
        else                          cnt <= cnt + 1'b1;
        btn_prev <= btn_stable;
    end
    wire start = btn_stable & ~btn_prev;          // one-clock pulse

    // ---------------- operands ----------------
    wire live = sw[13];
    logic [W-1:0] A [0:N-1][0:N-1];
    logic [W-1:0] B [0:N-1][0:N-1];
    always_comb begin
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A[i][j] = W'(WMAT[i][j]);
                if (live) B[i][j] = (j == 0) ? W'({sw[3*i +: 3], 3'b000}) : '0;
                else      B[i][j] = W'(XMAT[i][j]);
            end
        end
    end

    // ---------------- the accelerator ----------------
    logic [CW-1:0] C [0:N-1][0:N-1];
    logic busy, done;
    systolic_matmul #(.N(N), .W(W)) u_mm (
        .clk(clk), .rst(rst), .start(start),
        .A(A), .B(B), .C(C), .busy(busy), .done(done)
    );

    // ---------------- result display ----------------
    logic [1:0] pred;                              // argmax over the classes of sample 0 (live mode)
    always_comb begin
        pred = 2'd0;
        for (int c = 1; c < N; c++)
            if (C[c][0] > C[pred][0]) pred = c[1:0];
    end

    wire [CW-1:0] sel_score = C[sw[1:0]][sw[3:2]];

    logic [15:0] led;
    always_comb begin
        led = '0;
        if (live) led[3:0]  = 4'b0001 << pred;
        else      led[14:0] = sel_score[14:0];
        led[15] = done;
    end
    assign led_pin = led ^ {16{LED_INV}};
endmodule
