////////////////////////////////////////////////////////////////////////
// Project Name: eHome-IV
// Task Name   : issue FIFO
// Module Name : issue_FIFO
// File Name   : issue_FIFO.v
// Description : store the issued command,addr,bank
// Author      : Chih-Yuan Chang
// Revision History:
// Date        : 2012.12.12
////////////////////////////////////////////////////////////////////////


`define COUNTER_WIDTH 5
`define DEPTH 32
`include "userType_pkg.sv"

module issue_FIFO( 
                   // Data in
                   clk,
                   rst_n,
                   wen,
                   data_in,
                   ren,
                   // Data out
                   data_out,
                   data_out_pre,
                   full,
                   virtual_full,
                   empty
                   );

input clk ;
input rst_n ;
input wen ;
input [`ISU_FIFO_WIDTH-1:0]data_in ; //{command , addr , bank} [20:17]   [16:3] [2:0]
input ren ;


output [`ISU_FIFO_WIDTH-1:0]data_out;
output [`ISU_FIFO_WIDTH-1:0]data_out_pre;
output full;
output virtual_full;
output empty;

import userType_pkg::*;

typedef struct packed {
  sch_cmd_t command;
  logic[13:0] addr;
  logic[2:0] bank;
} issue_fifo_cmd_in_t;

reg write_en ;
reg empty;
reg virtual_full,full;

integer i ;

issue_fifo_cmd_in_t buffer[`DEPTH-1:0];

reg [`COUNTER_WIDTH-1:0]read_counter ;
reg [`COUNTER_WIDTH-1:0]read_counter_sub1 ;
reg [`COUNTER_WIDTH-1:0]write_counter ;

issue_fifo_cmd_in_t buf_in ;

issue_fifo_cmd_in_t data_out;
issue_fifo_cmd_in_t data_out_pre;

reg [`COUNTER_WIDTH:0]valid_space;

wire[`COUNTER_WIDTH-1:0]  write_0 = write_counter ;

//test signal
issue_fifo_cmd_in_t buf0 ;
issue_fifo_cmd_in_t buf1 ;
issue_fifo_cmd_in_t buf2 ;
issue_fifo_cmd_in_t buf3 ;
issue_fifo_cmd_in_t buf4 ;

always_comb begin:TEST_SIGNALS
  buf0 = buffer[0] ;
  buf1 = buffer[1] ;
  buf2 = buffer[2] ;
  buf3 = buffer[3] ;
  buf4 = buffer[4] ;
end

always@(posedge clk) begin
if(rst_n==0)
  read_counter <= 0 ;
else
  if(ren==1)
    if(empty)
      read_counter <= read_counter ;
    else
      read_counter <= read_counter + 1 ;
  else
    read_counter <= read_counter ;
end

always@(posedge clk) begin
if(rst_n==0)
  write_counter <= 0 ;
else
  if(write_en)
    write_counter <= write_counter + 1 ;
  else
    write_counter <= write_counter ;
end

always@(posedge clk)begin

for(i=0;i<`DEPTH;i=i+1)
  buffer[i] <= buffer[i] ;

if(write_en)
 buffer[write_0] <= data_in ;
else
	for(i=0;i<`DEPTH;i=i+1)
	  buffer[i] <= buffer[i] ;

end

always@* begin
if(write_counter >= read_counter)
  valid_space = (`DEPTH-write_counter)+read_counter ;
else
  valid_space = read_counter-write_counter ;
end

always@* begin
    write_en = wen ;
end

always@* begin
if(valid_space < 8)
  virtual_full = 1 ;
else
  virtual_full = 0 ;
end

always@* begin
if(valid_space < 4)
  full = 1 ;
else
  full = 0 ;
end

always@* begin
empty = (read_counter == write_counter) ? 1 : 0 ;
end

always@* begin
read_counter_sub1 = read_counter-1 ;
end

always@* begin
  data_out = buffer[read_counter] ;
  data_out_pre = buffer[read_counter_sub1] ;
end


endmodule
