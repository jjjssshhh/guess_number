`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 01:58:58 PM
// Design Name: 
// Module Name: cnn_tb
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

module cnn_tb();

    localparam TROOM = 784;//784
    //새로운 인터페이스 선언
    logic snn_clk;
    my_vga_if test_if(.clk(snn_clk)); 

    cnn_top ctop (
        .m(test_if.cnn_top) 
    );

    always #10 test_if.wclk =  ~test_if.wclk;

    //integer target_digit = 8; // 0~9 중 테스트하고 싶은 숫자 설정
    integer target_digit;
    string file_name;
    logic [7:0] test_digit_mem [0:TROOM];
    
    
    initial begin
        snn_clk = 0;
        test_if.wclk = 0;
        test_if.rstn = 0;
        test_if.cnn_dt = 0;
        test_if.cnn_valid = 0;
        test_if.cnn_done = 0;

        #100 test_if.rstn = 1;
        test_task();
//        total_test();
        //double_chk();
        //fake_num();
        #10000;
        $finish;
    end
    
    task double_chk();
        integer i;
        repeat(2)begin
            $sformat(file_name, "/home/jsh-laptop/Downloads/N/mnist_%0d.mem", 1);
            $readmemh(file_name, test_digit_mem);
            for(i=0; i<TROOM; i=i+1) begin    
                    @(posedge test_if.wclk); // 매 데이터마다 클럭 동기화
                    test_if.cnn_valid = 1;
                    test_if.cnn_dt = test_digit_mem[i];
            end
            test_if.cnn_valid = 0;
             test_if.cnn_done = 1;
            @(posedge test_if.wclk);
            test_if.cnn_done = 0;
            repeat(300)@(posedge test_if.wclk);
        end

    endtask
    
    task fake_num();
        integer i,k;
        for(k=0;k<10;k=k+1)begin
            $sformat(file_name, "/home/jsh-laptop/Downloads/N/mnist_%0d.mem", k);
            $readmemh(file_name, test_digit_mem);
            for(i=0; i<TROOM; i=i+1) begin    
                    @(posedge test_if.wclk); // 매 데이터마다 클럭 동기화
                    test_if.cnn_valid = 1;
                    test_if.cnn_dt = test_digit_mem[i];
            end
            test_if.cnn_valid = 0;
             test_if.cnn_done = 1;
            @(posedge test_if.wclk);
            test_if.cnn_done = 0;
            repeat(300)@(posedge test_if.wclk);
        end

    endtask
    /* 실제 카메라 환경 대입 */
    task test_task();
    
        integer idx; 
        $sformat(file_name,"/home/jsh-laptop/Downloads/N/mnist_%0d.mem", 4);
        $readmemh(file_name,test_digit_mem);

        idx = 0;
        repeat(28)begin
            repeat(28)@(posedge test_if.wclk)begin
                    test_if.cnn_dt = test_digit_mem[idx];
                    test_if.cnn_valid = 1;
                    idx = idx + 1;
            end
            @(posedge test_if.wclk);
            test_if.cnn_valid = 0;
            repeat(200)@(posedge test_if.wclk);
        end
        test_if.cnn_done = 1;
        @(posedge test_if.wclk);
        test_if.cnn_done = 0;
    endtask

    task total_test();
        integer i;  
        logic [11:0] idx;
        for(i=0;i<10;i=i+1)begin
            $sformat(file_name,"/home/jsh-laptop/Downloads/N/mnist_%0d.mem", i);
            $readmemh(file_name,test_digit_mem);
            idx = 0;
            repeat(28)begin
                repeat(28)@(posedge test_if.wclk)begin
                        test_if.cnn_dt = test_digit_mem[idx];
                        test_if.cnn_valid = 1;
                        idx = idx + 1;
                end
                @(posedge test_if.wclk);
                test_if.cnn_valid = 0;
                repeat(200)@(posedge test_if.wclk);
            end
            @(posedge test_if.wclk);
            test_if.cnn_done = 1;
            @(posedge test_if.wclk);
            test_if.cnn_done = 0;
            repeat(200)@(posedge test_if.wclk);
        end
    endtask
        
endmodule



//    // 1. 레퍼런스 데이터를 저장할 메모리 선언
//    logic signed [31:0] ref_relu_data [0:2703]; // 26*26*4 = 2704개
//    logic signed [31:0] ref_final_data [0:9];
    
//    initial begin
//        // 2. 파이썬에서 만든 정답지 로드
//        $readmemh("/home/jsh-laptop/Downloads/debug_relu_out.hex", ref_relu_data);
//        $readmemh("/home/jsh-laptop/Downloads/debug_final_score.hex", ref_final_data);
//    end
//// 3. ReLU 결과 자동 비교 (TB 수정본)
//    integer relu_cnt; // 선언만

//    initial begin
//        relu_cnt = 0; // 명시적 초기화
//        // 파일 로드 확인용 디스플레이
//        #1; 
//        $display("CHECK: ref_relu_data[0] = %h", ref_relu_data[0]); 
//        if (ref_relu_data[0] === 32'hX) begin
//            $display("!!! [FATAL ERROR] HEX 파일을 못 읽었습니다. 경로 확인하세요 !!!");
//        end
//    end
//    /* 한번에 4개가 나온다. */
//    always @(negedge ctop.m.wclk) begin
//        if (ctop.conv_d5) begin 
////        if (ctop.relu_chk) begin 
//            for (int i=0; i<4; i++) begin
//                // FPGA 값과 Ref 값을 변수에 담아서 출력해봅시다.
//                $display("[DEBUG] Cnt:%0d | FPGA:%d | Ref:%d", 
//                          relu_cnt, ctop.relu_result[i], ref_relu_data[relu_cnt+i]);
                
//                if (ctop.relu_result[i] !== ref_relu_data[relu_cnt+i]) begin
//                    $display("[ERROR] Mismatch!");
//                end
//                relu_cnt = relu_cnt + 1;
//            end//for
//        end
//    end
    
//    // 4. 최종 FC 결과 자동 비교
//    always @(posedge ctop.m.wclk) begin
//        if (ctop.final_chk) begin
//            for (int i=0; i<10; i++) begin
//                if (ctop.final_reg[i] !== ref_final_data[i]) begin
//                    $display("[ERROR] Final Score Mismatch! Class:%d, FPGA:%d, Ref:%d", 
//                              i, ctop.final_reg[i], ref_final_data[i]);
//                end else begin
//                    $display("[SUCCESS] Class:%d matched!", i);
//                end
//            end
//        end
//    end
















