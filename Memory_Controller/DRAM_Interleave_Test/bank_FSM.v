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
                process_cmd    
                );
                
input stall ;
input valid ;
input [31:0]command ;

input [2:0]number ;
input rst_n ;
input clk ;

input  [`FSM_WIDTH1-1:0] state ;
output [`FSM_WIDTH2-1:0] ba_state ;
output ba_busy ;                          
output [`ADDR_BITS-1:0] ba_addr;  
output ba_issue ;
output [2:0]process_cmd ;

reg [4:0]ba_counter_nxt,ba_counter ;
reg [`FSM_WIDTH2-1:0] ba_state,ba_state_nxt;

reg ba_busy ;                          
reg [`ADDR_BITS-1:0] ba_addr;  
reg [3:0]ba_command ;
reg ba_issue ;
reg [`ADDR_BITS-1:0] active_row;  
reg [`ADDR_BITS-1:0] col_addr_buf;
reg [`ADDR_BITS-1:0] row_addr_buf;
reg [31:0]command_buf ;


wire [`ADDR_BITS-1:0]row_addr = command[30:17] ;
wire [`ADDR_BITS-1:0]col_addr = command[16:3] ;
wire [`BA_BITS-1:0]bank = command[2:0] ;
reg [`ADDR_BITS-1:0]col_addr_t ;
reg [2:0]process_cmd ;

//command format = {read/write , row_addr , col_addr , bank } ;
//                  [31]         [30:17]    [16:3]     [2:0]


//counters

reg[4:0]counter;

reg rw ;

always@(posedge clk) begin
if(rst_n==0)
  ba_state <= `B_INITIAL ;
else
  ba_state <= ba_state_nxt ;
end


always@(posedge clk) begin
if(ba_state_nxt == `B_ACTIVE)
  active_row <= command_buf[30:17] ; //row_addr
else
  active_row <= active_row ;
end

always@(posedge clk) begin
if(valid==1 && bank==number)	
  command_buf <= command ;
else
  command_buf <= command_buf ;
end

always@(posedge clk) begin
if(rst_n==0)
  process_cmd <= `PROC_NO ;	
else	
	if(valid==1 && bank==number)
	  process_cmd <= (command[31])? `PROC_READ : `PROC_WRITE ;
	else
	  if(ba_state == `B_ACT_STANDBY)
	    process_cmd <= `PROC_NO ;
	  else
	    process_cmd <= process_cmd ; 
end


always@* begin
case(ba_state)
  `B_ACTIVE : ba_addr <= command_buf[30:17] ; //row
  `B_READ   : ba_addr <= command_buf[16:3] ;  //col
  `B_WRITE  : ba_addr <= command_buf[16:3] ;  //col
  `B_PRE    : ba_addr <= 0 ;
  default   : ba_addr <= 0 ;
endcase
end



always@* begin
  rw = command_buf[31] ;
end

always@* begin
case(ba_state)
  `B_IDLE        : ba_busy = 0 ;
  `B_ACT_STANDBY : ba_busy = 0 ;
  default        : ba_busy = 1 ;
endcase
end

always@* begin
  case(ba_state)
   `B_INITIAL    : ba_state_nxt = (state == `FSM_IDLE) ? `B_IDLE : `B_INITIAL ;
   `B_IDLE       : if(valid==1 && bank==number)
                     ba_state_nxt = `B_ACT_CHECK ;
                   else
                     ba_state_nxt = ba_state ;
                     
   `B_ACT_CHECK:  ba_state_nxt = (stall)? `B_ACT_CHECK : `B_ACTIVE ;
                    
   `B_ACTIVE   :  if(rw==1)
                    ba_state_nxt = `B_READ_CHECK ;
                  else
                    ba_state_nxt = `B_WRITE_CHECK ;
                    
   `B_WRITE_CHECK : ba_state_nxt = (stall)? `B_WRITE_CHECK : `B_WRITE ;                  
   `B_READ_CHECK  : ba_state_nxt = (stall)? `B_READ_CHECK : `B_READ ;
   `B_PRE_CHECK   : ba_state_nxt = (stall)? `B_PRE_CHECK  : `B_PRE ;      
   `B_ACT_STANDBY :    if(valid==1 && bank==number)
                         if(row_addr == active_row)
		                       ba_state_nxt = (command[31]) ? `B_READ_CHECK : `B_WRITE_CHECK ;
		                     else
		                       ba_state_nxt = `B_PRE_CHECK ;
		                   else
		                     ba_state_nxt = ba_state ;
		                      
		                    
   `B_READ,
   `B_WRITE     : if(command_buf[13]==1)//auto-precharge on !
                   ba_state_nxt = `B_IDLE ;
                 else  
                   ba_state_nxt = `B_ACT_STANDBY ;
   
   `B_PRE      : ba_state_nxt = `B_ACT_CHECK ;
   default : ba_state_nxt = ba_state ;
  endcase
end

always@* begin
if(ba_state == `B_ACTIVE || ba_state == `B_READ || ba_state == `B_WRITE || ba_state == `B_PRE)
  ba_issue = 1 ;
else
  ba_issue = 0 ;
end

endmodule
