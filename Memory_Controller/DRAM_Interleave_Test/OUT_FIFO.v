
`define COUNTER_WIDTH 3
`define DEPTH 5
//`define OUT_FIFO_WIDTH 65

module OUT_FIFO( clk,
                 rst_n,
                 wen,              
                 data_in,
                 ren,
                 data_out,
                 full,
                 virtual_full,
                 empty
                 );

input clk ;
input rst_n ;
input wen ;          
input [`OUT_FIFO_WIDTH-1:0]data_in ;
input ren ;

output [`OUT_FIFO_WIDTH-1:0]data_out;
output full;
output virtual_full;
output empty;

reg write_en ;
reg empty;
reg virtual_full;

integer i ;

reg [`OUT_FIFO_WIDTH-1:0]buffer[`DEPTH-1:0];
reg [`COUNTER_WIDTH:0]read_counter ;
reg [`COUNTER_WIDTH:0]write_counter ;

reg [`OUT_FIFO_WIDTH-1:0]buf_in ;

reg [`OUT_FIFO_WIDTH-1:0]data_out;

reg [`COUNTER_WIDTH:0]valid_space;

wire[`COUNTER_WIDTH-1:0]  write_0 = write_counter ;

//test signal
wire [`OUT_FIFO_WIDTH-1:0]buf0=buffer[0] ;
wire [`OUT_FIFO_WIDTH-1:0]buf1=buffer[1] ;
wire [`OUT_FIFO_WIDTH-1:0]buf2=buffer[2] ;
wire [`OUT_FIFO_WIDTH-1:0]buf3=buffer[3] ;
wire [`OUT_FIFO_WIDTH-1:0]buf4=buffer[4] ;

always@(posedge clk) begin
if(rst_n==0)
  read_counter <= 0 ;
else
  if(ren==1)
    if(empty)
      read_counter <= read_counter ;
    else
      read_counter <= (read_counter==4)? 0 : read_counter + 1 ;
  else
    read_counter <= read_counter ;
end

always@(posedge clk) begin
if(rst_n==0)
  write_counter <= 0 ;
else
  if(write_en)
    write_counter <= (write_counter==4) ? 0 : write_counter + 1 ;
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
if(valid_space < 1)
  virtual_full = 1 ;
else
  virtual_full = 0 ;
end

always@* begin
empty = (read_counter == write_counter) ? 1 : 0 ;
end

always@* begin
  data_out = buffer[read_counter] ;
end


endmodule


