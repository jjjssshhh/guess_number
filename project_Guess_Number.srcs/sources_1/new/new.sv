`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2026 03:16:52 PM
// Design Name: 
// Module Name: new
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mnist_top (
    input           clk,
    input           rst_n,
    input  [7:0]    pixel_in,      // 0~255 input
    input           pixel_valid,   // New pixel pulse
    output [6:0]    seg_out        // 7-segment output
);

    // 내부 신호 연결
    wire [19:0] conv_out [0:3];    // 4개 채널 출력
    wire        conv_valid;
    
    wire [19:0] pool_out [0:3];
    wire        pool_valid;
    
    wire [3:0]  digit;             // 최종 인식 결과 (0-9)

    // 1. Convolution Layer (No Padding, 3x3)
    conv_layer conv_inst (
        .clk(clk), .rst_n(rst_n),
        .pixel_in(pixel_in), .pixel_valid(pixel_valid),
        .out0(conv_out[0]), .out1(conv_out[1]), 
        .out2(conv_out[2]), .out3(conv_out[3]),
        .valid_out(conv_valid)
    );

    // 2. Max Pooling (2x2)
    maxpool_layer pool_inst (
        .clk(clk), .rst_n(rst_n),
        .in0(conv_out[0]), .in1(conv_out[1]),
        .in2(conv_out[2]), .in3(conv_out[3]),
        .valid_in(conv_valid),
        .out0(pool_out[0]), .out1(pool_out[1]),
        .out2(pool_out[2]), .out3(pool_out[3]),
        .valid_out(pool_valid)
    );

    // 3. Fully Connected Layer & Argmax
    fc_layer fc_inst (
        .clk(clk), .rst_n(rst_n),
        .in0(pool_out[0]), .in1(pool_out[1]),
        .in2(pool_out[2]), .in3(pool_out[3]),
        .valid_in(pool_valid),
        .digit(digit)
    );

    // 4. 7-Segment Decoder
    seg7_decoder seg_inst (
        .digit(digit),
        .seg(seg_out)
    );

endmodule


module conv_layer (
    input clk, rst_n,
    input [7:0] pixel_in,
    input pixel_valid,
    output reg [19:0] out0, out1, out2, out3,
    output reg valid_out
);
    // Line Buffers (28x28 input -> 2 lines needed for 3x3)
    reg [7:0] line_buf1 [0:27];
    reg [7:0] line_buf2 [0:27];
    reg [4:0] col_cnt, row_cnt;
    
    // 3x3 Window
    reg [7:0] win [0:2][0:2];
    
    // 가중치 메모리 (S7.8)
    reg signed [7:0] c_w [0:3][0:8];
    reg signed [7:0] c_b [0:3];
    initial begin
        $readmemh("FINAL_conv1_w.mem", c_w);
        $readmemh("FINAL_conv1_b.mem", c_b);
    end

    // Window Sliding & Line Buffer Logic
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0; row_cnt <= 0;
        end else if (pixel_valid) begin
            // 윈도우 업데이트 및 라인 버퍼 쉬프트 로직 (생략 - 핵심 연산 집중)
            // ... (표준 Line Buffer 구현) ...
            
            // 연산: Out = (Sum(W*X) + Bias*128)
            // Python에서 fake_q는 /128을 하므로, 정수형 연산 시 Bias에 128을 곱해 단위를 맞춤
            if (row_cnt >= 2 && col_cnt >= 2) begin
                out0 <= (win[0][0]*c_w[0][0] + win[0][1]*c_w[0][1] + ...) + (c_b[0] <<< 7);
                // ReLU 적용
                if (out0[19]) out0 <= 0; 
                valid_out <= 1;
            end else begin
                valid_out <= 0;
            end
        end else valid_out <= 0;
    end
endmodule


module fc_layer (
    input clk, rst_n,
    input [19:0] in0, in1, in2, in3,
    input valid_in,
    output reg [3:0] digit
);
    reg signed [31:0] acc [0:9];
    reg [9:0] fc_w_addr;
    
    // 10개 출력에 대한 가중치 (676개씩)
    reg signed [7:0] w0[0:675], w1[0:675], ..., w9[0:675];
    initial begin
        $readmemh("FINAL_fc_w0.mem", w0);
        // ... w1~w9 로드
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for(i=0; i<10; i=i+1) acc[i] <= 0;
            fc_w_addr <= 0;
        end else if (valid_in) begin
            // Interleaving 순서대로 들어오는 4개 채널을 각 가중치와 곱해서 누적
            acc[0] <= acc[0] + (in0 * w0[fc_w_addr]) + (in1 * w0[fc_w_addr+1]) ...;
            fc_w_addr <= fc_w_addr + 4;
            
            if (fc_w_addr >= 672) begin // 모든 676개 픽셀 처리 완료 시
                // Argmax 로직 실행
                // ...
            end
        end
    end
endmodule


module seg7_decoder (
    input      [3:0] digit,
    output reg [6:0] seg
);
    always @(*) begin
        case (digit)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            default: seg = 7'b1111111;
        endcase
    end
endmodule
