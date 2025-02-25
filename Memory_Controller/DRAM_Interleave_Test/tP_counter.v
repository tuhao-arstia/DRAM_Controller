////////////////////////////////////////////////////////////////////////
// Project Name: eHome-IV
// Task Name   : multiple purpose timing counter
// Module Name : tP_counter
// File Name   : tP_counter.v
// Description : Recode the command latency. 
//               The purpose is prevent some timing violateions. 
// Author      : Chih-Yuan Chang
// Revision History:
// Date        : 2012.12.11
////////////////////////////////////////////////////////////////////////

module tP_counter(rst_n,
                  clk,
                  f_bank,
                  BL,
                  state_nxt,
                  number,
                  auto_pre,
                  
                  tP_ba_counter,
                  tRAS_counter,
				  tREF_counter,
                  recode
                  ) ;

input rst_n;
input clk;
input [2:0]number ;
input [`BA_BITS-1:0]f_bank;
input [1:0]BL;
input [`FSM_WIDTH1-1:0]state_nxt;
input auto_pre;

output [4:0]tP_ba_counter ;
output [5:0]tRAS_counter;
output [5:0]tREF_counter;
output [2:0]recode;

reg [10:0] tREF_counter;
reg [4:0]tP_ba_counter ;
reg [5:0]tRAS_counter; //purpose : prevent tRC and tRAS violation
reg [2:0]recode;//1 : recode write-to-precharge ;   prevent tWR  violation 
                //2 : recode precharge-to-active ;  prevent tRP  violation
                //3 : recode active-to-read/write ; prevent tRCD violation
                //4 : recode read-to-precharge ;    prevent tRTP violation
                //5 : recode write-to-active with auto-precharge
                //6 : recode read-to-active with auto-precharge 
always@(posedge clk) begin
if(rst_n == 0)
  tP_ba_counter <= 0 ;
else
  case(state_nxt)
    `FSM_ACTIVE : tP_ba_counter <= (f_bank==number) ? `CYCLE_TRCD-1 : (tP_ba_counter==0) ? 0 : tP_ba_counter - 1 ;
	              // tRCD  Active to Read/Write command time
    `FSM_READ : if(f_bank==number)
                  if(auto_pre)//with auto-precharge
                    tP_ba_counter <= `CYCLE_TRTP+`CYCLE_TRP-1; 
                  else //normal
                    tP_ba_counter <= `CYCLE_TRTP-1 ; //tRTP = Read to precharge command delay
                else
                  if(tP_ba_counter==0)
                    tP_ba_counter <= 0 ;
                  else
                    tP_ba_counter <= tP_ba_counter - 1 ;

    `FSM_WRITE: if(f_bank==number)
                  if(auto_pre)//with auto-precharge
                    if(BL==2'b01 || BL==2'b00) //Burst length is on-the-fly or fixed 8
                      tP_ba_counter <= `CYCLE_TOTAL_WL+4+`CYCLE_TWR+`CYCLE_TRP-1 ;
                    else //Burst length is fixed 4
                      tP_ba_counter <= `CYCLE_TOTAL_WL+2+`CYCLE_TWR+`CYCLE_TRP-1 ;
                  else //normal
                    if(BL==2'b01 || BL==2'b00) //Burst length is on-the-fly or fixed 8
                      tP_ba_counter <= `CYCLE_TOTAL_WL+4+`CYCLE_TWR-1 ;
                    else //Burst length is fixed 4
                      tP_ba_counter <= `CYCLE_TOTAL_WL+2+`CYCLE_TWR-1 ;
                else
                  if(tP_ba_counter==0)
                    tP_ba_counter <= 0 ;
                  else
                    tP_ba_counter <= tP_ba_counter - 1 ;
    	 
    `FSM_PRE  : tP_ba_counter <= (f_bank==number) ? `CYCLE_TRP-1 : (tP_ba_counter == 0) ? 0 : tP_ba_counter - 1 ;
    default   : tP_ba_counter <= (tP_ba_counter == 0) ? 0 : tP_ba_counter - 1 ;
  endcase
end

always@(posedge clk) begin
if(rst_n == 0)
  tREF_counter <= 0 ;
else
  case(state_nxt)
    `FSM_REF : tREF_counter <= (f_bank==number) ? `CYCLE_TRAS-1 : (tREF_counter==0) ? 0 : tREF_counter - 1 ;
    default  : tREF_counter <= (tREF_counter == 0) ? 0 : tREF_counter - 1 ;
  endcase
end

always@(posedge clk) begin
if(rst_n == 0)
  tRAS_counter <= 0 ;
else
  case(state_nxt)
    `FSM_ACTIVE : tRAS_counter <= (f_bank==number) ? `CYCLE_TRAS-1 : (tRAS_counter==0) ? 0 : tRAS_counter - 1 ;
    default     : tRAS_counter <= (tRAS_counter == 0) ? 0 : tRAS_counter - 1 ;
  endcase
end

always@(posedge clk) begin
if(rst_n==0)
  recode <= 0 ;
else
  case(state_nxt)
    `FSM_WRITE: recode <= (f_bank==number)?(auto_pre)? 5 : 1 : recode ;
    `FSM_PRE  : recode <= (f_bank==number)? 2 : recode ;
    `FSM_ACTIVE:recode <= (f_bank==number)? 3 : recode ;
    `FSM_READ : recode <= (f_bank==number)?(auto_pre)? 6 : 4 : recode ;
    default   : recode <= recode ;
  endcase
end

endmodule
