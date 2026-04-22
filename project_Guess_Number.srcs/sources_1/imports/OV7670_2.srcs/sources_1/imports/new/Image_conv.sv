`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/29/2026 12:46:07 PM
// Design Name: 
// Module Name: Image_conv
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
    GrayScale = 0.3 Red + 0.6 Green + 0.1 Blue
    GrayScale = 0.25 Red + 0.5 Green + 0.125Blue
    GrayScale = 0.25 Red + 0.625 Green + 0.125Blue how?
    GrayScale = (2*Red + 5*Green + Blue) >> 3;
*/
module Image_conv(my_vga_if.image_cov m);

    logic rgb;
    logic [15:0] red;
    logic [15:0] green; // 
    logic edge_reg;
    logic p_edge;
    logic [1:0] sync_pclk;
    // 2단 싱크로
    always@(posedge m.pclk , negedge m.rstn)begin
        if(!m.rstn)begin
            sync_pclk <= 0;
        end else begin
            sync_pclk[0] <= m.sccb_master_done;
            sync_pclk[1] <= sync_pclk[0];
        end
    end
    
    logic first;
    logic [8:0] x,y;
    
    /* 네모 구역 미리 라인버퍼에 넣기 */
    /* 몇번째 데이터? 320*225의 160,112 ; 132 - 188, 84 - 140 구역만 가져가기..*/
    /* 한줄에 320이므로 x,y */
    logic into_cnn;
    /*  %, /를 사용하지 않기 위한 카운팅 로직 */
    always@(posedge m.pclk , negedge m.rstn)begin
        if(!m.rstn)begin
            x <= 0; y <= 0; 
            into_cnn <= 0;
        end
        else begin
            if(m.wt_valid)begin//1클럭 느리게 증가.
                x <= (x >= 319) ? 0 : x + 1;
                y <= (x == 319) ? y + 1 : y; //한순간만 증가.
                //1클럭 당기기. + 56 x 56 -> 28 x 28 샘플링해야 함. - 131~186, 84 ~ 139
                // 10 10 00 00 -> y[홀수] = 0, x[홀수] = 0
                if( (x >= 132&& x <= 186) && (y >= 84 && y <= 138) &&
                    ( (x[0] == 0) && (y[0] == 0))  )begin
                    into_cnn <= 1;
                end else into_cnn <= 0;
            end
            else if(m.Camera_Vs)begin
                x <= 0; y <= 0;
            end
        end 
   end
    logic [7:0] gray_val;
    assign gray_val = ((red << 1) + ({green,m.image_data[7:5] } <<2)+ {green,m.image_data[7:5]} + m.image_data[4:0])>>3;
    always@(posedge m.pclk , negedge m.rstn)begin
        if(!m.rstn)begin
            rgb <= 0;
            m.in_dt <= 0;
            m.wt_valid <= 0;
            m.addra <= 0;
            m.finish <= 0;
            m.led_clk2 <= 0;
            edge_reg <= 0;
            p_edge <= 0;
            m.room_chk <= 0;
            first <= 0;
            red <= 0;
            green <= 0;
            
            m.cnn_valid <= 0;
            m.cnn_dt <= 0;
            m.cnn_done <= 0;
        end else begin
            
            edge_reg <= m.Camera_Vs; // 카메라의 Vs는 Active High 평소에 0
            p_edge <= ({edge_reg, m.Camera_Vs} == 2'b01); //rising edge찾기
            
            //case(m.sccb_master_done)
            case(sync_pclk[1])
                0:begin
                    //waiting master_done
                end
                1:begin
                    //다음 줄 시작전 초기화
                    if(p_edge)begin           
                        //rgb <= 0;
                        m.room_chk <= ~m.room_chk;
                        m.addra <= (m.room_chk == 0) ? 72000 : 0;
                        
                        //m.finish <= 1;      // 이미지 한장 완료
                        if(!first)begin
                            first <= 1;
                            m.finish <= 0;
                        end else m.finish <= 1;
                        
                        m.wt_valid <= 0;
                        m.led_clk2 <= 1;
                    end 
                    else begin
                        if(!m.Camera_Vs && m.Camera_Hs)begin//!m.Camera_Vs
                        
                             if(!rgb)begin
                                rgb <= 1;
                                m.wt_valid <= 0;
                                {red,green} <= {m.image_data[7:3],m.image_data[2:0]};
                            end else begin
                                rgb <= 0;
                                /****  bram에 데이터 던지기  ****/
                                m.in_dt <= {green,m.image_data[7],m.image_data[4:1]};//green
                                //m.in_dt <= (((red << 1) + ({green,m.image_data[7:5] } <<2)+ {green,m.image_data[7:5]} + m.image_data[4:0])>>3);
                                m.wt_valid <= 1;
                                /****  cnn에 데이터 던지기  ****/
                                if(into_cnn) begin
                                    m.cnn_valid <= 1;
                                    /* Camera는 밝으면 FF 어두우면 0 ; MNIST는 밝으면 0 어두우면 FF임*/
                                    //m.cnn_dt <=~{red,green,m.image_data[7],m.image_data[4:1]};//일단은 이렇게 
                                    m.cnn_dt <= (gray_val >= 8'h80) ? 8'h00 : 8'hFF;
                                     
                                end else m.cnn_valid <= 0;
                                if( x == 187 && y == 138 ) m.cnn_done <= 1;//한클럭 더 늦게 
                                else m.cnn_done <= 0;
                                
                                // 잔상제거 필수
                                if(m.room_chk== 0 && m.addra >= 71999) begin
                                    m.addra <= 71999;//포인터 상한두기
                                end else begin
                                    m.addra <= m.addra + 1;
                                end
                                
                            end
                        end else begin  // Camera_Hs = 0
                            rgb <= 1; //
                            red <= 0;
                            green <= 0;
                            m.wt_valid <= 0;
                        end
                    end 
                end//1
            endcase
        end
    end
    
    
endmodule
/* 2*red + 5*green + blue */
//m.in_dt <= ( (red << 1) +({green,m.image_data[7:5]} << 2)+ {green,m.image_data[7:5]} + m.image_data[4:0]) >> 3; //try 1


