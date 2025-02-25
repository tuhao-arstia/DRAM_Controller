////////////////////////////////////////////////////////////////////////
// Project Name: eHome-IV 
// Task Name   : Memory Controller
// Module Name : Ctrl
// File Name   : Ctrl.v
// Description : External memory interface construction
// Author      : Chih-Yuan Chang
// Revision History:
// Date        : 2012.12.24
////////////////////////////////////////////////////////////////////////

`include "define.v"
`include "bank_FSM.v"
`include "tP_counter.v"
`include "issue_FIFO.v"
`include "OUT_FIFO.v"
`include "cmd_scheduler.v"
`include "wdata_FIFO.v"

module Ctrl(   
//== I/O from System ===============
               power_on_rst_n,
               clk,
               clk2,
//==================================

//== I/O from access command =======
               write_data,
               command,
               read_data,
              // read_addr,
               valid,
               ba_cmd_pm,
               read_data_valid
//==================================
);
    
`include "2048Mb_ddr3_parameters.vh"

   // Declare Ports
    
    //== I/O from System ===============
    input  power_on_rst_n;
    input  clk;
    input clk2;
    //==================================
    //== I/O from access command =======
    input  [`DQ_BITS*8-1:0]   write_data;
    output [`DQ_BITS*8-1:0]    read_data;
    input  [31:0] command;
    input  valid ;
     
    output [3:0] ba_cmd_pm; //{power_up,power_down,refresh,write,read,active}
    output read_data_valid;
   //===================================
   
    // DRAM ports

    wire                  ck_n = ~clk;
	
    reg   [3:0]           cs_mux = 4'b1111;   

    reg   rst_n;
    reg   cke;
    reg   cs_n;
    reg   ras_n;
    reg   cas_n;
    reg   we_n;
    
    wire  [`DM_BITS-1:0]   dm_tdqs_in;
    reg   [`DM_BITS-1:0]   dm_tdqs_out;
    
    reg   [`BA_BITS-1:0]   ba;
    reg   [`ADDR_BITS-1:0] addr;
    
    wire  [`DQ_BITS-1:0] data_in;
    reg   [`DQ_BITS-1:0] data_out;
	
    wire  [8*`DQ_BITS-1:0] data_all_in;
    reg   [8*`DQ_BITS-1:0] data_all_out;	
    
    wire  [`DQS_BITS-1:0]  dqs_in;
    reg   [`DQS_BITS-1:0]  dqs_out;
    
    wire  [`DQS_BITS-1:0]  dqs_n_in;
    reg   [`DQS_BITS-1:0]  dqs_n_out;
    
    wire  [`DQS_BITS-1:0]  tdqs_n;
    reg   odt;
    reg   ddr3_rw ;// 0: write
                   // 1: read

	
	wire  [`DQ_BITS-1:0]  dq;
	wire  [8*`DQ_BITS-1:0] dq_all;
	wire  [`DM_BITS-1:0]  dm;
	wire  [`DQS_BITS-1:0] dqs;
	wire  [`DQS_BITS-1:0] dqs_n;
	
	
	
assign dm = (ddr3_rw) ? dm_tdqs_in : dm_tdqs_out ;	
	
assign dq = (ddr3_rw) ? 16'bz : data_out ;
assign data_in = (ddr3_rw) ? dq : 16'bz ;

assign dq_all = (ddr3_rw) ? 128'bz : data_all_out ;
assign data_all_in = (ddr3_rw) ? dq_all : 128'bz ;

assign dqs = (ddr3_rw) ? 2'bz : dqs_out ;
assign dqs_in = (ddr3_rw) ? dqs : 2'bz ;

assign dqs_n = (ddr3_rw) ? 2'bz : dqs_n_out ;
assign dqs_n_in = (ddr3_rw) ? dqs_n : 2'bz ;
	
reg [`FSM_WIDTH1-1:0]state,state_nxt ;

reg [3:0]d_state,d_state_nxt ;

reg [1:0]dq_state,dq_state_nxt ;

reg [9:0]counter,counter_nxt; //used for count command waiting latencys

reg [7:0]d0_counter,d0_counter_nxt; //used for read/write waiting output latencys
reg [7:0]d1_counter,d1_counter_nxt;
reg [7:0]d2_counter,d2_counter_nxt;
reg [7:0]d3_counter,d3_counter_nxt;
reg [7:0]d4_counter,d4_counter_nxt;

reg [4:0]d_counter_used,
         d_counter_used_nxt,
         d_counter_used_start,
         d_counter_used_end ;                //[0]:d0_counter,
                                             //[1]:d1_counter,
                                             //[2]:d2_counter,
                                             //[3]:d3_counter,
                                             //[4]:d4_counter


reg [1:0]act_counter;      //used for count active number 
reg [3:0]read_counter ;    //used for count the latest read latency , prevent tRTW
reg [3:0]write_counter ;   //prevent tWTR
reg [3:0]r_to_pre_counter ; //prevent tRTP
reg [3:0]w_to_pre_counter ;
reg [4:0]tRP_counter ;

reg [2:0]tCCD_counter ;
reg [3:0]tRTW_counter ;
reg [3:0]tWTR_counter ;

  
wire [4:0]tP_ba0_counter,tP_ba1_counter,tP_ba2_counter,tP_ba3_counter;

wire [5:0]tRAS0_counter,tRAS1_counter,tRAS2_counter,tRAS3_counter;
wire [5:0]tREF0_counter,tREF1_counter,tREF2_counter,tREF3_counter;          
wire [2:0]tP_c0_recode,tP_c1_recode,tP_c2_recode,tP_c3_recode;


reg [4:0]tP_bax,tP_baxx ;
reg [5:0]tRAS_bax,tRAS_baxx ;

reg [2:0]tP_recodex,tP_recodexx ;

reg [3:0]o_counter,o_counter_nxt;
reg [3:0]dq_counter,dq_counter_nxt;
reg out_ff ;
reg read_data_valid ;
reg W_BL ;

reg  [8*`DQ_BITS-1:0]  data_all_out_nxt;
reg  [`DQ_BITS-1:0]  data_out_t,data_out_nxt;
reg  [`DM_BITS-1:0]  dm_tdqs_out_nxt;
reg  [`DQS_BITS-1:0] dqs_out_nxt;
reg [`DQS_BITS-1:0] dqs_n_out_nxt;

reg [`BA_BITS-1:0] act_bank ;
reg [`ADDR_BITS-1:0] act_row ;
reg [`ADDR_BITS-1:0] act_addr ;
reg [`DQ_BITS*8-1:0] read_data ;
reg [3:0]act_command ;
reg act_busy ;


reg [`BA_BITS-1:0]   isu_bank ;
reg [`ADDR_BITS-1:0] isu_addr ;
reg [`DQ_BITS*8-1:0] isu_wdata; 
reg [3:0] isu_command ;
reg isu_en ;
reg [`ISSUE_BUF_PTR_SIZE-1:0]isu_buf_ptr ;
reg [84:0]isu_buf[`ISSUE_BUF_SIZE-1:0] ;
reg [`ISSUE_BUF_SIZE-1:0]isu_shift;
reg [`ISSUE_BUF_SIZE-1:0]isu_in;

reg [`DQ_BITS*8-1:0] WD ;

reg [4:0] cmd_RW_buf ; // 0 : write
                       // 1 : read
reg [2:0]W_buf_ptr ;
reg [2:0]process_BL ;
reg [`DQ_BITS-1:0] RD_buf[7:0] ;
reg [8*`DQ_BITS-1:0] RD_buf_all;
reg [`DQ_BITS-1:0] RD_temp;

reg read_odd ;

reg [1:0]bank_state[2**`BA_BITS-1:0];

reg [7:0]pre_all_t ;
reg pre_all ;
reg [3:0]now_issue ;
reg [2:0]now_bank;
reg [2:0]f_bank;
reg f_auto_pre ;

reg [`ADDR_BITS-1:0] now_addr ;
reg pre_store ;

reg [3:0]pre_cmd ;
reg [2:0]pre_bank ;
reg [`ADDR_BITS-1:0] pre_addr ;

reg [15:0]MR0,MR1,MR2,MR3 ;
reg tP_all_zero ;

wire [`FSM_WIDTH2-1:0]ba0_state ;
wire [`FSM_WIDTH2-1:0]ba1_state ;
wire [`FSM_WIDTH2-1:0]ba2_state ;
wire [`FSM_WIDTH2-1:0]ba3_state ;


wire ba0_busy,ba1_busy,ba2_busy,ba3_busy;                          
wire [`ADDR_BITS-1:0] ba0_addr,ba1_addr,ba2_addr,ba3_addr;  
wire [`DQ_BITS*8-1:0] ba0_wdata,ba1_wdata,ba2_wdata,ba3_wdata;
wire [3:0]ba0_command,ba1_command,ba2_command,ba3_command;
wire ba0_issue,ba1_issue,ba2_issue,ba3_issue;
wire [2:0]ba0_process_cmd,ba1_process_cmd,ba2_process_cmd,ba3_process_cmd;
wire ba0_stall,ba1_stall,ba2_stall,ba3_stall;


reg [3:0]ba_cmd_pm ;

//====== simulation test signal ======================
wire [`DQ_BITS-1:0] RD_buf_0 = RD_buf[0] ;
wire [`DQ_BITS-1:0] RD_buf_1 = RD_buf[1] ;
wire [`DQ_BITS-1:0] RD_buf_2 = RD_buf[2] ;
wire [`DQ_BITS-1:0] RD_buf_3 = RD_buf[3] ;
wire [`DQ_BITS-1:0] RD_buf_4 = RD_buf[4] ;
wire [`DQ_BITS-1:0] RD_buf_5 = RD_buf[5] ;
wire [`DQ_BITS-1:0] RD_buf_6 = RD_buf[6] ;
wire [`DQ_BITS-1:0] RD_buf_7 = RD_buf[7] ;

wire [1:0] bank0_state = bank_state[0];
wire [1:0] bank1_state = bank_state[1];
wire [1:0] bank2_state = bank_state[2];
wire [1:0] bank3_state = bank_state[3];

//=====================================================
wire [`ISU_FIFO_WIDTH-1:0]isu_fifo_out;
wire [`ISU_FIFO_WIDTH-1:0]isu_fifo_out_pre;
wire isu_fifo_full;
wire isu_fifo_vfull;
wire isu_fifo_empty;


reg out_fifo_wen;             
reg [`OUT_FIFO_WIDTH-1:0]out_fifo_in;
reg out_fifo_ren;
wire [`OUT_FIFO_WIDTH-1:0]out_fifo_out;
wire out_fifo_full;
wire out_fifo_vfull;
wire out_fifo_empty;

reg wdata_fifo_wen;
reg [`WDATA_FIFO_WIDTH-1:0]wdata_fifo_in;
reg wdata_fifo_ren;
wire [`WDATA_FIFO_WIDTH-1:0]wdata_fifo_out;
wire wdata_fifo_full;
wire wdata_fifo_vfull;
wire wdata_fifo_empty;


//DRAM Module
    ddr3 Bank0 (
        rst_n,
        clk, 
        ck_n,
        cke, 
        cs_mux[0] ? cs_n : 1'b1, 
        ras_n, 
        cas_n, 
        we_n, 
        dm, 
        ba, 
        addr, 
        dq, 
		dq_all,
        dqs,
        dqs_n,
        tdqs_n,
        odt
    );

    ddr3 Bank1 (
        rst_n,
        clk, 
        ck_n,
        cke, 
        cs_mux[1] ? cs_n : 1'b1, 
        ras_n, 
        cas_n, 
        we_n, 
        dm, 
        ba, 
        addr, 
        dq, 
		dq_all,
        dqs,
        dqs_n,
        tdqs_n,
        odt
    );	
	
    ddr3 Bank2 (
        rst_n,
        clk, 
        ck_n,
        cke, 
        cs_mux[2] ? cs_n : 1'b1, 
        ras_n, 
        cas_n, 
        we_n, 
        dm, 
        ba, 
        addr, 
        dq, 
		dq_all,
        dqs,
        dqs_n,
        tdqs_n,
        odt
    );

    ddr3 Bank3 (
        rst_n,
        clk, 
        ck_n,
        cke, 
        cs_mux[3] ? cs_n : 1'b1, 
        ras_n, 
        cas_n, 
        we_n, 
        dm, 
        ba, 
        addr, 
        dq, 
		dq_all,
        dqs,
        dqs_n,
        tdqs_n,
        odt
    );	


// Bank state connection
bank_FSM    ba0(.state      (state) ,
                .stall      (ba0_stall),
                .valid      (valid)   ,
                .command    (command)   ,
                .number     (3'd0)   ,
                .rst_n      (power_on_rst_n)   ,
                .clk        (clk)   ,
                .ba_state   (ba0_state)   ,
                .ba_busy    (ba0_busy  )   , 
                .ba_addr    (ba0_addr    )   ,
                
                .ba_issue   (ba0_issue),
                .process_cmd(ba0_process_cmd)  
                );

bank_FSM    ba1(.state      (state) ,
                .stall      (ba1_stall), 
                .valid      (valid)   ,
                .command    (command)   ,
                .number     (3'd1)   ,
                .rst_n      (power_on_rst_n)   ,
                .clk        (clk)   ,
                .ba_state   (ba1_state)   ,
                .ba_busy    (ba1_busy  )   ,                    
                .ba_addr    (ba1_addr    )   ,
               
                .ba_issue   (ba1_issue),
                .process_cmd(ba1_process_cmd)   
                );                           

bank_FSM    ba2(.state      (state) ,
                .stall      (ba2_stall), 
                .valid      (valid)   ,
                .command    (command)   , 
                .number     (3'd2)   ,
                .rst_n      (power_on_rst_n)   ,
                .clk        (clk)   ,
                .ba_state   (ba2_state)   ,
                .ba_busy   (ba2_busy  )   ,                    
                .ba_addr    (ba2_addr    )   ,
               
                .ba_issue   (ba2_issue),
                .process_cmd(ba2_process_cmd)  
                );

bank_FSM    ba3(.state      (state) ,
                .stall      (ba3_stall), 
                .valid      (valid)   ,
                .command    (command)   , 
                .number     (3'd3)   ,
                .rst_n      (power_on_rst_n)   ,
                .clk        (clk)   ,
                .ba_state   (ba3_state)   ,
                .ba_busy   (ba3_busy  )   ,                    
                .ba_addr    (ba3_addr    )   ,
               
                .ba_issue   (ba3_issue),
                .process_cmd(ba3_process_cmd)  
                );


wire [`BA_INFO_WIDTH-1:0]ba0_info = {ba0_state,ba0_addr,ba0_process_cmd} ;
wire [`BA_INFO_WIDTH-1:0]ba1_info = {ba1_state,ba1_addr,ba1_process_cmd} ;
wire [`BA_INFO_WIDTH-1:0]ba2_info = {ba2_state,ba2_addr,ba2_process_cmd} ;
wire [`BA_INFO_WIDTH-1:0]ba3_info = {ba3_state,ba3_addr,ba3_process_cmd} ;
wire [`ISU_FIFO_WIDTH-1:0] sch_out ;

//Command Schedular
cmd_scheduler  scheduler(
                         .clk      (clk           )  ,
                         .rst_n    (power_on_rst_n)     ,
                         .isu_fifo_full (isu_fifo_full) ,
                         .ba0_info (ba0_info)  ,
                         .ba1_info (ba1_info)  ,
                         .ba2_info (ba2_info)  ,
                         .ba3_info (ba3_info)  ,

                         .ba0_stall(ba0_stall) ,
                         .ba1_stall(ba1_stall) ,
                         .ba2_stall(ba2_stall) ,
                         .ba3_stall(ba3_stall) ,

                         .sch_out  (sch_out  ) ,
                         .sch_issue(sch_issue)
                         );


//Timing Counter						 
tP_counter  tP_ba0(.rst_n        (power_on_rst_n),
                   .clk          (clk),
                   .f_bank       (f_bank),
                   .BL           (MR0[1:0]),
                   .state_nxt    (state_nxt),
                   .number       (3'd0),
                   .tP_ba_counter(tP_ba0_counter),
                   .tRAS_counter (tRAS0_counter),
				   .tREF_counter (tREF0_counter),
                   .recode       (tP_c0_recode),
                   .auto_pre     (f_auto_pre)
                   );

tP_counter  tP_ba1(.rst_n        (power_on_rst_n),
                   .clk          (clk),
                   .f_bank       (f_bank),
                   .BL           (MR0[1:0]),
                   .state_nxt    (state_nxt),
                   .number       (3'd1),
                   .tP_ba_counter(tP_ba1_counter),
                   .tRAS_counter (tRAS1_counter),
				   .tREF_counter (tREF1_counter),
                   .recode       (tP_c1_recode),
                   .auto_pre     (f_auto_pre)
                   );
                   
tP_counter  tP_ba2(.rst_n        (power_on_rst_n),
                   .clk          (clk),
                   .f_bank       (f_bank),
                   .BL           (MR0[1:0]),
                   .state_nxt    (state_nxt),
                   .number       (3'd2),
                   .tP_ba_counter(tP_ba2_counter),
                   .tRAS_counter (tRAS2_counter),
				   .tREF_counter (tREF2_counter),
                   .recode       (tP_c2_recode),
                   .auto_pre     (f_auto_pre)
                   );
                   
tP_counter  tP_ba3(.rst_n        (power_on_rst_n),
                   .clk          (clk),
                   .f_bank       (f_bank),
                   .BL           (MR0[1:0]),
                   .state_nxt    (state_nxt),
                   .number       (3'd3),
                   .tP_ba_counter(tP_ba3_counter),
                   .tRAS_counter (tRAS3_counter),
				   .tREF_counter (tREF3_counter),
                   .recode       (tP_c3_recode),
                   .auto_pre     (f_auto_pre)
                   );

wire isu_fifo_wen = sch_issue ;

                                   
issue_FIFO  isu_fifo(.clk          (clk),
                     .rst_n        (power_on_rst_n),
                     .wen          (isu_fifo_wen),              
                     .data_in      (sch_out),
                     .ren          (~act_busy),
                     .data_out     (isu_fifo_out),
                     .data_out_pre (isu_fifo_out_pre),
                     .full         (isu_fifo_full),
                     .virtual_full (isu_fifo_vfull),
                     .empty        (isu_fifo_empty)
                     );                   

wdata_FIFO wdata_fifo( .clk          (clk),           
                       .rst_n        (power_on_rst_n),
                       .wen          (wdata_fifo_wen),      
                       .data_in      (wdata_fifo_in),   
                       .ren          (wdata_fifo_ren),  
                       .data_out     (wdata_fifo_out),  
                       .full         (wdata_fifo_full), 
                       .virtual_full (wdata_fifo_vfull),
                       .empty        (wdata_fifo_empty) 
                       );



OUT_FIFO out_fifo( .clk         (clk),
                   .rst_n       (power_on_rst_n),
                   .wen         (out_fifo_wen),              
                   .data_in     (out_fifo_in),
                   .ren         (out_fifo_ren),
                   .data_out    (out_fifo_out),
                   .full        (out_fifo_full),
                   .virtual_full(out_fifo_vfull),
                   .empty       (out_fifo_empty)
                 );
                   
                                                                             
//==== Sequential =======================

always@(posedge clk) begin
  MR0 <= `MR0_CONFIG ;
  MR1 <= `MR1_CONFIG ;
  MR2 <= `MR2_CONFIG ;
  MR3 <= `MR3_CONFIG ;
end
  
always@(posedge clk) begin
if(power_on_rst_n == 0)
  state <= `FSM_POWER_UP ;
else
  state <= state_nxt ;
end

always@(posedge clk) begin
if(power_on_rst_n == 0)
  d_state <= `D_IDLE ;
else
  d_state <= d_state_nxt ;
end

always@(posedge clk) begin
if(power_on_rst_n == 0)
  dq_state <= `DQ_IDLE ;
else
  dq_state <= dq_state_nxt ;
end

//time counter
always@(posedge clk) begin
if(power_on_rst_n == 0)
  counter <= 14 ;
else
  counter <= counter_nxt ;
end


always@(posedge clk) begin
if(power_on_rst_n == 0) begin
  d0_counter <= 0 ;
  d1_counter <= 0 ;
  d2_counter <= 0 ;
  d3_counter <= 0 ;
  d4_counter <= 0 ;
end
else begin
  d0_counter <= d0_counter_nxt ;
  d1_counter <= d1_counter_nxt ;
  d2_counter <= d2_counter_nxt ;
  d3_counter <= d3_counter_nxt ;
  d4_counter <= d4_counter_nxt ;
end
end

always@(posedge clk) begin
if(power_on_rst_n == 0)
  d_counter_used <= 0 ;
else 
  d_counter_used <= d_counter_used_nxt ;
end

//output counter
always@(posedge clk) begin
if(power_on_rst_n == 0)
  o_counter <= 0 ;
else
  o_counter <= o_counter_nxt ;
end


always@(posedge clk) begin
if(power_on_rst_n == 0)
  tCCD_counter <= 0 ;
else
  case(state_nxt)
    `FSM_READ,
    `FSM_WRITE     : tCCD_counter <= `CYCLE_TCCD - 1 ;
    `FSM_WAIT_TCCD : tCCD_counter <= tCCD_counter - 1 ;
    default        : tCCD_counter <= (tCCD_counter == 0) ? 0 : tCCD_counter - 1 ;
  endcase
end

always@(posedge clk) begin
if(power_on_rst_n == 0)
  tRTW_counter <= 0 ;
else
  case(state_nxt)
    `FSM_READ      : tRTW_counter <= `CYCLE_TRTW - 1 ;
    `FSM_WAIT_TRTW : tRTW_counter <=  tRTW_counter - 1 ;
    default        : tRTW_counter <= (tRTW_counter == 0) ? 0 : tRTW_counter - 1 ;
  endcase
end

always@(posedge clk) begin
if(power_on_rst_n == 0)
  tWTR_counter <= 0 ;
else
  case(state_nxt)
    `FSM_WRITE      : if(MR0[1:0] == 2'b01)
                        tWTR_counter <= `CYCLE_TOTAL_WL+`CYCLE_TWTR+4-1 ;
                      else if(MR0[1:0] == 2'b00)
                        tWTR_counter <= `CYCLE_TOTAL_WL+`CYCLE_TWTR+4-1 ;
                      else
                        tWTR_counter <= `CYCLE_TOTAL_WL+`CYCLE_TWTR+2-1 ;

    `FSM_READY      : tWTR_counter <= (tWTR_counter == 0) ? 0 : tWTR_counter - 1 ;
    `FSM_WAIT_TWTR  : tWTR_counter <=  tWTR_counter - 1 ;
    default         : tWTR_counter <= (tWTR_counter == 0) ? 0 : tWTR_counter - 1 ;
  endcase
end

//time counter
always@(posedge clk2) begin
  dq_counter <= dq_counter_nxt ;
end

//active busy control
always@* begin
 case(state)
   `FSM_READ   : act_busy = 0 ;
   `FSM_WRITE  : act_busy = 0 ;
   `FSM_PRE    : act_busy = 0 ;
   `FSM_ACTIVE : act_busy = 0 ;
   `FSM_READY  : act_busy = 0 ;
   default     : act_busy = 1 ;
 endcase
end

always@(posedge clk) begin
if(act_busy==0)	
    if(isu_fifo_empty==0) begin
       act_bank    <= isu_fifo_out[2:0] ;
       act_addr    <= isu_fifo_out[16:3] ;
       act_command <= isu_fifo_out[20:17] ;
    end
    else begin
       act_bank    <= 0 ;     
       act_addr    <= 0 ;        
       act_command <= `ATCMD_NOP ;   
    end
else begin
 act_bank    <= act_bank ;     
 act_addr    <= act_addr ;   
 act_command <= act_command ;     
end
  
end

always@(posedge clk) begin
if(power_on_rst_n==0)
  act_counter <= 0 ;
else
  case(state)
    `FSM_READY : act_counter <= act_counter ;
    //`FSM_WAIT_TRRD 
    
    `FSM_ACTIVE : act_counter <= (act_counter == 3) ? 0 : act_counter+1 ;
    default : act_counter <= act_counter ;
  endcase

end

always@(posedge clk) begin
if(power_on_rst_n==0)
  read_counter <= 0 ;
else
  if(state == `FSM_READ)
    read_counter <= 0 ;
  else
    if(read_counter == `CYCLE_TRTW-4)
      read_counter <= read_counter ;
    else  
      read_counter <= read_counter + 1 ;
end

always@(posedge clk) begin
	
if(power_on_rst_n==0)
  write_counter <= 0 ;
else
  if(d_state == `D_WRITE_F)
    write_counter <= 1 ;
  else if (d_state == `D_IDLE)
    if(write_counter != 0)
      write_counter <= (write_counter == `CYCLE_TWTR-3) ? write_counter : write_counter + 1 ; 
    else
      write_counter <= 0 ;
  else
    write_counter <= 0 ;

end

always@* begin
wdata_fifo_in = {write_data,command[15]} ; // {data,burst_length}

if(command[31]==0 && valid==1) //write command
  wdata_fifo_wen=1 ;
else
  wdata_fifo_wen=0 ;

if( d_state_nxt == `D_WRITE_F )
  wdata_fifo_ren = 1 ;
else
  wdata_fifo_ren = 0 ;
    
end

always@* begin
if(isu_fifo_vfull || wdata_fifo_vfull)
  ba_cmd_pm = 0 ;
else
  ba_cmd_pm = ~{ba3_busy,ba2_busy,ba1_busy,ba0_busy}  ;
end


always@* begin
if(d_state_nxt == `D_WRITE_F || d_state_nxt == `D_READ_F) 
  out_fifo_ren = 1 ;
else
  out_fifo_ren = 0 ;
end  

always@* begin
  if(state == `FSM_WRITE) begin
  	out_fifo_wen = 1 ;
    out_fifo_in = {1'b0,act_addr[12]} ; // {read/write,Burst_Length} ;
  end
  else if (state == `FSM_READ) begin
  	out_fifo_wen = 1 ;
    out_fifo_in = {1'b1,act_addr[12]} ; // {read/write,Burst_Length} ;
  end
  else begin
  	out_fifo_wen = 0 ;
  	out_fifo_in = 0 ; 
  end
end
  

always@(posedge clk) begin
if(power_on_rst_n == 0)
  process_BL <= 0 ;
else
  if(d_state == `D_IDLE)
    process_BL <= 0 ;
  else
    process_BL <= (W_BL) ? 3 : 3 ; 
end


always@(posedge clk) begin
if(power_on_rst_n == 0)
  read_data_valid <= 0 ;
else
  if(d_state_nxt == `D_READ_F)
    read_data_valid <= 1 ;
  else
    read_data_valid <= 0 ;
end


//command output
// {cke,cs_n,ras_n,cas_n,we_n}
always@(negedge clk) begin
  case(state)
    `FSM_POWER_UP : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_POWER_UP ;
    `FSM_ZQ       : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_ZQ_CALIBRATION ;
    `FSM_LMR0,
    `FSM_LMR1,
    `FSM_LMR2,
    `FSM_LMR3     : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_LOAD_MODE ;
    `FSM_ACTIVE   : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_ACTIVE ;
    `FSM_READ     : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_READ ;
    `FSM_WRITE    : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_WRITE ;
    `FSM_PRE      : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_PRECHARGE ;
    default : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_NOP ;
  endcase
end

always@(negedge clk) begin
  case(state)
    `FSM_ZQ       : addr <= 1024 ; //A10 = 1 ;
    `FSM_LMR0     : addr <= MR0;
    `FSM_LMR1     : addr <= MR1;
    `FSM_LMR2     : addr <= MR2; 
    `FSM_LMR3     : addr <= MR3;  
    `FSM_ACTIVE   : addr <= act_addr ;
    `FSM_READ     : addr <= act_addr ;
    `FSM_WRITE    : addr <= act_addr ;
    `FSM_PRE      : addr <= act_addr ;
    default : addr <= addr ;
  endcase
end

always@(negedge clk) begin
  case(state)
    `FSM_ZQ       : ba <= 0 ; //A10 = 1 ;
    `FSM_LMR0     : ba <= 0 ;
    `FSM_LMR1     : ba <= 1 ;
    `FSM_LMR2     : ba <= 2 ;
    `FSM_LMR3     : ba <= 3 ;
    `FSM_ACTIVE   : ba <= 0;//act_bank ;
    `FSM_READ     : ba <= 0;//act_bank ;
    `FSM_WRITE    : ba <= 0;//act_bank ;
    `FSM_PRE      : ba <= 0;//act_bank ;

    default : ba <= ba ;
  endcase
end

always@(negedge clk) begin
  case(state)
    `FSM_ZQ       : cs_mux <= 4'b1111; //1 = selected , 0 = no selected
    `FSM_LMR0     : cs_mux <= 4'b1111;
    `FSM_LMR1     : cs_mux <= 4'b1111;
    `FSM_LMR2     : cs_mux <= 4'b1111;
    `FSM_LMR3     : cs_mux <= 4'b1111;
    `FSM_ACTIVE,  
    `FSM_READ,    
    `FSM_WRITE,   
    `FSM_PRE      : begin 
					case(act_bank) 
					3'd0:  cs_mux <= 4'b0001;
					3'd1:  cs_mux <= 4'b0010;
					3'd2:  cs_mux <= 4'b0100;
					3'd3:  cs_mux <= 4'b1000;
					default cs_mux <= cs_mux;
					endcase
					end
    default : cs_mux <= cs_mux ;
  endcase
end


//=======================================

//pad_rw
always@(negedge clk) begin
case(d_state_nxt)
  `D_READ1   : ddr3_rw <= 1 ;
  `D_READ2   : ddr3_rw <= 1 ;
  `D_READ_F  : ddr3_rw <= 1 ;
  `D_WRITE1  : ddr3_rw <= 0 ;
  `D_WRITE2  : ddr3_rw <= 0 ;
  `D_WRITE_F : ddr3_rw <= 0 ;
  default  : ddr3_rw <= ddr3_rw ;
endcase
end

//odt control
always@(negedge clk) begin
if(power_on_rst_n == 0)
  odt <= 0 ;
else
  case(state)
    `FSM_READ  : odt <= 0 ;
    `FSM_WRITE : odt <= 0 ;
    default : odt <= odt ;
  endcase  
end

always@(negedge clk) begin
if(power_on_rst_n == 0)
  out_ff <= 0 ;
else
  out_ff <= (d_state == `D_WRITE1 || d_state == `D_WRITE2) ? ~out_ff : 0 ;
  
end


always@(posedge clk2) begin

  dqs_out <= dqs_out_nxt ;
	dqs_n_out <= dqs_n_out_nxt ;

end

always@* begin	
	case(d_state)
    `D_WRITE1 : begin
                  if(dqs_out == 2'b11) begin
                    dqs_out_nxt = ~dqs_out ;   
                    dqs_n_out_nxt = ~dqs_n_out ;
                  end	
                  else begin
    	              dqs_out_nxt = (out_ff) ? 2'b11 : 2'bZZ ;
    	              dqs_n_out_nxt = (out_ff) ? 2'b00 : 2'bZZ ;
    	            end
    	          end
    	          
    `D_WRITE2 : begin
                  dqs_out_nxt = ~dqs_out ;
                  dqs_n_out_nxt = ~dqs_n_out ;
                end
    `D_WRITE_F: if(d0_counter == `CYCLE_TOTAL_WL-1-1 || d1_counter == `CYCLE_TOTAL_WL-1-1 ||
                   d2_counter == `CYCLE_TOTAL_WL-1-1 || d3_counter == `CYCLE_TOTAL_WL-1-1 ||
                   d4_counter == `CYCLE_TOTAL_WL-1-1) begin
                
                   dqs_out_nxt = ~dqs_out ;
                   dqs_n_out_nxt = ~dqs_n_out ;              
    
                end
                else if(d0_counter == `CYCLE_TOTAL_WL-1 || d1_counter == `CYCLE_TOTAL_WL-1 ||
                        d2_counter == `CYCLE_TOTAL_WL-1 || d3_counter == `CYCLE_TOTAL_WL-1 ||
                        d4_counter == `CYCLE_TOTAL_WL-1) begin
                   
                   dqs_out_nxt = ~dqs_out ;
                   dqs_n_out_nxt = ~dqs_n_out ;
                end
                else if(d0_counter == `CYCLE_TOTAL_WL-1+1 || d1_counter == `CYCLE_TOTAL_WL-1+1 ||
                        d2_counter == `CYCLE_TOTAL_WL-1+1 || d3_counter == `CYCLE_TOTAL_WL-1+1 ||
                        d4_counter == `CYCLE_TOTAL_WL-1+1) begin
                   
                   dqs_out_nxt = ~dqs_out ;
                   dqs_n_out_nxt = ~dqs_n_out ;
                end   
                else begin
                   dqs_out_nxt = ~dqs_out ;
                   dqs_n_out_nxt = ~dqs_n_out ;
                end
    `D_READ_F  :begin
                   dqs_out_nxt = 2'b11 ;
                   dqs_n_out_nxt = 2'b00 ;
                end               
    default    : begin
    	             dqs_out_nxt = 2'bzz ;
    	             dqs_n_out_nxt = 2'bzz ;
    	           end
  endcase
end

always@(posedge clk2) begin
  data_out <= data_out_nxt ;	
end

always@(posedge clk2) begin
  data_all_out <= data_all_out_nxt ;	
end

always@(posedge clk2) begin
  dm_tdqs_out <= dm_tdqs_out_nxt ;  
end	

always@* begin	
  if(dq_state == `DQ_OUT) begin
    if(W_BL==0) //Burst Length = 4
      dm_tdqs_out_nxt = (dq_counter <= 3) ? 2'b00 : 2'b11 ;
    else //Burst_Length = 8
      dm_tdqs_out_nxt = (dq_counter <= 7) ? 2'b00 : 2'b11 ;
  end 
  else
    dm_tdqs_out_nxt = 2'b11 ;
end


always@(negedge clk) begin

RD_buf[0] <= (dq_counter == 2 && (d_state == `D_READ2 || d_state == `D_WAIT_CL_READ) ) ? RD_temp : RD_buf[0];
RD_buf[2] <= (dq_counter == 2 && d_state == `D_READ2) ? data_in : RD_buf[2];
RD_buf[4] <= (dq_counter == 4 && d_state == `D_READ2) ? data_in : RD_buf[4];
RD_buf[6] <= (dq_counter == 6 && d_state == `D_READ2) ? data_in : RD_buf[6];

end

always@(posedge clk) begin

RD_buf[1] <= (dq_counter == 1 && (d_state == `D_READ2 || d_state == `D_READ_F) ) ? data_in : RD_buf[1];
RD_buf[3] <= (dq_counter == 3 && d_state == `D_READ2) ? data_in : RD_buf[3];
RD_buf[5] <= (dq_counter == 5 && d_state == `D_READ2) ? data_in : RD_buf[5];
RD_buf[7] <= (dq_counter == 7 && d_state == `D_READ2) ? data_in : RD_buf[7];

end

always@(posedge clk) begin

RD_buf_all <= (dq_counter == 1 && (d_state == `D_READ2 || d_state == `D_READ_F) ) ? data_all_in : RD_buf_all;


end

always@(negedge clk) begin
case(d_state)

  `D_READ_F  :  RD_temp <= data_in ;
  
  `D_READ2   :  RD_temp <= data_in ;
  
  default    :  RD_temp <= RD_temp ;
  
endcase    
end


always@(posedge clk) begin	
if(power_on_rst_n == 0)	
  isu_buf_ptr <= 0 ;
else
  if(isu_en == 0 && act_busy == 0)
    isu_buf_ptr <= (isu_buf_ptr == 0) ? 0 : isu_buf_ptr - 1 ;
  else if(isu_en == 0 && act_busy == 1)
    isu_buf_ptr <= isu_buf_ptr ;
  else if(isu_en == 1 && act_busy == 0)
    isu_buf_ptr <= isu_buf_ptr ;
  else
    isu_buf_ptr <= isu_buf_ptr + 1 ;
end

always@* begin
case(state_nxt)
  `FSM_WRITE,
  `FSM_READ,
  `FSM_PRE,
  `FSM_ACTIVE : pre_store = 1 ;
  default : pre_store = 0 ;      
endcase	

end

always@* begin
	
    if(isu_fifo_empty==0) begin
       pre_bank = isu_fifo_out_pre[2:0] ;
       pre_addr = isu_fifo_out_pre[16:3] ;
       pre_cmd  = isu_fifo_out_pre[20:17] ;
    end
    else begin                    
       pre_bank = 0 ;         
       pre_addr = 0 ;                
       pre_cmd  = `ATCMD_NOP ;   
    end                                                        
                                  
end

always@* begin
case(now_bank)
  0       :  tP_bax = tP_ba0_counter ;
  1       :  tP_bax = tP_ba1_counter ;
  2       :  tP_bax = tP_ba2_counter ;
  3       :  tP_bax = tP_ba3_counter ;
  default :  tP_bax = tP_ba0_counter ;
endcase

case(act_bank)
  0       :  tP_baxx = tP_ba0_counter ;
  1       :  tP_baxx = tP_ba1_counter ;
  2       :  tP_baxx = tP_ba2_counter ;
  3       :  tP_baxx = tP_ba3_counter ;
  default :  tP_baxx = tP_ba0_counter ;
endcase

if(tP_ba0_counter==0 && tP_ba1_counter==0 && tP_ba2_counter==0 && tP_ba3_counter==0)

  tP_all_zero = 1 ;
else
  tP_all_zero = 0 ;

end

always@* begin
case(now_bank)
  0       :  tP_recodex = tP_c0_recode ;
  1       :  tP_recodex = tP_c1_recode ;
  2       :  tP_recodex = tP_c2_recode ;
  3       :  tP_recodex = tP_c3_recode ;
  default :  tP_recodex = tP_c0_recode ;
endcase

case(act_bank)
  0       :  tP_recodexx = tP_c0_recode ;
  1       :  tP_recodexx = tP_c1_recode ;
  2       :  tP_recodexx = tP_c2_recode ;
  3       :  tP_recodexx = tP_c3_recode ;
  default :  tP_recodexx = tP_c0_recode ;
endcase

end

always@* begin
case(now_bank)
  0       :  tRAS_bax = tRAS0_counter ;
  1       :  tRAS_bax = tRAS1_counter ;
  2       :  tRAS_bax = tRAS2_counter ;
  3       :  tRAS_bax = tRAS3_counter ;
  default :  tRAS_bax = tRAS0_counter ;
endcase

case(act_bank)
  0       :  tRAS_baxx = tRAS0_counter ;
  1       :  tRAS_baxx = tRAS1_counter ;
  2       :  tRAS_baxx = tRAS2_counter ;
  3       :  tRAS_baxx = tRAS3_counter ;
  default :  tRAS_baxx = tRAS0_counter ;
endcase

end

always@* begin
case(state)
  `FSM_READY  : f_bank = now_bank ;
  `FSM_READ,
  `FSM_WRITE,
  `FSM_PRE,
  `FSM_ACTIVE : f_bank = now_bank ;
  default     : f_bank = act_bank ;
endcase
end

always@* begin
case(state)
  `FSM_READY  : f_auto_pre = now_addr[10] ;
  `FSM_READ,
  `FSM_WRITE,
  `FSM_PRE,
  `FSM_ACTIVE : f_auto_pre = now_addr[10] ;
  default     : f_auto_pre = act_addr[10] ;
endcase
end

//command state defination
always@* begin
	
	now_issue = (isu_fifo_empty) ? `ATCMD_NOP : isu_fifo_out[20:17] ;
  now_bank = (isu_fifo_empty) ? 0 : isu_fifo_out[2:0] ;
  now_addr = (isu_fifo_empty) ? 0 : isu_fifo_out[16:3] ;
	  
  case(state)
   `FSM_POWER_UP  : state_nxt = (counter == 0) ? `FSM_WAIT_TXPR : `FSM_POWER_UP  ;
   `FSM_WAIT_TXPR : state_nxt = (counter == 0) ? `FSM_ZQ : `FSM_WAIT_TXPR ;
   `FSM_ZQ        : state_nxt = `FSM_LMR0 ;
   `FSM_LMR0      : state_nxt = `FSM_WAIT_TMRD ;
   `FSM_WAIT_TMRD : case(counter)
                     7 : state_nxt = `FSM_LMR1 ;
                     4 : state_nxt = `FSM_LMR2 ;
                     1 : state_nxt = `FSM_LMR3 ;
                     default : state_nxt = state ;
                    endcase
   `FSM_LMR1     : state_nxt = `FSM_WAIT_TMRD ;
   `FSM_LMR2     : state_nxt = `FSM_WAIT_TMRD ;
   `FSM_LMR3     : state_nxt = `FSM_WAIT_TDLLK ;
   `FSM_WAIT_TDLLK : state_nxt = (counter == 0) ? `FSM_IDLE : `FSM_WAIT_TDLLK ;
   `FSM_IDLE      : state_nxt = `FSM_READY ;
   
   
   `FSM_READ,
   `FSM_WRITE,
   `FSM_PRE,
   `FSM_ACTIVE,
   `FSM_READY     :  case(now_issue)
                       `ATCMD_NOP      : state_nxt = `FSM_READY ;
                       `ATCMD_ACTIVE   : if(tRAS_bax != 0)//tRC violation
                                           state_nxt = `FSM_WAIT_TRC ;
                                         else if(tP_bax != 0 && (tP_recodex==2 || tP_recodex==5 || tP_recodex==6) )//tRP violation
                                           state_nxt = `FSM_WAIT_TRP ;
                                         else//no violation
                                           state_nxt = `FSM_ACTIVE ;

                       `ATCMD_READ     :if(tWTR_counter!=0) // tWTR violation
                                          state_nxt = `FSM_WAIT_TWTR ;
                                        else if(tP_bax != 0 && tP_recodex==3)//tRCD violation
                                          state_nxt = `FSM_WAIT_TRCD ;
                                        else if(tCCD_counter != 0) //tCCD violation
                                          state_nxt = `FSM_WAIT_TCCD ;
                                        else
                                          state_nxt = `FSM_READ ; 

                                            
                       `ATCMD_WRITE    :if(tP_bax != 0 && tP_recodex==3)//tRCD violation
                                          state_nxt = `FSM_WAIT_TRCD ;
                                        else if(tCCD_counter != 0 || tRTW_counter !=0)//tCCD violation or tRTW violation
                                          if(tCCD_counter>=tRTW_counter)
                                            state_nxt = `FSM_WAIT_TCCD ;
                                          else
                                            state_nxt = `FSM_WAIT_TRTW ;
                                        else
                                          state_nxt = `FSM_WRITE ;
      
                       `ATCMD_PRECHARGE:if(tRAS_bax >= `CYCLE_TRC-`CYCLE_TRAS) //tRAS violation
                                          state_nxt = `FSM_WAIT_TRAS ;
                                        else if(tP_bax != 0 && tP_recodex==1)//tWR violation
                                          state_nxt = `FSM_WAIT_TW ;  
                                        else if(tP_bax != 0 && tP_recodex==4)//tRTP violation
                                          state_nxt = `FSM_WAIT_TRTP ;
                                        else
                                          if(now_addr[10]) //precharge all
                                            state_nxt = (tP_all_zero) ? `FSM_PRE : `FSM_WAIT_TW ;                                               
                                          else
                                            state_nxt = `FSM_PRE ;
                       default         : state_nxt = state ;
                     endcase

   `FSM_WAIT_TRC : if(tRAS_baxx!=0)
                     state_nxt = `FSM_WAIT_TRC ;
                   else
                     if(tP_baxx!=0 && (tP_recodexx==2 || tP_recodexx==5 || tP_recodexx==6))
                       state_nxt = `FSM_WAIT_TRP ;
                     else
                       state_nxt = `FSM_ACTIVE ; 
                                      
   `FSM_WAIT_TCCD: if(tCCD_counter == 0)
                     if(act_command == `ATCMD_READ)
                       state_nxt = `FSM_READ ;
                     else if (act_command == `ATCMD_WRITE)
                       state_nxt = `FSM_WRITE ;
                     else
                       state_nxt = state ;
                   else
                     state_nxt = `FSM_WAIT_TCCD ;
                      
   `FSM_WAIT_TRCD,
   `FSM_WAIT_TW,  
   `FSM_WAIT_TRP, 
   `FSM_WAIT_TRTP:if(tP_baxx==0)
                    case(tP_recodexx)
                      1       : state_nxt = `FSM_PRE ;
                      2,
                      5,
                      6       : state_nxt = `FSM_ACTIVE ; 
                      3       : if(act_command == `ATCMD_READ)
                                  if(tCCD_counter==0)
                                    state_nxt = `FSM_READ ;
                                  else
                                    state_nxt = `FSM_WAIT_TCCD ;
                                else if(act_command == `ATCMD_WRITE)
                                  if(tCCD_counter==0 && tRTW_counter==0)
                                    state_nxt = `FSM_WRITE ;
                                  else if(tCCD_counter >= tRTW_counter)
                                    state_nxt = `FSM_WAIT_TCCD ;
                                  else
                                    state_nxt = `FSM_WAIT_TRTW ;
                                else
                                  state_nxt = state ;    
                                                                     
                      4       : state_nxt = `FSM_PRE ;
                      default : state_nxt = `FSM_PRE ;
                    endcase
                  else
                    state_nxt = state ;
                                        
   `FSM_WAIT_TRTW: state_nxt = (tRTW_counter==0) ? `FSM_WRITE : `FSM_WAIT_TRTW ;   
   `FSM_WAIT_TWTR: if(tWTR_counter==0)
                     if(tP_baxx!=0 && tP_recodexx==3)//check tRCD violation
                       state_nxt = `FSM_WAIT_TRCD ;
                     else
                       state_nxt = `FSM_READ ;
                   else
                     state_nxt = `FSM_WAIT_TWTR ;
               
	 `FSM_WAIT_TRAS: if(tRAS_baxx>=(`CYCLE_TRC-`CYCLE_TRAS))
                     state_nxt = `FSM_WAIT_TRAS ;
	                 else
	                   if(tP_baxx!=0)
	                     case(tP_recodexx)
	                       1      : state_nxt = `FSM_WAIT_TW ;
	                       4      : state_nxt = `FSM_WAIT_TRTP ;
	                       default: state_nxt = `FSM_PRE ;
	                     endcase
	                   else
	                     state_nxt = `FSM_PRE ;
	                     
	 `FSM_DLY_READ   : state_nxt = `FSM_READ ;	                     
   `FSM_DLY_WRITE  : state_nxt = `FSM_WRITE ;
   `FSM_PRE        : state_nxt = `FSM_READY ; 
                      
   default : state_nxt = state ;
  endcase
end

always@* begin
  case(state)
    `FSM_POWER_UP  : counter_nxt = (state_nxt == `FSM_POWER_UP) ? counter - 1 : `CYCLE_TXPR ;
    `FSM_WAIT_TXPR : counter_nxt = (state_nxt == `FSM_WAIT_TXPR) ? counter - 1 : 0 ;
    `FSM_ZQ        : counter_nxt = `CYCLE_TMRD ;
    `FSM_WAIT_TMRD : counter_nxt =  counter - 1 ;
    `FSM_LMR3      : counter_nxt = `CYCLE_TDLLK ;
    `FSM_WAIT_TDLLK: counter_nxt = counter - 1 ;
    default : counter_nxt = counter ;
  endcase	
  
end

// dqs control state defination
always@* begin
  case(d_state)
   `D_IDLE     : if(state == `FSM_READ)
                   d_state_nxt = `D_WAIT_CL_READ ;
                 else if (state == `FSM_WRITE)
                   d_state_nxt = `D_WAIT_CL_WRITE ;
                 else
                   d_state_nxt = `D_IDLE ;
   `D_WAIT_CL_READ  : d_state_nxt = (d0_counter >= `CYCLE_TOTAL_RL-1 ||
                                     d1_counter >= `CYCLE_TOTAL_RL-1 ||
                                     d2_counter >= `CYCLE_TOTAL_RL-1 ||
                                     d3_counter >= `CYCLE_TOTAL_RL-1 ||
                                     d4_counter >= `CYCLE_TOTAL_RL-1  ) ? `D_READ1 : `D_WAIT_CL_READ ; 
   
   `D_WAIT_CL_WRITE : d_state_nxt = (d0_counter >= `CYCLE_TOTAL_WL-1-1 ||
                                     d1_counter >= `CYCLE_TOTAL_WL-1-1 ||
                                     d2_counter >= `CYCLE_TOTAL_WL-1-1 ||
                                     d3_counter >= `CYCLE_TOTAL_WL-1-1 ||
                                     d4_counter >= `CYCLE_TOTAL_WL-1-1  ) ? `D_WRITE1 : `D_WAIT_CL_WRITE ; 
   `D_WRITE1    : d_state_nxt = `D_WRITE2 ;
   `D_WRITE2    : d_state_nxt = (dq_counter[2:0] == process_BL) ? `D_WRITE_F : `D_WRITE2 ;  
   `D_WRITE_F   :if(d_counter_used == 0)
		               if(state==`FSM_WRITE)
                     d_state_nxt = `D_WAIT_CL_WRITE ;
                   else if(state==`FSM_READ) 
                     d_state_nxt = `D_WAIT_CL_READ ;
                   else
		                 d_state_nxt = `D_IDLE ;
		             else
		               if(d0_counter == `CYCLE_TOTAL_WL-1-1 || d1_counter == `CYCLE_TOTAL_WL-1-1 ||
		                  d2_counter == `CYCLE_TOTAL_WL-1-1 || d3_counter == `CYCLE_TOTAL_WL-1-1 ||
		                  d4_counter == `CYCLE_TOTAL_WL-1-1  )
		                  
		                 d_state_nxt = `D_WRITE1 ;
		             
		             
		               else if(d0_counter == `CYCLE_TOTAL_WL-1 || d1_counter == `CYCLE_TOTAL_WL-1 ||
		                       d2_counter == `CYCLE_TOTAL_WL-1 || d3_counter == `CYCLE_TOTAL_WL-1 ||
		                       d4_counter == `CYCLE_TOTAL_WL-1  )
		                  
		                 d_state_nxt = `D_WRITE2 ;
		                 
		               else if(d0_counter == `CYCLE_TOTAL_WL-1+1 || d1_counter == `CYCLE_TOTAL_WL-1+1 ||
		                       d2_counter == `CYCLE_TOTAL_WL-1+1 || d3_counter == `CYCLE_TOTAL_WL-1+1 ||
		                       d4_counter == `CYCLE_TOTAL_WL-1+1  )
		                       
		                 d_state_nxt = `D_WRITE2 ;
		               
		               else
		                       
		                 d_state_nxt = `D_WAIT_CL_WRITE ;
                      
   `D_READ1    : d_state_nxt = `D_READ2 ;
   `D_READ2    : d_state_nxt = (dq_counter[2:0] == process_BL) ? `D_READ_F : `D_READ2 ;
   `D_READ_F   : if(d_counter_used == 0)
		               if(state==`FSM_WRITE)
                     d_state_nxt = `D_WAIT_CL_WRITE ;
                   else if(state==`FSM_READ)
                     d_state_nxt = `D_WAIT_CL_READ ;
                   else
                     d_state_nxt = `D_IDLE ;  
		             else
		               if(out_fifo_out[1] == 0) begin  //write
		               	
				                if(d0_counter == `CYCLE_TOTAL_WL-1-1 || d1_counter == `CYCLE_TOTAL_WL-1-1 ||
				                   d2_counter == `CYCLE_TOTAL_WL-1-1 || d3_counter == `CYCLE_TOTAL_WL-1-1 ||
				                   d4_counter == `CYCLE_TOTAL_WL-1-1  )
				                   
				                  d_state_nxt = `D_WRITE1 ;
				              
				              
				                else if(d0_counter == `CYCLE_TOTAL_WL-1 || d1_counter == `CYCLE_TOTAL_WL-1 ||
				                        d2_counter == `CYCLE_TOTAL_WL-1 || d3_counter == `CYCLE_TOTAL_WL-1 ||
				                        d4_counter == `CYCLE_TOTAL_WL-1  )
				                   
				                  d_state_nxt = `D_WRITE2 ;
				                  
				                else if(d0_counter == `CYCLE_TOTAL_WL-1+1 || d1_counter == `CYCLE_TOTAL_WL-1+1 ||
				                        d2_counter == `CYCLE_TOTAL_WL-1+1 || d3_counter == `CYCLE_TOTAL_WL-1+1 ||
				                        d4_counter == `CYCLE_TOTAL_WL-1+1  )
				                        
				                  d_state_nxt = `D_WRITE2 ;
				                
				                else
				                        
				                  d_state_nxt = `D_WAIT_CL_WRITE ;                   
		               end 
		               
		               else begin//read
		               
				                if(d0_counter == `CYCLE_TOTAL_RL-1+2 || d1_counter == `CYCLE_TOTAL_RL-1+2 ||
				                   d2_counter == `CYCLE_TOTAL_RL-1+2 || d3_counter == `CYCLE_TOTAL_RL-1+2 ||
				                   d4_counter == `CYCLE_TOTAL_RL-1+2  )
				                   
				                  d_state_nxt = `D_READ2 ;
				                  
				                else if(d0_counter == `CYCLE_TOTAL_RL-1+1 || d1_counter == `CYCLE_TOTAL_RL-1+1 ||
				                        d2_counter == `CYCLE_TOTAL_RL-1+1 || d3_counter == `CYCLE_TOTAL_RL-1+1 ||
				                        d4_counter == `CYCLE_TOTAL_RL-1+1  )
				                
				                  d_state_nxt = `D_READ2 ;
				                
				                else if(d0_counter == `CYCLE_TOTAL_RL-1 || d1_counter == `CYCLE_TOTAL_RL-1 ||
				                        d2_counter == `CYCLE_TOTAL_RL-1 || d3_counter == `CYCLE_TOTAL_RL-1 ||
				                        d4_counter == `CYCLE_TOTAL_RL-1  )
				                  
				                  d_state_nxt = `D_READ1 ;
				                  
				                else                      
				                  
				                  d_state_nxt = `D_WAIT_CL_READ ;                    
		                 end //end else cmd_RW_buf[0]

   default     : d_state_nxt = d_state ;
  endcase
end

//dq control state defination
always@* begin
  case(dq_state)
   `DQ_IDLE    : case(d_state)
                   `D_WRITE1 : dq_state_nxt =`DQ_OUT ;
                   `D_WRITE2 : dq_state_nxt =`DQ_OUT ;
                   `D_WRITE_F : if(d0_counter == `CYCLE_TOTAL_WL-1-1 || d1_counter == `CYCLE_TOTAL_WL-1-1 ||
                                   d2_counter == `CYCLE_TOTAL_WL-1-1 || d3_counter == `CYCLE_TOTAL_WL-1-1 ||
                                   d4_counter == `CYCLE_TOTAL_WL-1-1)
                               
                                  dq_state_nxt = `DQ_IDLE ;
                                
                                else if(d0_counter == `CYCLE_TOTAL_WL-1 || d1_counter == `CYCLE_TOTAL_WL-1 ||
                                        d2_counter == `CYCLE_TOTAL_WL-1 || d3_counter == `CYCLE_TOTAL_WL-1 ||
                                        d4_counter == `CYCLE_TOTAL_WL-1) 
                                  
                                  dq_state_nxt = `DQ_OUT ;
                                  
                                else
                                
                                  dq_state_nxt = `DQ_IDLE ;
                   
                   `D_READ1 : dq_state_nxt = `DQ_OUT ;
                   `D_READ2 : dq_state_nxt = `DQ_OUT ;
                   `D_READ_F :if(d_state_nxt==`D_WAIT_CL_WRITE || d_state_nxt==`D_WAIT_CL_READ || d_state_nxt == `D_IDLE)
                                dq_state_nxt = `DQ_IDLE ;
                              else
                              if(out_fifo_out[1]==0)//write
                                dq_state_nxt = `DQ_OUT ;
                              else //continuous read
	                               if(d0_counter == `CYCLE_TOTAL_RL-1+1 || d1_counter == `CYCLE_TOTAL_RL-1+1 ||
	                                  d2_counter == `CYCLE_TOTAL_RL-1+1 || d3_counter == `CYCLE_TOTAL_RL-1+1 ||
	                                  d4_counter == `CYCLE_TOTAL_RL-1+1)
	                               
	                                  dq_state_nxt = `DQ_OUT ;
	                               
	                               else
	                               
	                                  dq_state_nxt = `DQ_IDLE ;
                                  
                   default : dq_state_nxt =`DQ_IDLE ;               
                 endcase
   
   `DQ_OUT     : if(d_state_nxt == `D_WRITE_F)
	                   if(d0_counter == `CYCLE_TOTAL_WL-1-1 || d1_counter == `CYCLE_TOTAL_WL-1-1 ||
	                      d2_counter == `CYCLE_TOTAL_WL-1-1 || d3_counter == `CYCLE_TOTAL_WL-1-1 ||
	                      d4_counter == `CYCLE_TOTAL_WL-1-1)
	
	                     dq_state_nxt = `DQ_IDLE ;
	                   
	                   else if(d0_counter == `CYCLE_TOTAL_WL-1 || d1_counter == `CYCLE_TOTAL_WL-1 ||
	                           d2_counter == `CYCLE_TOTAL_WL-1 || d3_counter == `CYCLE_TOTAL_WL-1 ||
	                           d4_counter == `CYCLE_TOTAL_WL-1) 
	                     
	                     dq_state_nxt = `DQ_OUT ;
	                           
	                   else 
	                     dq_state_nxt = `DQ_IDLE ;
	                     
                 else if(d_state_nxt == `D_READ_F)
                   	 if(d0_counter == `CYCLE_TOTAL_RL-1+1 || d1_counter == `CYCLE_TOTAL_RL-1+1 ||
	                      d2_counter == `CYCLE_TOTAL_RL-1+1 || d3_counter == `CYCLE_TOTAL_RL-1+1 ||
	                      d4_counter == `CYCLE_TOTAL_RL-1+1)
	                      
                       dq_state_nxt = `DQ_OUT ;
                       
                     else
                     
                       dq_state_nxt = `DQ_IDLE ;
                 
                 else
                   dq_state_nxt = `DQ_OUT ;

   default     : dq_state_nxt = dq_state ;
  endcase
end


//DDR3 rst control
always@* begin
  rst_n = (state == `FSM_POWER_UP) ? (counter >= 7) ? 0 : 1 : 1 ;
end


always@* begin
	WD = wdata_fifo_out[128:1] ;
  case(dq_counter)
    0 : data_out_t <= WD[`DQ_BITS-1:0] ;
    1 : data_out_t <= WD[`DQ_BITS*2-1:`DQ_BITS] ;
    2 : data_out_t <= WD[`DQ_BITS*3-1:`DQ_BITS*2] ;
    3 : data_out_t <= WD[`DQ_BITS*4-1:`DQ_BITS*3] ;
    4 : data_out_t <= WD[`DQ_BITS*5-1:`DQ_BITS*4] ;
    5 : data_out_t <= WD[`DQ_BITS*6-1:`DQ_BITS*5] ;
    6 : data_out_t <= WD[`DQ_BITS*7-1:`DQ_BITS*6] ;
    7 : data_out_t <= WD[`DQ_BITS*8-1:`DQ_BITS*7] ;
    default    : data_out_t <= 16'bz ;
  endcase
   
end

always@* begin	
	if(dq_state == `DQ_OUT)
    if(W_BL==0)//Burst Length = 4
      data_all_out_nxt = (dq_counter <= 3) ? WD : 128'bz ;
    else//Burst_Length = 8
      data_all_out_nxt = (dq_counter <= 7) ? WD : 128'bz ;
  else
    data_all_out_nxt = 128'bz ;

end


always@* begin	
	if(dq_state == `DQ_OUT)
    if(W_BL==0)//Burst Length = 4
      data_out_nxt = (dq_counter <= 3) ? data_out_t : 16'bz ;
    else//Burst_Length = 8
      data_out_nxt = (dq_counter <= 7) ? data_out_t : 16'bz ;
  else
    data_out_nxt = 16'bz ;

end


always@* begin

d_counter_used_end[0] = (d_counter_used[0]) ? (d0_counter > d1_counter && 
                                               d0_counter > d2_counter && 
                                               d0_counter > d3_counter &&
                                               d0_counter > d4_counter    ) ? 0 : 1 : 0 ;

d_counter_used_end[1] = (d_counter_used[1]) ? (d1_counter > d0_counter && 
                                               d1_counter > d2_counter && 
                                               d1_counter > d3_counter &&
                                               d1_counter > d4_counter   ) ? 0 : 1 : 0 ;
                                            
d_counter_used_end[2] = (d_counter_used[2]) ? (d2_counter > d0_counter && 
                                               d2_counter > d1_counter && 
                                               d2_counter > d3_counter &&
                                               d2_counter > d4_counter   ) ? 0 : 1 : 0 ;
                                             
d_counter_used_end[3] = (d_counter_used[3]) ? (d3_counter > d0_counter && 
                                               d3_counter > d1_counter && 
                                               d3_counter > d2_counter &&
                                               d3_counter > d4_counter   ) ? 0 : 1 : 0 ;		                                              		                                              

d_counter_used_end[4] = (d_counter_used[4]) ? (d4_counter > d0_counter && 
                                               d4_counter > d1_counter && 
                                               d4_counter > d2_counter &&
                                               d4_counter > d3_counter   ) ? 0 : 1 : 0 ;	


case(d_counter_used)
  5'b00000:d_counter_used_start = 5'b00001 ;
  5'b00001:d_counter_used_start = 5'b00011 ;
  5'b00010:d_counter_used_start = 5'b00011 ;
  5'b00011:d_counter_used_start = 5'b00111 ;
  5'b00100:d_counter_used_start = 5'b00101 ;
  5'b00101:d_counter_used_start = 5'b00111 ;
  5'b00110:d_counter_used_start = 5'b00111 ;
  5'b00111:d_counter_used_start = 5'b01111 ;
  5'b01000:d_counter_used_start = 5'b01001 ;
  5'b01001:d_counter_used_start = 5'b01011 ;
  5'b01010:d_counter_used_start = 5'b01011 ;
  5'b01011:d_counter_used_start = 5'b01111 ;
  5'b01100:d_counter_used_start = 5'b01101 ;
  5'b01101:d_counter_used_start = 5'b01111 ;
  5'b01110:d_counter_used_start = 5'b01111 ;
  5'b01111:d_counter_used_start = 5'b11111 ;
  5'b10000:d_counter_used_start = 5'b10001 ;
  5'b10001:d_counter_used_start = 5'b10011 ;
  5'b10010:d_counter_used_start = 5'b10011 ;
  5'b10011:d_counter_used_start = 5'b10111 ;
  5'b10100:d_counter_used_start = 5'b10101 ;
  5'b10101:d_counter_used_start = 5'b10111 ;
  5'b10110:d_counter_used_start = 5'b10111 ;
  5'b10111:d_counter_used_start = 5'b11111 ;
  5'b11000:d_counter_used_start = 5'b11001 ;
  5'b11001:d_counter_used_start = 5'b11011 ;
  5'b11010:d_counter_used_start = 5'b11011 ;
  5'b11011:d_counter_used_start = 5'b11111 ;
  5'b11100:d_counter_used_start = 5'b11101 ;
  5'b11101:d_counter_used_start = 5'b11111 ;
  5'b11110:d_counter_used_start = 5'b11111 ;
  default :d_counter_used_start = 5'b00000 ;
endcase




if( (d_state == `D_WRITE2 && d_state_nxt == `D_WRITE_F) ||
    (d_state == `D_READ2  && d_state_nxt == `D_READ_F)   ) begin

  if(state == `FSM_READ || state == `FSM_WRITE) begin
    d_counter_used_nxt[0] = (d_counter_used[0]==0 && d_counter_used_start[0]==1) ? d_counter_used_start[0] : d_counter_used_end[0] ;
    d_counter_used_nxt[1] = (d_counter_used[1]==0 && d_counter_used_start[1]==1) ? d_counter_used_start[1] : d_counter_used_end[1] ;
    d_counter_used_nxt[2] = (d_counter_used[2]==0 && d_counter_used_start[2]==1) ? d_counter_used_start[2] : d_counter_used_end[2] ;
    d_counter_used_nxt[3] = (d_counter_used[3]==0 && d_counter_used_start[3]==1) ? d_counter_used_start[3] : d_counter_used_end[3] ;
    d_counter_used_nxt[4] = (d_counter_used[4]==0 && d_counter_used_start[4]==1) ? d_counter_used_start[4] : d_counter_used_end[4] ;
  end
  else
    d_counter_used_nxt = d_counter_used_end ;   
end   
else begin        	
	if(state == `FSM_READ || state == `FSM_WRITE)
    d_counter_used_nxt = d_counter_used_start ;
	else
	  d_counter_used_nxt = d_counter_used ; 
end

end

//dqs control state counter
always@* begin
 d0_counter_nxt = ( d_counter_used_nxt[0] ) ? d0_counter + 1 : 0 ;
 d1_counter_nxt = ( d_counter_used_nxt[1] ) ? d1_counter + 1 : 0 ;
 d2_counter_nxt = ( d_counter_used_nxt[2] ) ? d2_counter + 1 : 0 ;
 d3_counter_nxt = ( d_counter_used_nxt[3] ) ? d3_counter + 1 : 0 ;
 d4_counter_nxt = ( d_counter_used_nxt[4] ) ? d4_counter + 1 : 0 ;  
end


//dqs output counter
always@* begin
	W_BL = out_fifo_out[0] ;
  case(d_state)
    `D_WRITE1   : o_counter_nxt = ( W_BL ) ? 3 : 1 ; //W_BL=0 : BC4 ; W_BL=1 : BL8 . 4/2 - 1 = 1 (Half cycle)
    `D_WRITE2   : o_counter_nxt = o_counter - 1 ;
    default     : o_counter_nxt = 0 ;
  endcase
end

//dq out counter
always@* begin
	if(power_on_rst_n == 0)
	  dq_counter_nxt = 0 ;
	else
	  case(dq_state)
	    `DQ_OUT     : dq_counter_nxt = (dq_counter == process_BL) ? 0 : dq_counter + 1 ;
	    default     : dq_counter_nxt = 0 ;
	  endcase
end
//=======================================

always@* begin
//read_data <= {RD_buf[7],RD_buf[6],RD_buf[5],RD_buf[4],
//              RD_buf[3],RD_buf[2],RD_buf[1],RD_buf[0]} ;

read_data <= RD_buf_all;

end

endmodule