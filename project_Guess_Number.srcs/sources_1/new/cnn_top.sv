`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/13/2026 11:48:11 AM
// Design Name: 
// Module Name: cnn_top
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

/*
    이번 프로젝트의 핵심 CNN
    8bit 데이터를 받고. 가중치 셋을 받고 
    Conbolution -> ReUL -> Polling -> FC
    
*/
module cnn_top(my_vga_if.cnn_top m);

    localparam ROOM = 675;//783, 675
    localparam OFFSET = 169;//169
    localparam LINE = 27;//27
    localparam LINE2 = 25;//polling 25
    localparam LINE3 = 27;//line
    localparam PLINE = 14;//13
    //3줄의 라인버퍼.
    logic signed[8:0] line_buffer0 [0:LINE];
    logic signed[8:0] line_buffer1 [0:LINE];
    logic signed[8:0] line_buffer2 [0:LINE];
    
    logic [5:0] cnt;
    logic [2:0] ccnt;
    
    logic [7:0] in_buffer[0:1];
    logic scnn_valid[0:1];
    logic scnn_done[0:1];
    
    /* signed 선언필요 */
    logic signed [7:0] conv1_b [0:3];
    logic signed [7:0] conv1_w [0:35];
    logic signed [7:0] fc_b[0:9];
    // 10행의 784*10으로 쪼개기?
    //(* ram_style = "block" *) logic signed [7:0] fc_w[0:7839];
    //logic signed [7:0] fc_w[0:9][0:ROOM];
    
   //(* ram_style = "block" *) logic signed [7:0] fc_w[0:7839];
   (* ram_style = "block" *) logic signed [7:0] fc_w0[0:ROOM]; (* ram_style = "block" *) logic signed [7:0] fc_w5[0:ROOM];
   (* ram_style = "block" *) logic signed [7:0] fc_w1[0:ROOM]; (* ram_style = "block" *) logic signed [7:0] fc_w6[0:ROOM];
   (* ram_style = "block" *) logic signed [7:0] fc_w2[0:ROOM]; (* ram_style = "block" *) logic signed [7:0] fc_w7[0:ROOM];
   (* ram_style = "block" *) logic signed [7:0] fc_w3[0:ROOM]; (* ram_style = "block" *) logic signed [7:0] fc_w8[0:ROOM];
   (* ram_style = "block" *) logic signed [7:0] fc_w4[0:ROOM]; (* ram_style = "block" *) logic signed [7:0] fc_w9[0:ROOM];
   
    string path = "/home/jsh-laptop/workspace_ondevice_2/fpga/self_study/project_Guess_Number";

    initial begin
        // 기본 레이어 가중치
        $readmemh($sformatf("%s/FINAL_conv1_b.mem", path), conv1_b);
        $readmemh($sformatf("%s/FINAL_conv1_w.mem", path), conv1_w);
        $readmemh($sformatf("%s/FINAL_fc_b.mem",    path), fc_b);
    
        // FC 레이어 가중치 (한 줄에 가독성 있게 배치)
        $readmemh($sformatf("%s/FINAL_fc_w0.mem", path), fc_w0); $readmemh($sformatf("%s/FINAL_fc_w5.mem", path), fc_w5);
        $readmemh($sformatf("%s/FINAL_fc_w1.mem", path), fc_w1); $readmemh($sformatf("%s/FINAL_fc_w6.mem", path), fc_w6);
        $readmemh($sformatf("%s/FINAL_fc_w2.mem", path), fc_w2); $readmemh($sformatf("%s/FINAL_fc_w7.mem", path), fc_w7);
        $readmemh($sformatf("%s/FINAL_fc_w3.mem", path), fc_w3); $readmemh($sformatf("%s/FINAL_fc_w8.mem", path), fc_w8);
        $readmemh($sformatf("%s/FINAL_fc_w4.mem", path), fc_w4); $readmemh($sformatf("%s/FINAL_fc_w9.mem", path), fc_w9);
    end
    
    // CDC
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            in_buffer[0] <= 0; in_buffer[1] <= 0;
            scnn_valid[0] <= 0; scnn_valid[1] <= 0;
            scnn_done[0] <= 0; scnn_done[1] <= 0;
        end
        else begin
             in_buffer[0] <= m.cnn_dt;
             in_buffer[1] <= in_buffer[0];
             
             scnn_valid[0] <= m.cnn_valid;
             scnn_valid[1] <= scnn_valid[0];
             
             scnn_done[0] <= m.cnn_done;
             scnn_done[1] <= scnn_done[0];
        end 
   end
   
    logic [1:0] select;
    logic line_valid;
    always@(posedge m.wclk, negedge m.rstn) begin
        if(!m.rstn) begin
            cnt <= 0; ccnt <= 0;
            select <= 0; line_valid <= 0;
            for(int i=0; i<28;i=i+1)begin
                line_buffer0[i] <= 0; line_buffer1[i] <= 0; line_buffer2[i] <= 0;
            end
        end else begin
            // done이 들어오면 프레임 전체 초기화
            if(scnn_done[1]) begin
                cnt <= 0;
                ccnt <= 0;
                select <= 0;
                line_valid <= 0;
            end 
            // 데이터가 들어올 때만 카운트 진행
            else if(scnn_valid[1]) begin
                if(cnt == LINE3) begin
                    cnt <= 0;
                    // 라인 버퍼 순환 (0->1->2->0...)
                    select <= (select == 2) ? 0 : select + 1;
                    // 최소 3줄(0,1,2)이 찼을 때부터 valid 시작
                    ccnt <= (ccnt >= 2) ? 2 : ccnt + 1;
                end else begin
                    cnt <= cnt + 1;
                end
                
                // ccnt가 2라는 건 버퍼 0, 1, 2가 한 번씩 다 돌았다는 뜻
                if(ccnt == 2) line_valid <= 1;
                else          line_valid <= 0;
                
                // 데이터 쓰기
                case(select)
                    0 : line_buffer0[cnt] <= {1'b0,in_buffer[1]};
                    1 : line_buffer1[cnt] <= {1'b0,in_buffer[1]};
                    2 : line_buffer2[cnt] <= {1'b0,in_buffer[1]};
                endcase
            end
            // valid가 0일 때는 아무것도 하지 않고 값 유지 (cnt <= 0; 지우기)
            else begin
                line_valid <= 0;
            end
        end
    end


    /* 컨볼루션 : 시스템은 가만히 있고 입력이 관통하면서 지나가기.*/
    /* 시스템이나 신호가 한칸씩 이동해야 한다.*/
    logic signed [8:0] sys[0:2][0:2];
    logic [5:0] idx;
    logic start_conv;
    logic [1:0] delay_conv;
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            idx <= 0; start_conv <= 0; delay_conv <= 0;
            for(int i=0; i<3;i=i+1)begin
                for(int j=0; j<3;j=j+1)begin
                    sys[i][j] <= 0;
                end
            end
        end else begin
            if(line_valid)begin
                // 0 -> 1 -> 2 -> 0 -> 1 -> 2...
                case(select)
                    0: begin // 방금 0번에 썼음
                        sys[0][2] <= line_buffer0[idx]; // 최신 (L0)
                        sys[1][2] <= line_buffer2[idx]; // 직전 (L1)
                        sys[2][2] <= line_buffer1[idx]; // 과거 (L2)
                    end
                    1: begin // 방금 1번에 썼음
                        sys[0][2] <= line_buffer1[idx]; // 최신 (L0)
                        sys[1][2] <= line_buffer0[idx]; // 직전 (L1)
                        sys[2][2] <= line_buffer2[idx]; // 과거 (L2)
                    end
                    2: begin // 방금 2번에 썼음
                        sys[0][2] <= line_buffer2[idx]; // 최신 (L0)
                        sys[1][2] <= line_buffer1[idx]; // 직전 (L1)
                        sys[2][2] <= line_buffer0[idx]; // 과거 (L2)
                    end
                endcase
                           
                sys[0][1] <= sys[0][2]; sys[0][0] <= sys[0][1];
                sys[1][1] <= sys[1][2]; sys[1][0] <= sys[1][1];
                sys[2][1] <= sys[2][2]; sys[2][0] <= sys[2][1];
                
                idx <= idx + 1;
                if(idx >= 2) start_conv <= 1;   // 2 ==========================26*26의 범위를 조정
                //start_conv <= 1;
            end else begin
                idx <= 0;
                start_conv <= 0;
//                if(delay_conv >= 2)begin//2
//                    delay_conv <= 0;
//                    start_conv <= 0; //new
//                end else delay_conv <= delay_conv + 1;
            end
        end
    end
    
    logic conv_d1,conv_d2,conv_d3,conv_d4, conv_d5, conv_d6;
    /* 28 * 28 -> 012 부터 시작 26 27 28 종료 26개  26*26 non padding */
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            conv_d1 <= 0; conv_d2 <= 0; conv_d3 <= 0; conv_d4 <= 0; conv_d5 <= 0; conv_d6 <= 0;
        end
        else begin
            conv_d1 <= start_conv;
            conv_d2 <= conv_d1; conv_d3 <= conv_d2; conv_d4 <= conv_d3; conv_d5 <=conv_d4; conv_d6 <= conv_d5;
        end
     end
     
    logic signed[15:0] process[0:11];
    logic signed[19:0] result[0:3];
    logic relu_chk;
    logic flag;
    /* y = conv1_w * image + conv1_b ; y = wx+b */
    /* 여기가 문제??? */
    
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            relu_chk <= 0;
        end else begin
            if(start_conv)begin//conv_d3
                /* 4개의 필터 */
                for(integer n=0; n < 4; n=n+1)begin
                    for(integer k=0; k < 3; k=k+1)begin
                        process[3*n + k] <= 
                            conv1_w[9*n + 3*k + 0] * sys[k][0]
                            + conv1_w[9*n+ 3*k + 1] * sys[k][1]
                            + conv1_w[9*n+3*k + 2] * sys[k][2];
                    end
                end
            end
        end
    end
        always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            //flag <= 0;
            relu_chk <= 0;
        end else begin
            if(conv_d1)begin//conv_d4
                relu_chk <= 1;
                for(integer n=0; n<4;n=n+1)begin
                        result[n] <= $signed(process[3*n]) + $signed(process[3*n+1]) + $signed(process[3*n+2]) + (conv1_b[n]<< 7 ); 
                end
            end//start_conv && ccn_valid[1]
            else begin
                relu_chk <= 0;//new
                result[0] <= 0; result[1] <= 0; result[2] <= 0; result[3] <= 0;//new
            end
        end
    end
    logic signed[19:0] raw_result[0:3];
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
        end else begin
            if(conv_d2)begin
                for(integer n=0; n<4;n=n+1)begin
                        raw_result[n] <= (result[n]) >>>7 ;
                end
            end
            else begin
                raw_result[0] <= 0; raw_result[1] <= 0; raw_result[2] <= 0; raw_result[3] <= 0;//new
            end
        end
    end
    
    
    /* ReLU : 음수를 0으로 깍기 - 비선형성 항 ; 연산량 줄이기 */
    /* 127넘으면 다 자른다? */
    logic signed[19:0] relu_result[0:3];
    logic polling_chk;
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            polling_chk <= 0; 
            for(integer i=0;i<4;i=i+1)begin
                relu_result[i] <= 0;
            end
        end else if(conv_d3)begin//relu_chk
            polling_chk <= 1;
            //relu_cnt <= 0;
            for(integer i=0;i<4;i=i+1)begin
                if(raw_result[i] > 127)begin
                    relu_result[i] <= 127;
                end
                else  if(raw_result[i] < 0)begin
                    relu_result[i] <= 0;
                end else relu_result[i] <= raw_result[i];
            end
        end
        else begin
            polling_chk <= 0;
        end
    end

    logic [5:0] idx_d1,idx_d2,idx_d3,idx_d4,idx_d5,idx_d6,idx_d7,idx_d8;
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            idx_d1 <= 0; idx_d2 <= 0; idx_d3 <= 0;
        end else begin
            idx_d1 <= idx; idx_d2 <= idx_d1; idx_d3 <= idx_d2; idx_d4 <= idx_d3; idx_d5 <= idx_d4; idx_d6 <= idx_d5; idx_d7 <= idx_d6; idx_d8 <= idx_d7;
        end
    end
    /* Max Polling  2 x 2 -> 1개로 압축  */
    /*  28*28*4 inputs to 14*14*4 outputs */
    /* 한줄 저장 전 2개 단위로 미리 대소 비교.*/
    /* 실제로는 2줄이 1줄로 줄면서 14*4 개가 폴링 됨 */
    logic  [19:0] polling_buffer [0:3][0:(PLINE-1)];//속도차이로 전체크기버퍼로 선언되어 있어야 한다.
    logic  [19:0] polling_output [0:3];
    logic [4:0] poll_idx;
    logic [4:0] poll_cnt;
    //logic [1:0] poll_st;
    logic [4:0] poll_st_cnt;
    logic fc_valid;
    logic [2:0] poll_wait;
    logic poll_st;
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            poll_st <= 1;
        end else begin
            if({conv_d4,conv_d3} == 2'b01)begin
                poll_st <= ~poll_st;
            end
        end
    end
    
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            poll_idx <= 0;
            poll_cnt <= 0;
            fc_valid <= 0;
            poll_st_cnt <= 0;
            poll_wait <= 0;
            for(integer i=0; i<4;i=i+1)begin
                polling_output[i] <= 0;//new 
                for(int j=0; j<PLINE;j=j+1)
                    polling_buffer[i][j] <= 0;
            end
        end
        else if(conv_d4)begin
            case(poll_st)
                /* 1행 */
                0:begin 
                    fc_valid <= 0; 
                    //poll_idx <= poll_idx + 1;
                    /* 저장 */
                    /* 28 => 14개 */
                    if(idx_d5[0] == 0)begin//idx_d5
                        polling_buffer[0][idx_d5[4:1]] <= relu_result[0]; polling_buffer[1][idx_d5[4:1]] <= relu_result[1];
                        polling_buffer[2][idx_d5[4:1]] <= relu_result[2]; polling_buffer[3][idx_d5[4:1]] <= relu_result[3];
                    end
                    /* 비교 후 저장 */
                    else begin
                        for(integer i=0;i<4;i=i+1)begin//14*2
                            if(polling_buffer[i][idx_d5[4:1]] < relu_result[i] )begin
                                polling_buffer[i][idx_d5[4:1]] <=  relu_result[i];
                            end
                        end
                    end//else
                    
                end
                /* 2행 */
                1:begin
                    if(poll_cnt >= LINE2)begin//25
                        poll_cnt <= 0;
                        if(poll_st_cnt == PLINE)begin//new
                            poll_st_cnt <= 0;
                            //poll_st <= 0;//2 new----------------
                        end
                        else begin
                            poll_st_cnt <= poll_st_cnt + 1;
                            //poll_st <= 0;
                        end
                    end else poll_cnt <= poll_cnt + 1;
                    //비교
                    if(poll_cnt[0] == 1)begin//1
                        fc_valid <= 1;
                        for(integer i=0; i<4;i=i+1)begin
                            if(polling_buffer[i][poll_cnt[4:1]] < relu_result[i] )begin
                                polling_output[i] <= relu_result[i];
                            end else begin
                                polling_output[i] <= polling_buffer[i][poll_cnt[4:1]];
                            end
                            polling_buffer[i][poll_cnt[4:1]] <= 0;//new
                        end
                    end else begin
                        fc_valid <= 0;
                        //비교
                        for(integer i=0;i<4;i=i+1)begin
                            if(polling_buffer[i][poll_cnt[4:1]] < relu_result[i] )begin
                                polling_buffer[i][poll_cnt[4:1]] <=  relu_result[i];
                            end
                        end
                    end
                end
            endcase
        end
        else begin
            fc_valid <= 0;
        end
    end
//    logic  [19:0] polling_output_d [0:3];
//    always@(posedge m.wclk, negedge m.rstn)begin
//            if(!m.rstn)begin
//                for(int i=0; i<4;i=i+1) polling_output_d[i] <= 0;
//            end else if(fc_valid)begin
//                polling_output_d <= polling_output;
//            end
//    end
    /* FC : Fully Connected Layer */
    /*  784 inputs to  10 output*/
    /* Polling 속도가 느림!! */
    /* 누산해야 한다. 
        그러면 fc_result 비트는
        20bit * 8bit  = 28bit. 4개 더하기 +2bit 누산 각 196번 2^8(256)이므로 
        최소 38bit, 40bit선정.
    */
    /* FC부터는 폴링이 완료되면 이미지가 들어오지 않고 있어도 작동되고 있어야 한다. */
    logic signed [39:0] fc_result [0:9];
    logic signed [39:0] temp_result [0:9];
    logic [11:0] fc_idx;
    logic [6:0] fc_cnt;
    logic [2:0] fc_st;
    logic final_chk;
    logic mm_chk;
    logic fc_nine_cnt;
    logic signed [39:0] final_reg[0:9];

    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            fc_idx <= 0;
            fc_cnt <= 0;
            final_chk <= 0;
            fc_st <= 0;
            mm_chk <=0;
            fc_nine_cnt <= 0;
            for(integer i=0; i< 10; i=i+1)begin
                fc_result[i] <= 0; temp_result[i] <= 0;
            end
        end else begin
            if(fc_idx >= OFFSET) begin//197번째에서 최종 출력 완료.
                fc_idx <= 0;
                final_chk <= 1;
                mm_chk <= 0;//new
                for(integer i=0; i<10;i=i+1)begin
                    final_reg[i] <= (fc_result[i] + (fc_b[i])) ;//new
                    fc_result[i] <= 0;//초기화
                    temp_result[i] <= 0;
                end
            end
             else if(fc_valid)begin
                //이미지 하나에 14*14 = 196개의 폴링 데이터
                
                    fc_idx <= fc_idx + 1; 
                    final_chk <= 0;
                    mm_chk <= 1;
                     
                    temp_result[0] <= ($signed(fc_w0[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w0[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w0[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w0[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[1] <= ($signed(fc_w1[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w1[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w1[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w1[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[2] <= ($signed(fc_w2[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w2[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w2[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w2[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[3] <= ($signed(fc_w3[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w3[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w3[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w3[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[4] <= ($signed(fc_w4[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w4[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w4[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w4[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[5] <= ($signed(fc_w5[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w5[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w5[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w5[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));//>>>5
                    temp_result[6] <= ($signed(fc_w6[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w6[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w6[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w6[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[7] <= ($signed(fc_w7[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w7[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w7[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w7[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));
                    temp_result[8] <= ($signed(fc_w8[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w8[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w8[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w8[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));//>>>2
                    temp_result[9] <= ($signed(fc_w9[fc_idx*4 + 0])) * ($signed({1'b0,polling_output[0]}))
                                                    + ($signed(fc_w9[fc_idx*4 + 1])) * ($signed({1'b0,polling_output[1]}))
                                                    + ($signed(fc_w9[fc_idx*4 + 2])) * ($signed({1'b0,polling_output[2]}))
                                                    + ($signed(fc_w9[fc_idx*4 + 3])) * ($signed({1'b0,polling_output[3]}));     
                                                                        
             end//fc_valid
             else begin
                //빈구간이 많으므로 계속 누산하면 안된다.
                final_chk <= 0;//new
                if(mm_chk)begin
                    mm_chk <= 0;
                    for(integer i=0; i<10;i=i+1)begin
                        fc_result[i] <= $signed(fc_result[i]) + ($signed(temp_result[i]));//14 ~ 38
                        //fc_result[i] <= $signed(fc_result[i]) + ($signed(temp_result[i]));
                    end//for 
                end//mm_chk
             end//else
             
        end
    end

 
        
    logic signed [39:0] final_seg;
    logic [3:0] final_num;
    logic [3:0] temp_num;
    logic com_chk;
    logic seg_chk;
    logic sum;
    /* Argument; */
    /* 10개 중 가장 큰 값 찾기 */
    /* Blocking */
    always_comb begin
        if(final_chk)begin//1클럭만에 해야 함.
        
            final_seg = final_reg[0];//비교값 초기셋팅.
            temp_num = 0;
            
            for(integer i=1; i<10; i=i+1)begin
                if(final_reg[i] > final_seg)begin // > new-----------------------------
                    final_seg = final_reg[i];
                    temp_num = i;
                end
            end//for
            
            com_chk = 1'b1;
        end else com_chk = 1'b0;
   end 

   /* Non-blocking */
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            seg_chk <= 0;
            final_num <= 0;
        end
        else begin
            if(com_chk)begin
                seg_chk <= 1'b1;
                final_num <= temp_num;
            end
        end
   end 
    
    /* segment 출력 */
    always@(posedge m.wclk, negedge m.rstn)begin
        if(!m.rstn)begin
            m.seg <= 8'hFF;
            m.an <= 4'b1111;
        end else begin
            if(seg_chk)begin
                m.an <= 4'b1110;
                case(final_num) //signed usigned무시하기 위해 0~9말고 비트로 넣음
                    4'b0000: m.seg <= 8'h40;
                    4'b0001: m.seg <= 8'h79;
                    4'b0010: m.seg <= 8'h24;
                    4'b0011: m.seg <= 8'h30;
                    4'b0100: m.seg <= 8'h19;
                    4'b0101: m.seg <= 8'h12;
                    4'b0110: m.seg <= 8'h02;
                    4'b0111: m.seg <= 8'h78;
                    4'b1000: m.seg <= 8'h00;
                    4'b1001: m.seg <= 8'h10;
                    default : m.seg <= 8'hFF;
                endcase
            end//seg_chk
        end
   end 
   
endmodule


