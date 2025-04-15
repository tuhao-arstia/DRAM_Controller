
`include "define.sv"
`include "Usertype.sv"
`include "frontend_cmd_definition_pkg.sv"


`define TOTAL_CMD 10000 // It is set to 40000 commands

`define TOTAL_ROW 2**(`ROW_BITS) //10-bit  (MAX:16-bit)
`define TOTAL_COL 2**(`COL_BITS)   //4-bit    (MAX:4-bit)
`define TEST_ROW_WIDTH $clog2(`TOTAL_ROW)
`define TEST_COL_WIDTH $clog2(`TOTAL_COL)
`define TOTAL_READ_TO_TEST 100

`define PATTERN_NUM 30
`define DEBUG_ON 1
`define TEST_ROWS 256

// take the log of TOTAL_ROW using function of system verilog

module PATTERN(
         power_on_rst_n,
         clk           ,
         clk2          ,
         write_data    ,
         read_data     ,
         command       ,
         valid         ,
         ba_cmd_pm     ,
         read_data_valid
);

`include "2048Mb_ddr3_parameters.vh"

import usertype::*;
import frontend_command_definition_pkg::*;

//== I/O from System ===============
output  power_on_rst_n;
output  clk  ;
output  clk2 ;
//==================================
//== I/O from access command =======

output  [`DQ_BITS*8-1:0]   write_data;
output  [`FRONTEND_CMD_BITS-1:0] command;
output  valid;
input   [`DQ_BITS*8-1:0]   read_data;
input   ba_cmd_pm;
input   read_data_valid;
//==================================

reg  power_on_rst_n;
reg  clk;
reg  clk2;

reg  [DQ_BITS*8-1:0]   write_data;
reg  [`FRONTEND_CMD_BITS-1:0] command;
//command format = {read/write , row_addr , col_addr , bank } ;
//                  [31]         [30:17]    [16:3]     [2:0]
// new format

reg  valid;

always #(`CLK_DEFINE/2.0) clk = ~clk ;
always #(`CLK_DEFINE/4.0) clk2 = ~clk2 ;

frontend_command_t command_table[`TOTAL_CMD-1:0];

reg [`DQ_BITS*8-1:0]write_data_table[`TOTAL_CMD-1:0];
reg pm_f;

reg [`ROW_BITS-1:0]row_addr; // This now uses 16 bits
reg [`COL_BITS-1:0]col_addr;  // This now uses 4  bits only
reg bl_ctl;
reg auto_pre;
reg [`BA_BITS-1:0]bank;
reg [1:0]rank;

typedef logic[`DQ_BITS*8-1:0] datapath_width_t;	

datapath_width_t golden_memory[`TOTAL_ROW-1:0][`TOTAL_COL-1:0];
datapath_width_t memory_back[`TOTAL_ROW-1:0][`TOTAL_COL-1:0];

integer stall=0;
integer i=0,j=0,k=0;
integer read_data_count,random_rw_num;
integer FILE1,FILE2,FILE3,cmd_count,wdata_count ;

integer ra,rr,cc,bb,bb_x,rr_x,cc_x,ra_x;
integer total_error=0;

typedef enum integer {  
	MARCHING_PATTERN,		
	READ_WRITE_SAME_LOCATION_PATTERN,
	ZIG_ZAG_PATTERN,
	RANDOM_ACCESS_PATTERN,
	REVERSE_HIGH_ADDRESS_ACCESS_PATTERN
} pattern_type_t;

typedef struct packed{
	command_t input_command;
	logic[`DQ_BITS*8-1:0] write_data;
} test_cmds_t;

integer stall_control = 0;

test_cmds_t golden_queue[$];

reg [31:0]bb_back,rr_back,cc_back;
reg [1:0] ra_back;
reg ran_rw;
reg [`TEST_ROW_WIDTH-1:0]ran_row;
reg [`TEST_COL_WIDTH-1:0]ran_col;
// reg [`TEST_BA_WIDTH-1:0]ran_ba;
reg [`TEST_COL_WIDTH-3-1:0]ran_col_div_8;

integer additonal_counts;
integer test_row_num;

wire all_data_read_f = read_data_count == `TOTAL_READ_TO_TEST;

pattern_type_t pattern_type = MARCHING_PATTERN;



//===========================================
//=            
//=                IO LOGIC Control
//=
//===========================================
always@*
begin
  pm_f = ba_cmd_pm ;
end

wire command_sent_handshake_f = valid == 1'b1 && pm_f == 1'b1;
logic[31:0] latency_counter;
logic latency_counter_lock;

always_ff@(posedge clk or negedge power_on_rst_n)
begin: LATENCY_CLOCK_LOCK
  if(power_on_rst_n == 0)
  begin
	latency_counter_lock<=1'b1;
  end
  else begin
	if(command_sent_handshake_f && latency_counter_lock==1'b1)
		latency_counter_lock <= 1'b0;
  end
end

always_ff@(posedge clk or negedge power_on_rst_n)
begin: LATENCY_COUNTER
	if(power_on_rst_n == 0)
		latency_counter<=1;
	else if(latency_counter_lock==1'b0 && all_data_read_f == 1'b0)
		latency_counter<=latency_counter + 1;
end

//command output control
always@(posedge clk) begin
  if(pm_f) begin
  	if(i==`TOTAL_CMD) begin
  	    command <= 0 ;
	    i<=i ;
	    valid<=0 ;
	    write_data <= 0 ;
  	end
  	else begin
  		if(i<golden_queue.size()) begin
	      command <= golden_queue[i] ;
	      valid <=1 ;
	      
		  if(command_sent_handshake_f)
		  begin
		  	i<=i+1 ;
	      	if(golden_queue[i].input_command.r_w == WRITE) begin //write
	      	  write_data <= golden_queue[i].write_data;
	      	  j<=j+1 ;
	      	end
	      	else begin
	      	  write_data <= 0 ;
	      	  j = j ;
	      	end
		  end
	    end
	    else begin
	      i<=i;
	      valid=0;
	    end
	  end
  end
  else begin
    command <= 'd0 ;
    i<=i ;
    valid=0 ;
  end
end

//read data receive control
always@(negedge clk)
begin
	if(read_data_valid==1 && `DEBUG_ON==1) begin
	  //$display("time: %t mem_back rank:%h  bank:%h  row:%h  col:%h data:%h \n",$time,ra_back, bb_back,rr_back,cc_back,read_data);
	  memory_back[rr_back][cc_back]   = read_data;
	end
end

always@(negedge clk) begin
if(read_data_valid==1 && `DEBUG_ON==1) begin
  if(rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-1))
    rr_back <= 0;
  else if(cc_back==(`TOTAL_COL-1))
    rr_back <= rr_back + 1 ;
  else
    rr_back <= rr_back ;
end
end

always@(negedge clk) begin
if(read_data_valid==1 && `DEBUG_ON==1)
  if(cc_back==(`TOTAL_COL-1))
      cc_back <= 0 ;
  else
      cc_back <= cc_back + 1;
end

always@(negedge clk) begin
if(read_data_valid==1 && `DEBUG_ON==1)
  if(rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-1) && bb_back==3)
    bb_back <= 0;
  else if (rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-1))
    bb_back <= bb_back + 1;
  else
    bb_back <= bb_back;
end

always@(negedge clk) begin
if(read_data_valid==1 && `DEBUG_ON==1)
  if(bb_back==3 && rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-1))
    ra_back <= ra_back + 1;
  else
    ra_back <= ra_back;
end

always@(negedge clk) begin
	if(power_on_rst_n==0) begin
	  read_data_count=0;
	end
	else begin
	  if(read_data_valid==1 && `DEBUG_ON==1)
	    read_data_count=read_data_count+1;
	end
end

task check_result_task;

	wait(all_data_read_f == 1'b1);

	repeat(100) begin
	  @(negedge clk);
	end

	//===========================
	//    CHECK RESULT         //
	//===========================
  	for(rr_x=0;rr_x<test_row_num;rr_x=rr_x+1)begin
 	  for(cc_x=0;cc_x<`TOTAL_COL;cc_x=cc_x+1)begin

 	      if(golden_memory[rr_x][cc_x] !== memory_back[rr_x][cc_x]) begin
 	        $display("mem[%1d][%1d][%2d][%2d] ACCESS FAIL ! , mem=%4h , mem_back=%4h",rr_x,cc_x,golden_memory[rr_x][cc_x],memory_back[rr_x][cc_x]) ;
 	    	   total_error=total_error+1;
  	   	 end
  	   	 else
  	   	   $display("mem[%2d][%2d] ACCESS SUCCESS ! ",rr_x,cc_x) ;
  	 end
  	end

	$display(" TOTAL design read data: %12d",read_data_count);
	$display("=====================================") ;
	$display(" TOTAL_ERROR: %12d",total_error);
	$display("=====================================") ;
	$display("Read data count: %d",read_data_count);
	$display("Total read data count: %d",`TOTAL_READ_TO_TEST);
	$display("Total Memory Simulation cycles:         %d",latency_counter);

	$finish;
endtask


initial begin
	main_task();
end

//===========================================
//=            
//=                TASKs
//=
//===========================================
task main_task;
	init_config();
	generate_write_commands(`TEST_ROWS,MARCHING_PATTERN,golden_queue);
	generate_read_commands(`TEST_ROWS,MARCHING_PATTERN,golden_queue);
	read_write_to_golden_memory(golden_queue,golden_memory);

	reset_task();
	check_result_task();
	
endtask

task reset_task();
begin
	clk = 1 ;
	clk2 = 1 ;
	power_on_rst_n = 1 ;
	valid = 0 ;

	repeat(10) @(negedge clk);
	power_on_rst_n = 0 ;
	
	repeat(10) @(negedge clk);
	power_on_rst_n = 1 ;
end
endtask


//===========================================
//=            
//=                FUNCTIONS
//=
//===========================================

function automatic void init_config();
begin
	$display("=============================================");
    $display("= Initialization Settings 			      =");
    $display("=============================================");
	
	FILE1 = $fopen("pattern_write_cmds.txt","w");
	FILE2 = $fopen("pattern_wdata.txt","w");
	FILE3 = $fopen("pattern_read_cmds.txt","w");

	// Intiailization of queues, golden memory and test memory
	golden_queue = {};
end
endfunction

integer _col_stride = 0;
integer _row_stride = 0;
integer _begin_column = 0;
integer _begin_row = 0;
r_w_t _rw_ctl = WRITE;


task generate_write_commands(input integer test_row_num,
							 	input pattern_type_t pattern_type,
							 	ref test_cmds_t golden_queue);
begin		
			$display("=============================================");
    		$display("= Generating WRITE COMMANDS & WRITE DATA    =");
    		$display("=============================================");

			_col_stride = 0;
			_row_stride = 0;
			_begin_column = 0;
			_begin_row = 0;
			_rw_ctl = WRITE;

			// Pattern type selections
			case(pattern_type)
				MARCHING_PATTERN: begin
					_begin_row  = 0;
					_begin_column = 0;

					_col_stride = 1;
					_row_stride = 1;
				end
				READ_WRITE_SAME_LOCATION_PATTERN: begin
					_begin_row = 0;
					_begin_column = 0;

					_col_stride = 0;
					_row_stride = 0;
				end
				ZIG_ZAG_PATTERN: begin
					_begin_row = 0;
					_begin_column = 0;

					_col_stride = 1;
					_row_stride = 8;
				end
				RANDOM_ACCESS_PATTERN: begin
					_begin_row  =   random() % `TOTAL_ROW;
					_begin_column = random() % `TOTAL_COL;

					_col_stride =  random() % `TOTAL_COL;
					_row_stride =  random() % test_row_num;
				end
				REVERSE_HIGH_ADDRESS_ACCESS_PATTERN: begin
					_begin_row    = `TOTAL_ROW - 1;
					_begin_column = `TOTAL_COL - 1;
					
					_col_stride = -1;
					_row_stride = 0;
				end
				default: begin
					_begin_row  = 0;
					_begin_column = 0;

					_col_stride = 1;
					_row_stride = 0;
				end
			endcase
			
			for(rr=_begin_row;rr<`TOTAL_ROW;rr=rr+_row_stride) begin
				for(cc=_begin_column;cc<`TOTAL_COL;cc=cc+_col_stride) begin
					test_cmds_t _command_temp_in;
					
					// Early break
					if(rr >= test_row_num) begin
						break;
					end

					_command_temp_in.input_command.op_type   = _rw_ctl;
					_command_temp_in.input_command.data_type = DATA_TYPE_WEIGHTS;
					_command_temp_in.input_command.row_addr  = rr;
					_command_temp_in.input_command.col_addr  = cc;

					_command_temp_in.write_data = rr*16+cc;

					// Write this into external file
					if(`DEBUG_ON == `DEBUG_ON) begin
						$fdisplay(FILE1,"%31b",_command_temp_in.input_command);
						$fdisplay(FILE2,"%1024h",_command_temp_in.write_data);
					end

					golden_queue.push_back(_command_temp_in);
				  end 
				end
end
endtask

task generate_read_commands(input integer test_row_num,
								input pattern_type_t pattern_type,
								ref test_cmds_t golden_queue);
begin
			$display("========================================");
    		$display("=   Generating READ commands           =");
    		$display("========================================");
			_col_stride = 0;
			_row_stride = 0;
			_begin_column = 0;
			 _begin_row = 0;
			_rw_ctl = READ;

			// Pattern type selections
			case(pattern_type)
				MARCHING_PATTERN: begin
					_begin_row  = 0;
					_begin_column = 0;

					_col_stride = 1;
					_row_stride = 1;
				end
				READ_WRITE_SAME_LOCATION_PATTERN: begin
					_begin_row = 0;
					_begin_column = 0;

					_col_stride = 0;
					_row_stride = 0;
				end
				ZIG_ZAG_PATTERN: begin
					_begin_row = 0;
					_begin_column = 0;

					_col_stride = 1;
					_row_stride = 8;
				end
				RANDOM_ACCESS_PATTERN: begin
					_begin_row  = random() % `TOTAL_ROW;
					_begin_column = random() % `TOTAL_COL;

					_col_stride = random() % `TOTAL_COL;
					_row_stride = random() % test_row_num;
				end
				REVERSE_HIGH_ADDRESS_ACCESS_PATTERN: begin
					_begin_row    = `TOTAL_ROW - 1;
					_begin_column = `TOTAL_COL - 1;
					
					_col_stride = -1;
					_row_stride = 0;
				end
				default: begin
					_begin_row  = 0;
					_begin_column = 0;

					_col_stride = 1;
					_row_stride = 0;
				end
			endcase
			
			for(rr=_begin_row;rr<`TOTAL_ROW;rr=rr+_row_stride) begin
				for(cc=_begin_column;cc<`TOTAL_COL;cc=cc+_col_stride) begin
					test_cmds_t _command_temp_in = 0;
					
					// Early break
					if(rr >= test_row_num) begin
						break;
					end

					_command_temp_in.input_command.op_type   = _rw_ctl;
					_command_temp_in.input_command.data_type = DATA_TYPE_WEIGHTS;
					_command_temp_in.input_command.row_addr  = rr;
					_command_temp_in.input_command.col_addr  = cc;

					_command_temp_in.write_data = 0;

					// Write this into external file
					if(`DEBUG_ON == `DEBUG_ON) begin
						$fdisplay(FILE3,"%31b",_command_temp_in.input_command);
					end

					golden_queue.push_back(_command_temp_in);
				  end 
				end
end
endtask

task read_write_to_golden_memory(ref test_cmds_t golden_queue, ref datapath_width_t golden_memory);
begin
	for(int i=0;i<golden_queue.size();i++) begin
		test_cmds_t _temp = golden_queue[i];

		if(_temp.input_command.op_type == WRITE) begin
			// Write the data into the golden memory
			golden_memory[_temp.input_command.row_addr][_temp.input_command.col_addr] = _temp.write_data;
		end
	end
end
endtask


endmodule