////////////////////////////////////////////////////////////////////////
// Project Name: eHome-IV
// Task Name   : Command Scheduler
// Module Name : cmd_scheduler
// File Name   : cmd_scheduler.v
// Description : schedule issue commands
// Author      : Chih-Yuan Chang
// Revision History:
// Date        : 2012.12.12
////////////////////////////////////////////////////////////////////////

`define B_COUNTER_WIDTH 8
`include "Usertype.sv"
`include "define.sv"

module cmd_scheduler(
                         clk,
                         rst_n,
                         isu_fifo_full,
                         ba0_info,
                         ba0_stall,
                         sch_out, // The command, adddr, bank
                         sch_issue
                         );

import usertype::*;

input clk;
input rst_n;
input isu_fifo_full;
input [`BA_INFO_WIDTH-1:0]ba0_info;

output ba0_stall;

output [`ISU_FIFO_WIDTH-1:0]sch_out ;
output sch_issue ;


reg ba0_stall;


sch_cmd_t sch_command ;
reg [`ADDR_BITS-1:0]sch_addr;
reg [`BA_BITS-1:0]sch_bank;

reg sch_issue ;

reg [2:0]act_count ;
reg [2:0]write_count ;
reg [2:0]read_count ;
reg [2:0]pre_count ;

bank_state_t bax_state;
bank_state_t f_ba_state;

bank_state_t ba0_state ;

bank_info_t ba0_info_in;

always_comb begin :BANKS_INFO_IN
  ba0_info_in = ba0_info;
end

always_comb begin :BANKS_STATE
  ba0_state = ba0_info_in.bank_state;
end

process_cmd_t ba0_proc;

always_comb begin : BANKS_PROC
  ba0_proc = ba0_info_in.proc_cmd;
end


reg act_pri;
reg read_pri;
reg write_pri;
reg pre_pri;
r_w_t current_rw ;

wire [`B_COUNTER_WIDTH-1:0]b0_counter;


reg [`B_COUNTER_WIDTH-1:0] b0_c_counter;


wire pre0_threshold = (b0_c_counter > 16) ? 1 : 0 ;

bx_counter     b0(.ba_state  (ba0_state),
                  .clk       (clk),
                  .rst_n     (rst_n),
                  .b_counter (b0_counter) );


// According to the states of each banks
// To check if there is a commands needed for issue in each bank, if there is a command, the signal will be high
wire have_cmd_act ;
wire have_cmd_read ;
wire have_cmd_write ;
wire have_cmd_pre ;

check_or_state    check_cmd_act(ba0_state,`B_ACTIVE,have_cmd_act);
check_or_state    check_cmd_write(ba0_state,`B_WRITE,have_cmd_write);
check_or_state    check_cmd_read(ba0_state,`B_READ,have_cmd_read);
check_or_state    check_cmd_pre(ba0_state,`B_PRE,have_cmd_pre);

// act count counts to 4
always@(posedge clk)
begin
if(rst_n==0)
  act_count <= 0 ;
else
  if(have_cmd_act)
     act_count <= (act_count==4)? 1 : act_count + 1 ;
  else
     act_count <= act_count ;
end

always@(posedge clk) begin
if(rst_n==0)
  read_count <= 0 ;
else
  if(have_cmd_read)
     read_count <= (read_count==4)? 1 : read_count + 1 ;
  else if(have_cmd_write)
     read_count <= 0 ;
  else
     read_count <=  read_count ;
end

always@(posedge clk) begin // Counts to 4
if(rst_n==0)
  write_count <= 0 ;
else
  if(have_cmd_write)
     write_count <= (write_count==4)? 1 : write_count + 1 ;
  else if(have_cmd_read)
     write_count <= 0 ;
  else
     write_count <= write_count ;
end

always@(posedge clk) begin // Counts to 3
if(rst_n==0)
    pre_count <= 0 ;
else
  if(have_cmd_pre)
     pre_count <= (pre_count==3)? 1 : pre_count + 1 ;
  else
     pre_count <= pre_count ;
end


always@* begin: SCH_ADDR_ISSUE_BLOCK
if(ba0_state == B_ACTIVE || ba0_state == B_READ || ba0_state == B_WRITE || ba0_state == B_PRE || ba0_state == B_REFRESH_CHECK)
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba0_info_in.bank_state,ba0_info_in.addr,3'd0,1'b1} ;
else
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba0_info_in.bank_state,ba0_info_in.addr,3'd0,1'b0} ;
end

always@* begin
if(write_count != 0 && read_count == 0)
  current_rw = WRITE ; //continuous write
else if(write_count == 0 && read_count != 0)
  current_rw = READ ; //continuous read
else
  current_rw = WRITE ;
end

always@* begin: SCH_BA_CMD_DECODER
case(f_ba_state)
  B_ACTIVE : sch_command <= ATCMD_ACTIVE ;
  B_READ   : sch_command <= ATCMD_READ ;
  B_WRITE  : sch_command <= ATCMD_WRITE ;
  B_PRE    : sch_command <= ATCMD_PRECHARGE ;
  // Add auto-precharge commands
  B_READA  : sch_command <= ATCMD_RDA ;
  B_WRITEA : sch_command <= ATCMD_WRA ;
  B_REFRESH_CHECK: sch_command <= ATCMD_REFRESH ;
  default   : sch_command <= ATCMD_NOP ;
endcase
end

assign sch_out = {sch_command,sch_addr,sch_bank} ; // 3 + ADDR_BITS + 3

wire have_act_c,have_write_c,have_read_c,have_pre_c ;
wire have_act_a,have_write_a,have_read_a,have_pre_a ;
wire b0_big_st;

// Why there are two sets of check_or_state???
check_or_state    check_act_c(ba0_state,`B_ACT_CHECK,have_act_c);
check_or_state    check_write_c(ba0_state,`B_WRITE_CHECK,have_write_c);
check_or_state    check_read_c(ba0_state,`B_READ_CHECK,have_read_c);
check_or_state    check_pre_c(ba0_state,`B_PRE_CHECK,have_pre_c);

check_or_state    check_act_a(ba0_state,`B_ACTIVE,have_act_a);
check_or_state    check_write_a(ba0_state,`B_WRITE,have_write_a);
check_or_state    check_read_a(ba0_state,`B_READ,have_read_a);
check_or_state    check_pre_a(ba0_state,`B_PRE,have_pre_a);

// Priority encoder, banks are competing for the same resource
always@*
begin: GRANTED_BANK_DECODER
  bax_state = ba0_state ;
end

wire have_act = have_act_c || have_act_a ;
wire have_write = have_write_c || have_write_a ;
wire have_read = have_read_c || have_read_a ;
wire have_pre = have_pre_c || have_pre_a ;

// This determines which dram bank cmds to schedule, due to the fact that a sequences of
// cmds must be scheduled in a certain order, the priority of the cmds must be determined
always@* begin: CMD_AUTHORIZE_BLOCK
case( {have_act,have_write,have_read,have_pre} )
  4'b0000 :{act_pri,write_pri,read_pri,pre_pri} = 0 ;
  4'b0001 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
  4'b0010 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;

  4'b0011 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;

  4'b0100 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
  4'b0101 :if(bax_state == B_PRE_CHECK || bax_state == B_PRE)
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
           else
	           if(pre0_threshold)

	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;

	           else

	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;

  4'b1000 :{act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  4'b1001 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;

  4'b0110 :if(write_count!=0 && read_count==0)     //continuous write
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
           else if(write_count==0 && read_count!=0)//continuous read
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
           else
             if(bax_state==B_WRITE_CHECK || bax_state == B_WRITE)
               {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
             else
               {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;

  4'b0111 :if(bax_state == B_PRE_CHECK || bax_state == B_PRE)
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
           else
	           if(current_rw==1)//continuous
	              {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
	           else
	              {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;

  4'b1110 :begin
  	         if(bax_state == B_ACT_CHECK || bax_state == B_ACTIVE)
  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  	         else
	             if(current_rw==1)  //continuous read
			  	         if(act_count==0 || act_count==1 || act_count==2)
			  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
			  	         else if(act_count == 3)
			  	           if(read_count==0 || read_count==4)
			  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
			  	           else
			  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
			  	         else if(act_count == 4)
			  	           if(read_count==1 || read_count==2 || read_count==3)
			  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
			  	           else
			  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
			  	         else
			  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	             else if(current_rw==0)  //continuous write
	                 if(act_count==0 || act_count==1 || act_count==2)
	  	               {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	             else if(act_count == 3)
	  	               if(write_count==0 || write_count==4)
	  	                 {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
	  	               else
	  	                 {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	             else if(act_count == 4)
	  	               if(write_count==1 || write_count==2 || write_count==3)
	  	                 {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
	  	               else
	  	                 {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	             else
	  	               {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	             else
	               {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
           end
  4'b1010 :begin
  	  	     if(bax_state == B_ACT_CHECK || bax_state == B_ACTIVE)
  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  	         else
	  	         if(act_count==0 || act_count==1 || act_count==2)
	  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	         else if(act_count == 3)
	  	           if(read_count==0 || read_count==4)
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
	  	           else
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	         else if(act_count == 4)
	  	           if(read_count==1 || read_count==2 || read_count==3)
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
	  	           else
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	         else
	  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  	       end
  4'b1100 :begin
  	         if(bax_state == B_ACT_CHECK || bax_state == B_ACTIVE)
  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  	         else
	  	         if(act_count==0 || act_count==1 || act_count==2)
	  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	         else if(act_count == 3)
	  	           if(write_count==0 || write_count==4)
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
	  	           else
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	         else if(act_count == 4)
	  	           if(write_count==1 || write_count==2 || write_count==3)
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
	  	           else
	  	             {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
	  	         else
	  	           {act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  	       end
  4'b1011 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
  4'b1101 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;

  4'b1111 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;

  default : {act_pri,write_pri,read_pri,pre_pri} = 4'b0000 ;
endcase

end

// wire b0_big,b1_big,b2_big,b3_big;

always@* begin
if(act_pri==1) begin
  b0_c_counter = (ba0_state==B_ACT_CHECK || ba0_state==B_ACTIVE) ? b0_counter : 0 ;
end
else if(write_pri==1) begin // Notice that there is a check state for every operation
  b0_c_counter = (ba0_state==B_WRITE_CHECK || ba0_state==B_WRITE) ? b0_counter : 0 ;
end
else if(read_pri==1) begin
  b0_c_counter = (ba0_state==B_READ_CHECK || ba0_state==B_READ) ? b0_counter : 0 ;
end
else if(pre_pri==1) begin
  b0_c_counter = (ba0_state==B_PRE_CHECK || ba0_state==B_PRE) ? b0_counter : 0 ;
end
else begin
  b0_c_counter =  b0_counter ;
end

end

// Why do we need stall signals? Only one bank can be granted at a time
always@* begin:STALL_GRANTER
	ba0_stall = 1 ;
if(isu_fifo_full==0)
	if( act_pri || write_pri || read_pri || pre_pri ) begin
	  ba0_stall = 0 ;
	end
	else
  begin
	  if( have_act || have_write || have_read || have_pre ) begin
	    ba0_stall = 0;
	  end
	  else
    begin
	      ba0_stall = 1 ;
	  end
	end
else begin
	ba0_stall = 1 ;
end

end

endmodule

module  check_or_state(other_ba_state0,
                       state,
                       have
                       );

input [`FSM_WIDTH2-1:0]other_ba_state0;
input [`FSM_WIDTH2-1:0]state;

output have ;

// Check to see if there exists a certain state within the bank

assign have = (other_ba_state0 == state)? 1'b1 : 1'b0 ;

endmodule

// Counter in charge of timing constraints counting
module bx_counter(ba_state,
                  clk,
                  rst_n,
                  b_counter);

input [`FSM_WIDTH2-1:0] ba_state ;
input clk ;
input rst_n ;

output [`B_COUNTER_WIDTH-1:0]b_counter;

bank_state_t ba_state_i;

always_comb begin
  // typecast the state to the bank_state_t
  ba_state_i = bank_state_t'(ba_state) ;
end

reg [`B_COUNTER_WIDTH-1:0]b_counter ;

always@(posedge clk) begin
  if(rst_n==0)
    b_counter <= 0 ;
  else
    case(ba_state_i)
      B_IDLE        : b_counter <= 0 ;
      B_ACT_CHECK   : b_counter <= b_counter + 1 ;
      B_WRITE_CHECK : b_counter <= b_counter + 1 ;
      B_READ_CHECK  : b_counter <= b_counter + 1 ;
      B_PRE_CHECK   : b_counter <= b_counter + 1 ;
      B_ACTIVE      : b_counter <= b_counter + 1 ;

      B_READ,
      B_WRITE,
      B_PRE         : b_counter <= b_counter + 1 ;
      B_ACT_STANDBY : b_counter <= 0 ;
      default        : b_counter <= 0 ;
    endcase
end

endmodule

module counter_compare(compare_in,
                       compare_0,
                       compare_1,
                       compare_2,


                       big

                       );

input [`B_COUNTER_WIDTH-1:0]compare_in;
input [`B_COUNTER_WIDTH-1:0]compare_0;
input [`B_COUNTER_WIDTH-1:0]compare_1;
input [`B_COUNTER_WIDTH-1:0]compare_2;


output big ;

assign big = (compare_in > compare_0 && compare_in > compare_1 && compare_in > compare_2)  ? 1 : 0 ;

endmodule