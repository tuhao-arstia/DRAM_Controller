////////////////////////////////////////////////////////////////////////
// Project Name: eHome-IV
// Task Name   : Bank Finite State Machine
// Module Name : bank_FSM
// File Name   : bank_FSM.v
// Description : bank state control
// Author      : Chih-Yuan Chang
// Revision History:
// Date        : 2012.12.11
////////////////////////////////////////////////////////////////////////
`include "Usertype.sv"
`include "define.sv"
module bank_FSM(state         ,
                stall         ,
                valid         ,
                command       ,
                number        ,
                rst_n         ,
                clk           ,
                ba_state      ,
                ba_busy       ,
                ba_addr       ,
                ba_issue      ,
                process_cmd   ,
                bank_refresh_completed,
                cmd_received_f,
                wdata_fifo_full_flag
                );

input stall ; // Stall signal comes from the cmd_scheduler
input valid ;
input [`MEM_CTR_COMMAND_BITS-1:0]command;

input [2:0]number ;
input rst_n ;
input clk ;
input wdata_fifo_full_flag ;

input  [`FSM_WIDTH1-1:0] state ;
output [`FSM_WIDTH2-1:0] ba_state ;
output ba_busy ;
output [`ADDR_BITS-1:0] ba_addr;
output ba_issue ;
output [2:0]process_cmd ;
output bank_refresh_completed ;
output cmd_received_f ;

import usertype::*;

reg [4:0]ba_counter_nxt,ba_counter ;
bank_state_t ba_state,ba_state_nxt;

reg ba_busy ;
reg [`ADDR_BITS-1:0] ba_addr;
reg ba_issue ;
reg [`ADDR_BITS-1:0] active_row_addr;
reg [`ADDR_BITS-1:0] col_addr_buf;
reg [`ADDR_BITS-1:0] row_addr_buf;


command_t command_buf;
command_t command_in;

always_comb begin :INPUT_CMD
  command_in = command;
end

// Using new command_in format
wire [`ADDR_BITS-1:0]row_addr = command_in.row_addr;
wire [`ADDR_BITS-1:0]col_addr = command_in.col_addr;
wire [`BA_BITS-1:0]bank = command_in.bank_addr ;
reg [`ADDR_BITS-1:0]col_addr_t ;
process_cmd_t process_cmd ;

logic[`ROW_BITS-1:0] tREF_period_counter;

logic[`ROW_BITS-1:0] tREFI_counter;

wire refresh_flag = tREF_period_counter == $unsigned(`CYCLE_REFRESH_PERIOD - 1);
wire refresh_finished_f = tREFI_counter == 0;

logic refresh_bit_f;

reg[4:0]counter;

reg rw ;

wire receive_command_handshake_f = valid == 1'b1 && ba_busy == 1'b0;

assign cmd_received_f = receive_command_handshake_f;

always@(posedge clk) begin
if(rst_n==0)
  ba_state <= B_INITIAL ;
else
  ba_state <= ba_state_nxt ;
end

// The active row address is strange, modify it
always@(posedge clk) begin
if(ba_state_nxt == B_ACTIVE || ba_state == B_ACTIVE)
  active_row_addr <= command_buf.row_addr ; //row_addr
else
  active_row_addr <= active_row_addr ;
end

always@(posedge clk) begin
if(receive_command_handshake_f)
  command_buf <= command_in ;
else
  command_buf <= command_buf ;
end

always@(posedge clk) begin
if(rst_n==0)
  process_cmd <= PROC_NO ;
else
	if(receive_command_handshake_f)
	  process_cmd <= (command_buf.r_w == READ)? PROC_READ : PROC_WRITE ;
	else
	  if(ba_state == B_ACT_STANDBY)
	    process_cmd <= PROC_NO ;
	  else
	    process_cmd <= process_cmd ;
end


always_comb begin
case(ba_state)
  B_ACTIVE :  ba_addr  = command_buf.row_addr ; //row
  B_READ   :  ba_addr  = command_buf.col_addr ;  //col
  B_WRITE  :  ba_addr  = command_buf.col_addr ;  //col
  B_PRE    :  ba_addr  = 0 ;
  default   : ba_addr  = 0 ;
endcase
end


always@* begin
  rw = command_buf.r_w;
end

always@* begin
if(refresh_flag||refresh_bit_f)
  ba_busy = 1'b1 ;
else if(wdata_fifo_full_flag)
begin
  ba_busy = 1'b1 ;
end
else
begin
  case(ba_state)
    B_IDLE        : ba_busy = 0 ;
    B_ACT_STANDBY : ba_busy = 0 ;
    default        : ba_busy = 1 ;
  endcase
end
end
// Add the flag to determine if the row is active
logic row_is_active_ff;
wire refresh_issued_f = state == FSM_REFRESH;
wire row_buffer_hits_f = active_row_addr == row_addr && ba_state == B_ACT_STANDBY;
wire row_buffer_conflict_f = active_row_addr != row_addr && ba_state == B_ACT_STANDBY;

logic row_buffer_conflict_flag_ff;

always_ff @( posedge clk or negedge rst_n )
begin
  if ( ~rst_n )
    row_buffer_conflict_flag_ff <= 0;
  else if(ba_state == B_ACT_STANDBY)
    row_buffer_conflict_flag_ff <= row_buffer_conflict_f;
  else if(ba_state == B_PRE || ba_state == B_PRE_CHECK)
    row_buffer_conflict_flag_ff <= row_buffer_conflict_flag_ff;
  else
    row_buffer_conflict_flag_ff <= 0;
end

always@*
begin
  case(ba_state)
   B_INITIAL    : ba_state_nxt = (state == FSM_IDLE) ? B_IDLE : B_INITIAL ;
   B_IDLE       :
                  if(refresh_flag||refresh_bit_f)
                    ba_state_nxt = B_REFRESH_CHECK ; // During the IDLE state, simply enter the REFRESH CHECK state
                  else if(receive_command_handshake_f)
                     ba_state_nxt = B_ACTIVE ;
                   else
                     ba_state_nxt = ba_state ;

   B_ACTIVE   :
                  if(rw==1)
                    ba_state_nxt = B_READ ;
                  else
                    ba_state_nxt = B_WRITE ;

   B_ACT_STANDBY : // Can only receive command in standby mode
                    if(refresh_flag||refresh_bit_f) //Needs to first precharge before refresh
                      ba_state_nxt = B_PRE;
                    else if(receive_command_handshake_f)
                         if(row_buffer_hits_f)// Row buffer hits
		                       ba_state_nxt = (command_buf.r_w == READ) ? B_READ : B_WRITE ;
		                     else // Row buffer conflicts, close the row buffer
		                       ba_state_nxt = B_PRE ;
		                   else
		                     ba_state_nxt = ba_state ;

   // When auto-precharge in on, the bank will go to idle state after read/write
   B_READ,
   B_WRITE     : if(command_buf.auto_precharge==1'b1)//auto-precharge on !
                   // Auto-precharge means we simply issue a WRA, or RDA command instead of precharge, but first issue the precharge to ensure the correct execution
                   ba_state_nxt = B_PRE ;
                 else // Open row policy
                   ba_state_nxt = B_ACT_STANDBY ;

   B_PRE      :
              if(refresh_bit_f)
                ba_state_nxt = B_REFRESH_CHECK;
                //auto-precharge is on !, Since due to row buffer conflict, we need to precharge and goes to the B_ACT_CHECK state instead of the IDLE state
              else if(command_buf.auto_precharge==1'b1 && row_buffer_conflict_flag_ff == 1'b0)
                  ba_state_nxt = B_IDLE ;
              else
                ba_state_nxt = B_ACTIVE ;
   // Additional refresh control
   B_WAIT_ISSUE_REFRESH :    ba_state_nxt = refresh_issued_f ? B_REFRESHING : B_WAIT_ISSUE_REFRESH;
   B_REFRESH_CHECK : ba_state_nxt =  B_ISSUE_REFRESH;
   B_ISSUE_REFRESH:  ba_state_nxt = B_WAIT_ISSUE_REFRESH;
   B_REFRESHING : ba_state_nxt = refresh_finished_f ? B_IDLE :B_REFRESHING; // Refresh is completed
   default : ba_state_nxt = ba_state ;
  endcase
end

assign bank_refresh_completed = refresh_finished_f && B_REFRESHING;

always@* begin
if(ba_state == B_ACTIVE || ba_state == B_READ || ba_state == B_WRITE || ba_state == B_PRE || ba_state == B_ISSUE_REFRESH)
  ba_issue = 1 ;
else
  ba_issue = 0 ;
end

// REFRESH Control
always@(posedge clk)
begin:REFI_CNT
if(rst_n == 0)
  tREFI_counter <=$unsigned(`CYCLE_TO_REFRESH-1) ;
else
  case(ba_state)
    B_REFRESHING: tREFI_counter <= $unsigned(tREFI_counter - 1);
    default  : tREFI_counter <= $unsigned(`CYCLE_TO_REFRESH-1);
  endcase
end



always_ff @( posedge clk )
begin: TREF_PERIOD_CNT
  // Issues a refresh every 3900 cycles
  if ( rst_n == 0 )
    tREF_period_counter <= 0 ;
  else
    tREF_period_counter <= refresh_flag ? 0 : tREF_period_counter + 1 ;
end

always_ff @( posedge clk )
begin: REFRESH_BIT
  // Refresh bit is toggled every 3900 cycles
  if ( rst_n == 0 )
    refresh_bit_f <= 0 ;
  else if(refresh_finished_f)
    refresh_bit_f <= 0 ;
  else
    refresh_bit_f <= refresh_flag ? 1'b1 : refresh_bit_f ;
end


endmodule