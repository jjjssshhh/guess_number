`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/28/2026 02:57:01 PM
// Design Name: 
// Module Name: tb_OV
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


//module tb_OV;

//    logic wclk,rstn;//input
//    logic SIO_C;//input
//    logic MCLK;//input
//    logic PCLK,Hs,Vs;//input
//    logic one_shot_top;//input
//    logic [7:0] image_data;//output
//    logic led_clk1,led_clk2,led_clk3;//output
//    logic [7:0] led_data;//output
//    wire SIO_D;//때로는 입력이면서 때로는 출력이고..때로는 z이다.
//    logic SIO_D_come_out;
//    logic SIO_D_come_in;
//    //assign SIO_D = (SIO_C) ? SIO_D_come_out : 1'bz ;
//    assign SIO_D = 1'bz ;
//    assign SIO_D_come_in = SIO_D;
    
//    OV_VGA dfs
//    (
//         .wclk(wclk),
//         .rstn(rstn),
//        //OV7670
//         .SIO_C(SIO_C),
//         .SIO_D(SIO_D),
//         .MCLK(MCLK),
//         .PCLK(PCLK),
//         .Camera_Hs(Hs),
//         .Camera_Vs(Vs),
//         .image_data(image_data),
        
//        //test_set
//         .one_shot_top(one_shot_top),
//         .led_clk1(led_clk1),
//         .led_clk2(led_clk2),
//         .led_clk3(led_clk3)
//    );
    
//    always #20 wclk = ~wclk;
//    assign MCLK = wclk;
    
    
//    initial begin
//        wclk = 0;
//        rstn = 0;
        
//        #100 rstn = 1;
//        one_shot_top = 1;
        
//        SIO_D_come_in = 1;
//        #4_300_000;
//        $finish;
//    end

//endmodule


`timescale 1ns / 1ps

module tb_OV;

    logic wclk, rstn;
    logic SIO_C;
    logic MCLK;
    logic PCLK, Hs, Vs;
    logic one_shot_top;
    logic [7:0] image_data;
    logic led_clk1, led_clk2, led_clk3,led_clk4;
    logic Hsync,Vsync;
    logic [3:0] vgaRed,vgaGreen,vgaBlue;
    logic [6:0] seg;
    logic an;
    
    wire SIO_D;
    
    assign SIO_D = 1'bz;
    
    OV_VGA dfs (
         .wclk(wclk),
         .rstn(rstn),
         .SIO_C(SIO_C),
         .SIO_D(SIO_D),
         .MCLK(MCLK),
         .PCLK(PCLK),
         .Camera_Hs(Hs),
         .Camera_Vs(Vs),
         .image_data(image_data),
         .led_clk1(led_clk1),
         .led_clk2(led_clk2),
         .led_clk3(led_clk3),
         .led_clk4(led_clk4),
         .Hsync(Hsync),
         .Vsync(Vsync),
         .vgaRed(vgaRed),
         .vgaGreen(vgaGreen),
         .vgaBlue(vgaBlue),
         .seg(seg),
         .an(an)
    );
    
    // System Clock: 25MHz (주기 40ns)
    always #20 wclk = ~wclk;
    assign MCLK = wclk;

    // Camera Pixel Clock (PCLK): 약 24MHz (주기 41.66ns)
    initial begin
        PCLK = 0;
        forever #20.83 PCLK = ~PCLK;
    end
    
    //---------------------------------------------------------
    // Camera Simulation Task (세로 컬러바 패턴 생성)
    // 320x240 해상도, RGB444 포맷 (1픽셀 = 2 Bytes = 2 PCLKs)
    //---------------------------------------------------------
    task send_camera_frame();
        // 1. VSYNC Active (프레임 시작)
        Vs = 1;
        repeat(3 * 784) @(posedge PCLK); // 약 3 라인 길이만큼 유지
        Vs = 0;
        
        // 2. V-Back Porch
        repeat(17 * 784) @(posedge PCLK); 

        // 3. Active Video (240 Lines)
        for (int row = 0; row < 240; row++) begin
            Hs = 1; // HSYNC (HREF) Active
            
            // 320 Pixels (640 Bytes/PCLKs)
            for (int col = 0; col < 320; col++) begin
                logic [3:0] r, g, b;
                
                // 4등분 세로 컬러바: Red -> Green -> Blue -> White
                if      (col < 80)  {r, g, b} = {4'hF, 4'h0, 4'h0};
                else if (col < 160) {r, g, b} = {4'h0, 4'hF, 4'h0};
                else if (col < 240) {r, g, b} = {4'h0, 4'h0, 4'hF};
                else                {r, g, b} = {4'hF, 4'hF, 4'hF};

                // Byte 1 (PCLK 1): {4'b0000, R[3:0]}
                image_data = {4'h0, r};
                @(posedge PCLK);
                
                // Byte 2 (PCLK 2): {G[3:0], B[3:0]}
                image_data = {g, b};
                @(posedge PCLK);
            end
            
            Hs = 0; // HSYNC (HREF) 비활성화
            
            // 4. H-Blanking (H-Front + Sync + H-Back)
            repeat(144) @(posedge PCLK);
        end
        
        // 5. V-Front Porch
        repeat(10 * 784) @(posedge PCLK);
    endtask

initial begin
        // 초기화
        wclk = 0;
        rstn = 0;
        Vs = 0;
        Hs = 0;
        image_data = 8'h00;

        // Reset 해제 (충분한 시간 대기)
        #100 rstn = 1;
        #200;

        // 시나리오 1: 정상적인 프레임 전송
        $display("Scenario 1: Normal Frame Transfer");
        send_camera_frame();
        
        #1000;

        // 시나리오 2: PCLK와 상관없이 Hs(HREF)가 중간에 튀는 경우 (Glitch/밀림 발생)
        $display("Scenario 2: Abnormal Hs Glitch - Data Shifting");
        send_corrupted_frame();

        #5000;
        $finish;
    end

    //---------------------------------------------------------
    // 픽셀 밀림 현상을 재현하기 위한 에러 유발 Task
    //---------------------------------------------------------
    task send_corrupted_frame();
        Vs = 1; repeat(2352) @(posedge PCLK); Vs = 0; // V-Sync
        repeat(13328) @(posedge PCLK); // V-Back Porch

        for (int row = 0; row < 10; row++) begin
            Hs = 1;
            // 수정된 Active Video 구간 (픽셀 번호를 데이터로 전송)
            for (int col = 0; col < 320; col++) begin
                // Byte 1: 상위 4비트는 0, 하위 4비트는 카운트 (식별용)
                image_data = col[7:0]; // 0, 1, 2, 3... 순차적으로 증가
                @(posedge PCLK);
                
                // Byte 2: 행(row) 정보를 섞어서 전송
                image_data = row[7:0]; 
                @(posedge PCLK);
            end
            
            // 중요: Blanking 구간에서는 데이터를 0으로 초기화 (그래야 밀림이 보임)
            Hs = 0;
            image_data = 8'h00; 
            repeat(144) @(posedge PCLK);
        end
    endtask

endmodule
    
