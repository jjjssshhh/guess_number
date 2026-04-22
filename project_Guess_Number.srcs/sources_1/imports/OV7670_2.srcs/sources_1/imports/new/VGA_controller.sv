`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 09:44:43 AM
// Design Name: 
// Module Name: VGA_controller
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


module VGA_controller_b ( my_vga_if.bot mi0 );

    // 304 624,(464) ; 162 386(274) 56*56 으로 1/2샘플링.
    // 테두리를 칠할 것이므로 (58 - 2)*(58 - 2)
    localparam BOX_H_START = 434;//436
    localparam BOX_H_END   = 494;//492
    localparam BOX_V_START = 244; //246
    localparam BOX_V_END   = 304; //302
    
    logic [1:0] finish_sync;
    always@(posedge mi0.clk_vga,negedge mi0.rstn)begin
        if(!mi0.rstn)begin
            finish_sync <= 0;
        end else begin
            finish_sync[0] <= mi0.finish;
            finish_sync[1] <= finish_sync[0];
        end
    end
    
    /*
        Image_conv에서 온 room_ff의 CDC문제를 해결
    */
    logic [1:0] room_ff;
    always@(posedge mi0.clk_vga or negedge mi0.rstn)begin
        if(!mi0.rstn)begin
            room_ff <= 0;
        end
        else begin
            room_ff[0] <= mi0.room_chk;
            room_ff[1] <= room_ff[0];
        end
    end
    
    /*
        Vsync, Hsync
        Vsync는 2클럭동안 0 이며 주기는 clk_vga 800클럭이다.
        Hsync는 Vsync가 0에서 시작하여 96클럭부터 500클럭까지 
    */
    logic [9:0] Vsync_cnt;
    logic [9:0] Hsync_cnt;
    always@(posedge mi0.clk_vga or negedge mi0.rstn)begin
        if(!mi0.rstn)begin
            Vsync_cnt <= 0;
            Hsync_cnt <= 0;
        end
        else begin
            if(Hsync_cnt == 799)begin
                Hsync_cnt <= 0;
                
                if(Vsync_cnt == 524)begin
                    Vsync_cnt <= 0;
                end else Vsync_cnt <= Vsync_cnt + 1;
                
            end else begin
                Hsync_cnt <= Hsync_cnt + 1;
            end
            
        end
    end
    
    /*
        실제 Hsync,Vsync Assignment
        1    2 변할때 데이터 즉시 대입 필요.
        95 96
    */
    always@(posedge mi0.clk_vga or negedge mi0.rstn)begin
        if(!mi0.rstn)begin
            mi0.Hsync <= 1;//default 1
            mi0.Vsync <= 1;
        end
        else begin
            mi0.Vsync <= (Vsync_cnt < 2) ? 0 : 1; //2
            mi0.Hsync <= (Hsync_cnt < 96) ? 0 : 1; //96
        end
    end
    
   /* 1. 사각형 구역이면서  2. 안쪽으로 2만큼만 파고들기 */
    wire is_border = ((Hsync_cnt >= BOX_H_START && Hsync_cnt < BOX_H_END) && 
                  (Vsync_cnt >= BOX_V_START && Vsync_cnt < BOX_V_END)) &&
                 ((Hsync_cnt < BOX_H_START+2 || Hsync_cnt >= BOX_H_END-2) || 
                  (Vsync_cnt < BOX_V_START+2 || Vsync_cnt >= BOX_V_END-2));
                  
    always@(posedge mi0.clk_vga or negedge mi0.rstn)begin
        if(!mi0.rstn)begin
            mi0.addrb <= 0;
        end
        else begin
            /*
                VGA의 프레임을 정하는 순간
                룸이 바뀌었는지 확인 && 
            */
            if(Vsync_cnt == 0)begin  
                mi0.addrb <= (room_ff[1]==0) ? 0 : 72000;
            end else begin
            /*
                640*480
                320*24
            */
            // 162 ~ 386 :: 31 ~ 511 303 623
            if((Vsync_cnt >= 162) && (Vsync_cnt < 386) &&
                    (Hsync_cnt >= 303) && (Hsync_cnt < 623))begin
                    
                    mi0.addrb <= mi0.addrb + 1;
                end
            end
                /*
                수평
                    144 ~ 784 default  
                    304 ~ 624
                    BRAM +1 clock
                    303 ~ 623
                수직
                    31 ~ 511
                    162 ~ 386
                    ver.2
                    31 ~ 271
                    272 ~ 511
                */
                //304 624,(464) 162 386(274) 56*56 으로 1/2샘플링.
                if(is_border)begin
                    mi0.vgaRed     <= 4'hF;
                    mi0.vgaGreen <= 0;
                    mi0.vgaBlue    <=0;  
                end
                else if((Hsync_cnt >= 304 && Hsync_cnt < 624) &&
                    (Vsync_cnt >= 162 && Vsync_cnt < 386) )begin
//                    mi0.vgaRed     <= mi0.doutb[7:4];     //
//                    mi0.vgaGreen <= mi0.doutb[3:0];     // 
//                    mi0.vgaBlue    <=mi0.doutb[11:8];   //
                    mi0.vgaRed     <= mi0.doutb[7:4]; //
                    mi0.vgaGreen <= mi0.doutb[7:4]; // 
                    mi0.vgaBlue    <=mi0.doutb[7:4];  //
                end
                else begin
                    mi0.vgaRed     <= 0;
                    mi0.vgaGreen <= 0;
                    mi0.vgaBlue    <= 0;
                end

        end
    end
    
endmodule

