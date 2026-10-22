// pine_test.sv -- 1-minute board check. Tells you the polarity of the switches, LEDs and buttons.
//   LED1 = constant logic 1   (ON  -> LEDs are active-high)
//   LED2 = constant logic 0   (OFF -> LEDs are active-high)
//   LED3 = raw level of button KEY_0,   LED4 = raw level of button KEY_1
//   LED5..LED16 = slide switches SW5..SW16
module pine_test (
    input  logic        clk,
    input  logic        btnC,
    input  logic        btnU,
    input  logic [15:0] sw_pin,
    output logic [15:0] led_pin
);
    always_comb begin
        led_pin[0]    = 1'b1;
        led_pin[1]    = 1'b0;
        led_pin[2]    = btnC;
        led_pin[3]    = btnU;
        led_pin[15:4] = sw_pin[15:4];
    end
endmodule
