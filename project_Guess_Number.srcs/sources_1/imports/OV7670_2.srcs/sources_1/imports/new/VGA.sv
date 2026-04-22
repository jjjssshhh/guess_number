`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 06:54:25 PM
// Design Name: 
// Module Name: VGA
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


interface my_vga_if(input logic clk);
    //VGA
    localparam [6:0] Tpw = 96;
    localparam [7:0] Tbp = 144;
    localparam [9:0] Tdisp = 784;
    localparam [9:0] Ts = 800; //가로 640포함 총
    localparam [9:0] ROW = 525; // 525
    localparam [16:0] ROWCOL = 17'd76799;
    
    logic rstn;
    logic [11:0] data;
    //vga 필요 신호
    logic Hsync,Vsync;
    logic [3:0] vgaRed,vgaBlue,vgaGreen;
    logic line_done;
    logic one_done;
    logic [9:0] row_cnt;//640
    //logic [9:0] col_cnt;//480
    //uart
    logic RsRx;//RsTx불필요
    logic div_8,div_96;//115200,9600
    logic finish;//이미지 한장 완료
    logic en_div;
    //
    //fifo
    logic [7:0]in_dt;
    logic wt_valid,rd_ready;
    logic rd_valid,wt_ready;
    //assign rd_valid = 1'b1;//계속 준비됨.
    assign wt_valid = 1'b1;
    assign rd_ready = 1'b1;
    assign wt_ready = 1'b1;//fifo제거로 사용 필요.
    //
    logic c_wt_en,c_rd_en;
    logic c_en;
    assign c_en = c_wt_en | c_rd_en;
    //
    logic [17:0] addra,addrb;// addra[17], addrb[17]은 의도적으로 오버플로를 내는것임.
    logic room_chk;
    
    logic wea;
    logic [7:0] doutb;
    //sccb_write
    //logic SIO_D;//three-state 0,1,z
    logic SIO_C;
    logic SIO_D_in;
    logic sio_c_n_edge,sio_c_p_edge;
    logic sccb_write_en,sccb_read_en;
    logic sccb_write_rstn, sccb_read_rstn;
    logic [7:0] ID_address,Sub_address, COM7;
    logic [7:0] read_data;
    logic [7:0] image_data;
    logic sccb_write_done,sccb_read_done;
    logic Camera_Hs,Camera_Vs;
    logic sccb_master_done;
    // tristate
    logic sio_d_write_en,sio_d_read_en;
    logic sio_dout_write,sio_dout_read;

    // test_set
    logic led_top;
    logic [7:0] led_data;
    logic led_clk1, led_clk2,led_clk3,led_clk4;
    
    logic pclk;
    logic clk_vga;
    
    //seg
    logic wclk;
    logic [6:0] seg;
    logic [3:0] an;
    logic [7:0] cnn_dt;
    logic cnn_valid;
    logic cnn_done;
    //VGA controller
    modport mid  ( input clk_vga,rstn,Vsync,finish,line_done,//line_done
                               output  Hsync,vgaRed,vgaBlue,vgaGreen,one_done,row_cnt,led_clk4);
    modport bot (input clk_vga,rstn,doutb,Vsync,row_cnt,finish,room_chk,//col_cnt; addrb를 input->output변경
                            output Hsync,vgaRed,vgaBlue,vgaGreen,addrb,rd_ready,led_clk3,line_done,one_done);//line_done
                                                
    //SCCB(OV7670) controller
    modport sccb_write (input clk,rstn,sccb_write_rstn,SIO_C,sio_c_n_edge,sio_c_p_edge,sccb_write_en,ID_address,Sub_address,COM7,
                                        output c_wt_en, sio_d_write_en,sio_dout_write,sccb_write_done);
                                        
    modport sccb_read   (input clk,rstn,sccb_read_rstn,sccb_read_en, ID_address,SIO_D_in,sio_c_p_edge,sio_c_n_edge,
                                        output c_rd_en,read_data,sccb_read_done,sio_d_read_en,sio_dout_read);
    
    modport sccb_top    (input pclk,rstn,sccb_write_done,sccb_read_done,read_data,
                                        output led_clk1,led_clk2,sccb_write_rstn,sccb_read_rstn,sccb_write_en,sccb_read_en,ID_address,Sub_address,COM7);
    
    modport sccb_master (input clk,pclk,rstn,sccb_write_done,sccb_read_done,read_data,
                                        output led_clk1,sccb_write_rstn,sccb_read_rstn,sccb_write_en,sccb_read_en,ID_address,Sub_address,COM7,sccb_master_done);

    //image conversion
    modport image_cov (input pclk,rstn,image_data,Camera_Hs,Camera_Vs,sccb_master_done, 
                                        output in_dt,addra,wt_valid,finish,led_clk2,room_chk,cnn_dt,cnn_valid,cnn_done);
    //
    modport make_sioc  (input clk,rstn,c_en, output SIO_C);   
    modport edged  (input clk,rstn,SIO_C,c_en, output sio_c_n_edge,sio_c_p_edge);   
    //
    modport cnn_top(input wclk,rstn,cnn_dt,cnn_valid,cnn_done, output seg,an);
    
    //modport testbench (input clk, output rstn,SIO_C,one_shot_top_in);
endinterface

/*
    SCL,SDA,
    PCLK,MCLK,
    VS,HS,D[7:0]
*/
module OV_VGA
(
    input wclk,
    input rstn,
    //OV7670
    output SIO_C,
    inout SIO_D,
    output MCLK,
    input PCLK,
    input Camera_Hs,Camera_Vs,
    input [7:0] image_data,
    //test_set
    output led_clk1,led_clk2,led_clk3,led_clk4,
    //vga
    output Hsync,Vsync,
    output [3:0] vgaRed,vgaGreen,vgaBlue,//, 쉼표와 XDC까지 
    output [6:0] seg,
    output [3:0] an
);
    assign led_data = main_bus.led_data;
//    assign led_top = main_bus.led_top;
    assign led_clk1 = main_bus.led_clk1;
    assign led_clk2 = main_bus.led_clk2;
    assign led_clk3 = main_bus.led_clk3;
    assign led_clk4 = main_bus.led_clk4;
    
    /*
        실제 동작위한 24Mhz기준 clock wizard
    */
    logic clk,clk_vga;
//    initial clk = 0;
//    always #20 clk = ~clk;//1Ghz/40 = 25Mhz :: 반주기 20 
    clk_wiz_0 cw0 
    (
        .clk_in1(wclk), 
        .reset(!rstn),
        .clk_out1(clk),            //24Mhz
        .clk_out2(clk_vga)     //25.178Mhz
    );
    //
    my_vga_if main_bus(clk);
    //
    //VGA_controller_t  t0(.mi0(main_bus.top) );
    //VGA_controller_m  m0 (.mi0(main_bus.mid));
    VGA_controller_b   b0   (.mi0(main_bus.bot));
    //
    //
    OV_write                  wt    (.mi0(main_bus.sccb_write));
    OV_read                   rd    (.mi0(main_bus.sccb_read));
    //OV_top                     ov   (.mi0(main_bus.sccb_top));
    OV_MASTER          ov_m (.mi0(main_bus.sccb_master));
    
    make_sio_c             c0    (.mi0(main_bus.make_sioc));
    edge_detector_n     ed0 (.mi0(main_bus.edged));
    //
    Image_conv             Icv0 (.m(main_bus.image_cov));
    //
    cnn_top                    cnn0(.m(main_bus.cnn_top));
    
    assign main_bus.clk_vga = clk_vga;
    assign main_bus.rstn = rstn;// input
    assign SIO_C                = main_bus.SIO_C;
    // 출력 MUX
    // 여러곳에서 SIO_D를 건드릴때는 제어신호를 달리 해야 함.
    assign SIO_D = (main_bus.sio_d_write_en) ? main_bus.sio_dout_write :
                               (main_bus.sio_d_read_en)  ? main_bus.sio_dout_read : 1'bz; //이 경우 쓰기 우선이 됨
   // 입력                         
    assign main_bus.SIO_D_in = SIO_D;
    //
    assign main_bus.image_data            = image_data;//revision
    //assign main_bus.one_shot_top_in    = one_shot_top;                  
    assign MCLK                                        = main_bus.clk;
    assign main_bus.pclk                         = PCLK;
    assign main_bus.Camera_Hs            = Camera_Hs;
    assign main_bus.Camera_Vs             = Camera_Vs;
    
    assign Hsync = main_bus.Hsync ;
    assign Vsync = main_bus.Vsync;
    assign vgaRed = main_bus.vgaRed;
    assign vgaBlue = main_bus.vgaBlue;
    assign vgaGreen = main_bus.vgaGreen ;
    
    assign main_bus.wclk = wclk ;//input
    assign seg = main_bus.seg ;//output
    assign an = main_bus.an;
    
    //                                                             OK.            
    // Camera -> OV_Master -> Image_conv -> BRAM -> VGA controller -> Monitor
    //             CLK               PCLK                 PCLK                                 CLK_VGA         
    
    // 144000 더블 버퍼링...
    blk_mem_gen_0    bram0(
                                            .addra(main_bus.addra),//넣고 계속 카운팅. 0 ~ 76779
                                            .clka(main_bus.pclk),//24Mhz
                                            .dina(main_bus.in_dt),//data
                                            .wea(main_bus.wt_valid),//write_enable - 값을 쓸때 1넣기rd_valid(fifo)
                                            .addrb(main_bus.addrb),//다음을 뽑기.
                                            .clkb(main_bus.clk_vga),//24Mhz
                                            .doutb(main_bus.doutb)
                                            );
endmodule
