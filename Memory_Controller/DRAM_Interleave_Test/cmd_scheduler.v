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

module cmd_scheduler(
                         clk,
                         rst_n,
                         isu_fifo_full,
                         ba0_info,
                         ba1_info,
                         ba2_info,
                         ba3_info,
                        
                         ba0_stall,
                         ba1_stall,
                         ba2_stall,
                         ba3_stall,
                         
                         sch_out,
                         sch_issue
                         );
input clk;
input rst_n;
input isu_fifo_full;
input [`BA_INFO_WIDTH-1:0]ba0_info;
input [`BA_INFO_WIDTH-1:0]ba1_info;
input [`BA_INFO_WIDTH-1:0]ba2_info;
input [`BA_INFO_WIDTH-1:0]ba3_info;


output ba0_stall;
output ba1_stall;
output ba2_stall;
output ba3_stall;


output [`ISU_FIFO_WIDTH-1:0]sch_out ;
output sch_issue ;

reg ba0_stall;
reg ba1_stall;
reg ba2_stall;
reg ba3_stall;


reg [3:0]sch_command ;
reg [13:0]sch_addr;
reg [2:0]sch_bank;

reg sch_issue ;

reg [2:0]act_count ;
reg [2:0]write_count ;
reg [2:0]read_count ;
reg [2:0]pre_count ;

reg [`FSM_WIDTH2-1:0]bax_state ;

reg [`FSM_WIDTH2-1:0]f_ba_state ;

wire [`FSM_WIDTH2-1:0]ba0_state = ba0_info[`BA_INFO_WIDTH-1-:`FSM_WIDTH2];
wire [`FSM_WIDTH2-1:0]ba1_state = ba1_info[`BA_INFO_WIDTH-1-:`FSM_WIDTH2];
wire [`FSM_WIDTH2-1:0]ba2_state = ba2_info[`BA_INFO_WIDTH-1-:`FSM_WIDTH2];
wire [`FSM_WIDTH2-1:0]ba3_state = ba3_info[`BA_INFO_WIDTH-1-:`FSM_WIDTH2];


wire [2:0]ba0_proc = ba0_info[2:0];
wire [2:0]ba1_proc = ba1_info[2:0];
wire [2:0]ba2_proc = ba2_info[2:0];
wire [2:0]ba3_proc = ba3_info[2:0];


reg act_pri; 
reg read_pri;
reg write_pri;
reg pre_pri;
reg current_rw ;

wire [`B_COUNTER_WIDTH-1:0]b0_counter,b1_counter,b2_counter,b3_counter;


reg [`B_COUNTER_WIDTH-1:0] b0_c_counter,b1_c_counter,b2_c_counter,b3_c_counter;


wire pre0_threshold = (b0_c_counter > 16) ? 1 : 0 ;
wire pre1_threshold = (b1_c_counter > 16) ? 1 : 0 ;
wire pre2_threshold = (b2_c_counter > 16) ? 1 : 0 ;
wire pre3_threshold = (b3_c_counter > 16) ? 1 : 0 ;



bx_counter     b0(.ba_state  (ba0_state),
                  .clk       (clk),
                  .rst_n     (rst_n),
                  .b_counter (b0_counter),
                  .ba_stall  (ba0_stall),
                  .ba_proc   (ba0_proc) );

bx_counter     b1(.ba_state  (ba1_state),
                  .clk       (clk),
                  .rst_n     (rst_n),
                  .b_counter (b1_counter),
                  .ba_stall  (ba1_stall),
                  .ba_proc   (ba1_proc));
                  
bx_counter     b2(.ba_state  (ba2_state),
                  .clk       (clk),
                  .rst_n     (rst_n),
                  .b_counter (b2_counter),
                  .ba_stall  (ba2_stall),
                  .ba_proc   (ba2_proc));
                  
bx_counter     b3(.ba_state  (ba3_state),
                  .clk       (clk),
                  .rst_n     (rst_n),
                  .b_counter (b3_counter),
                  .ba_stall  (ba3_stall),
                  .ba_proc   (ba3_proc));                                    

 
wire have_cmd_act ;  
wire have_cmd_read ; 
wire have_cmd_write ; 
wire have_cmd_pre ;

check_or_state    check_cmd_act(ba0_state,ba1_state,ba2_state,ba3_state,`B_ACTIVE,have_cmd_act); 
check_or_state    check_cmd_write(ba0_state,ba1_state,ba2_state,ba3_state,`B_WRITE,have_cmd_write);
check_or_state    check_cmd_read(ba0_state,ba1_state,ba2_state,ba3_state,`B_READ,have_cmd_read);
check_or_state    check_cmd_pre(ba0_state,ba1_state,ba2_state,ba3_state,`B_PRE,have_cmd_pre);

always@(posedge clk) begin
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

always@(posedge clk) begin
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

always@(posedge clk) begin
if(rst_n==0)
  pre_count <= 0 ;
else
  if(have_cmd_pre)
     pre_count <= (pre_count==3)? 1 : pre_count + 1 ;
  else
     pre_count <= pre_count ;
end

always@* begin
if(ba0_state == `B_ACTIVE || ba0_state == `B_READ || ba0_state == `B_WRITE || ba0_state == `B_PRE)
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba0_info[21:3],3'd0,1'b1} ;
  
else if (ba1_state == `B_ACTIVE || ba1_state == `B_READ || ba1_state == `B_WRITE || ba1_state == `B_PRE)
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba1_info[21:3],3'd1,1'b1} ;
  
else if (ba2_state == `B_ACTIVE || ba2_state == `B_READ || ba2_state == `B_WRITE || ba2_state == `B_PRE) 
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba2_info[21:3],3'd2,1'b1} ;
  
else if (ba3_state == `B_ACTIVE || ba3_state == `B_READ || ba3_state == `B_WRITE || ba3_state == `B_PRE) 
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba3_info[21:3],3'd3,1'b1} ;
  
else
  {f_ba_state,sch_addr,sch_bank,sch_issue} = {ba0_info[21:3],3'd0,1'b0} ;
  
end

always@* begin
if(write_count != 0 && read_count == 0)
  current_rw = 0 ; //continuous write
else if(write_count == 0 && read_count != 0)
  current_rw = 1 ; //continuous read
else
  current_rw = 0 ;
end

always@* begin
case(f_ba_state)
  `B_ACTIVE : sch_command <= `ATCMD_ACTIVE ;
  `B_READ   : sch_command <= `ATCMD_READ ;
  `B_WRITE  : sch_command <= `ATCMD_WRITE ;
  `B_PRE    : sch_command <= `ATCMD_PRECHARGE ;
  default   : sch_command <= `ATCMD_NOP ;
endcase
end

assign sch_out = {sch_command,sch_addr,sch_bank} ;


wire all_no_0,all_no_1,all_no_2,all_no_3;
//wire or_w_0,or_w_1,or_w_2,or_w_3,or_w_4,or_w_5,or_w_6,or_w_7;

wire have_act_c,have_write_c,have_read_c,have_pre_c ;
wire have_act_a,have_write_a,have_read_a,have_pre_a ;
wire b0_big_st,b1_big_st,b2_big_st,b3_big_st;

check_or_state    check_act_c(ba0_state,ba1_state,ba2_state,ba3_state,`B_ACT_CHECK,have_act_c);
check_or_state    check_write_c(ba0_state,ba1_state,ba2_state,ba3_state,`B_WRITE_CHECK,have_write_c);
check_or_state    check_read_c(ba0_state,ba1_state,ba2_state,ba3_state,`B_READ_CHECK,have_read_c);
check_or_state    check_pre_c(ba0_state,ba1_state,ba2_state,ba3_state,`B_PRE_CHECK,have_pre_c);

check_or_state    check_act_a(ba0_state,ba1_state,ba2_state,ba3_state,`B_ACTIVE,have_act_a);
check_or_state    check_write_a(ba0_state,ba1_state,ba2_state,ba3_state,`B_WRITE,have_write_a);
check_or_state    check_read_a(ba0_state,ba1_state,ba2_state,ba3_state,`B_READ,have_read_a);
check_or_state    check_pre_a(ba0_state,ba1_state,ba2_state,ba3_state,`B_PRE,have_pre_a);

counter_compare  comp0(b0_counter,b1_counter,b2_counter,b3_counter,b0_big_st);
counter_compare  comp1(b1_counter,b0_counter,b2_counter,b3_counter,b1_big_st);
counter_compare  comp2(b2_counter,b0_counter,b1_counter,b3_counter,b2_big_st);
counter_compare  comp3(b3_counter,b0_counter,b1_counter,b2_counter,b3_big_st);


always@* begin
case( {b3_big_st,b2_big_st,b1_big_st,b0_big_st} )
  8'b00000000:bax_state = ba0_state ;
  8'b00000001:bax_state = ba0_state ;
  8'b00000010:bax_state = ba1_state ;
  8'b00000100:bax_state = ba2_state ;
  8'b00001000:bax_state = ba3_state ;
  default : bax_state = ba0_state ;
endcase
end

wire have_act = have_act_c || have_act_a ;
wire have_write = have_write_c || have_write_a ;
wire have_read = have_read_c || have_read_a ;
wire have_pre = have_pre_c || have_pre_a ;


always@* begin
case( {have_act,have_write,have_read,have_pre} )
  4'b0000 :{act_pri,write_pri,read_pri,pre_pri} = 0 ;
  4'b0001 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
  4'b0010 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
  
  4'b0011 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
  
  4'b0100 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
  4'b0101 :if(bax_state == `B_PRE_CHECK || bax_state == `B_PRE)
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
           else
	           if(pre0_threshold||pre1_threshold||pre2_threshold||pre3_threshold)
	             
	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
	           
	           else
	             
	             {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
  
  4'b1000 :{act_pri,write_pri,read_pri,pre_pri} = 4'b1000 ;
  4'b1001 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;

  
 // 4'b0110 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0000 ;
 // 4'b0111 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0000 ;
 // 4'b1110 :{act_pri,write_pri,read_pri,pre_pri} = 4'b0000 ;
  
  4'b0110 :if(write_count!=0 && read_count==0)     //continuous write
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
           else if(write_count==0 && read_count!=0)//continuous read
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
           else
             if(bax_state==`B_WRITE_CHECK || bax_state == `B_WRITE)
               {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
             else
               {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
             
  4'b0111 :if(bax_state == `B_PRE_CHECK || bax_state == `B_PRE)
             {act_pri,write_pri,read_pri,pre_pri} = 4'b0001 ;
           else
	           if(current_rw==1)//continuous
	              {act_pri,write_pri,read_pri,pre_pri} = 4'b0010 ;
	           else
	              {act_pri,write_pri,read_pri,pre_pri} = 4'b0100 ;
    
  4'b1110 :begin
  	         if(bax_state == `B_ACT_CHECK || bax_state == `B_ACTIVE)
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
  	  	     if(bax_state == `B_ACT_CHECK || bax_state == `B_ACTIVE)
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
  	         if(bax_state == `B_ACT_CHECK || bax_state == `B_ACTIVE)
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


/*
always@* begin
{act_pri,write_pri,read_pri,pre_pri} = 4'b0000 ;
end
*/

wire b0_big,b1_big,b2_big,b3_big;

always@* begin
if(act_pri==1) begin
  b0_c_counter = (ba0_state==`B_ACT_CHECK || ba0_state==`B_ACTIVE) ? b0_counter : 0 ;
  b1_c_counter = (ba1_state==`B_ACT_CHECK || ba1_state==`B_ACTIVE) ? b1_counter : 0 ;
  b2_c_counter = (ba2_state==`B_ACT_CHECK || ba2_state==`B_ACTIVE) ? b2_counter : 0 ;
  b3_c_counter = (ba3_state==`B_ACT_CHECK || ba3_state==`B_ACTIVE) ? b3_counter : 0 ;

end
else if(write_pri==1) begin
  b0_c_counter = (ba0_state==`B_WRITE_CHECK || ba0_state==`B_WRITE) ? b0_counter : 0 ;
  b1_c_counter = (ba1_state==`B_WRITE_CHECK || ba1_state==`B_WRITE) ? b1_counter : 0 ;
  b2_c_counter = (ba2_state==`B_WRITE_CHECK || ba2_state==`B_WRITE) ? b2_counter : 0 ;
  b3_c_counter = (ba3_state==`B_WRITE_CHECK || ba3_state==`B_WRITE) ? b3_counter : 0 ;

end
else if(read_pri==1) begin
  b0_c_counter = (ba0_state==`B_READ_CHECK || ba0_state==`B_READ) ? b0_counter : 0 ;
  b1_c_counter = (ba1_state==`B_READ_CHECK || ba1_state==`B_READ) ? b1_counter : 0 ;
  b2_c_counter = (ba2_state==`B_READ_CHECK || ba2_state==`B_READ) ? b2_counter : 0 ;
  b3_c_counter = (ba3_state==`B_READ_CHECK || ba3_state==`B_READ) ? b3_counter : 0 ;
end  
else if(pre_pri==1) begin
  b0_c_counter = (ba0_state==`B_PRE_CHECK || ba0_state==`B_PRE) ? b0_counter : 0 ;
  b1_c_counter = (ba1_state==`B_PRE_CHECK || ba1_state==`B_PRE) ? b1_counter : 0 ;
  b2_c_counter = (ba2_state==`B_PRE_CHECK || ba2_state==`B_PRE) ? b2_counter : 0 ;
  b3_c_counter = (ba3_state==`B_PRE_CHECK || ba3_state==`B_PRE) ? b3_counter : 0 ;
end  
else begin
  b0_c_counter =  b0_counter ;
  b1_c_counter =  b1_counter ;
  b2_c_counter =  b2_counter ;
  b3_c_counter =  b3_counter ;
end

end

counter_compare  comp0_c(b0_c_counter,b1_c_counter,b2_c_counter,b3_c_counter,b0_big);
counter_compare  comp1_c(b1_c_counter,b0_c_counter,b2_c_counter,b3_c_counter,b1_big);
counter_compare  comp2_c(b2_c_counter,b0_c_counter,b1_c_counter,b3_c_counter,b2_big);
counter_compare  comp3_c(b3_c_counter,b0_c_counter,b1_c_counter,b2_c_counter,b3_big);




always@* begin
if(isu_fifo_full==0)
	if( act_pri || write_pri || read_pri || pre_pri ) begin
	  ba0_stall = (b0_big) ? 0 : 1 ;
	  ba1_stall = (b1_big) ? 0 : 1 ;
	  ba2_stall = (b2_big) ? 0 : 1 ;
	  ba3_stall = (b3_big) ? 0 : 1 ;
	end
	else begin
	  if( have_act || have_write || have_read || have_pre ) begin
	    ba0_stall = (b0_big) ? 0 : 1 ;
	    ba1_stall = (b1_big) ? 0 : 1 ;
	    ba2_stall = (b2_big) ? 0 : 1 ;
	    ba3_stall = (b3_big) ? 0 : 1 ;
	  end
	  else begin
	    ba0_stall = 1 ;
        ba1_stall = 1 ;
        ba2_stall = 1 ;
        ba3_stall = 1 ;
	  end
	    
	end 
else begin
	ba0_stall = 1 ;
	ba1_stall = 1 ;
	ba2_stall = 1 ;
	ba3_stall = 1 ;
end
 
end

endmodule

module  check_or_cmd(other_ba_proc0,
                     other_ba_proc1,
                     other_ba_proc2,
                     other_ba_proc3,
                     other_ba_proc4,
                     other_ba_proc5,
                     other_ba_proc6,
                     proc,
                     
                     have
                     );

input [2:0]other_ba_proc0;
input [2:0]other_ba_proc1;       
input [2:0]other_ba_proc2;
input [2:0]other_ba_proc3;
input [2:0]other_ba_proc4;
input [2:0]other_ba_proc5;
input [2:0]other_ba_proc6;
input [2:0]proc;

output have ;

assign have = (other_ba_proc0 == proc || other_ba_proc1 == proc || other_ba_proc2 == proc ||
               other_ba_proc3 == proc || other_ba_proc4 == proc || other_ba_proc5 == proc ||
               other_ba_proc6 == proc) ? 1 : 0 ;


endmodule


module  check_or_state(other_ba_state0,
                       other_ba_state1,
                       other_ba_state2,
                       other_ba_state3,
                       state,
                       
                       have
                       );

input [`FSM_WIDTH2-1:0]other_ba_state0;
input [`FSM_WIDTH2-1:0]other_ba_state1;       
input [`FSM_WIDTH2-1:0]other_ba_state2;
input [`FSM_WIDTH2-1:0]other_ba_state3;
input [`FSM_WIDTH2-1:0]state;

output have ;

assign have = (other_ba_state0 == state || other_ba_state1 == state || other_ba_state2 == state ||
               other_ba_state3 == state ) ? 1 : 0 ;

endmodule


module bx_counter(ba_state,
                  clk,
                  rst_n,
                  b_counter,
                  ba_stall,
                  ba_proc);

input [`FSM_WIDTH2-1:0] ba_state ;
input clk ;
input rst_n ;
input [`STALL_WIDTH-1:0] ba_stall ;
input [2:0]ba_proc ;

output [`B_COUNTER_WIDTH-1:0]b_counter ;


reg [`B_COUNTER_WIDTH-1:0]b_counter ;
                  
always@(posedge clk) begin
  if(rst_n==0)
    b_counter <= 0 ;
  else
    case(ba_state)
      `B_IDLE        : b_counter <= 0 ;
      `B_ACT_CHECK   : b_counter <= b_counter + 1 ;
      `B_WRITE_CHECK : b_counter <= b_counter + 1 ;
      `B_READ_CHECK  : b_counter <= b_counter + 1 ;
      `B_PRE_CHECK   : b_counter <= b_counter + 1 ;
      `B_ACTIVE      : b_counter <= b_counter + 1 ;
      
      `B_READ,
      `B_WRITE,
      `B_PRE         : b_counter <= b_counter + 1 ;
      `B_ACT_STANDBY : b_counter <= 0 ;
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

