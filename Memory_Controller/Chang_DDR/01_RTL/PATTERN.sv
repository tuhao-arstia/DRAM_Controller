
`include "define.sv"
`include "Usertype.sv"


`define TOTAL_CMD 10000 // It is set to 40000 commands

`define TOTAL_ROW 2**(`ROW_BITS) //10-bit  (MAX:16-bit)
`define TOTAL_COL 2**(`COL_BITS)   //4-bit    (MAX:4-bit)
`define TEST_ROW_WIDTH $clog2(`TOTAL_ROW)
`define TEST_COL_WIDTH $clog2(`TOTAL_COL)

`define PATTERN_NUM 30

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

//== I/O from System ===============
output  power_on_rst_n;
output  clk  ;
output  clk2 ;
//==================================
//== I/O from access command =======

output  [DQ_BITS*8-1:0]   write_data;
output  [`USER_COMMAND_BITS-1:0] command;
output  valid;
input   [DQ_BITS*8-1:0]   read_data;
input   [7:0] ba_cmd_pm;
input   read_data_valid;
//==================================

reg  power_on_rst_n;
reg  clk;
reg  clk2;

reg  [DQ_BITS*8-1:0]   write_data;
reg  [`USER_COMMAND_BITS-1:0] command;
//command format = {read/write , row_addr , col_addr , bank } ;
//                  [31]         [30:17]    [16:3]     [2:0]
// new format

reg  valid;

always #(`CLK_DEFINE/2.0) clk = ~clk ;
always #(`CLK_DEFINE/4.0) clk2 = ~clk2 ;

user_command_type_t command_table[`TOTAL_CMD-1:0];

reg [DQ_BITS*8-1:0]write_data_table[`TOTAL_CMD-1:0];
reg pm_f;

reg rw_ctl ; //0:write ; 1:read
reg [`ROW_BITS-1:0]row_addr; // This now uses 16 bits
reg [`COL_BITS-1:0]col_addr;  // This now uses 4  bits only
reg bl_ctl;
reg auto_pre;
reg [`BA_BITS-1:0]bank;
reg [1:0]rank;

integer stall=0;
integer i=0,j=0,k=0;
integer read_data_count,random_rw_num;
integer FILE1,FILE2,cmd_count,wdata_count ;

integer ra,rr,cc,bb,bb_x,rr_x,cc_x,ra_x;
integer total_error=0;
reg [33:0]command_table_out;

reg [`DQ_BITS*8-1:0]mem[1:0][2:0][`TOTAL_ROW-1:0][`TOTAL_COL-1:0] ; //[rank][bank][row][col];
reg [`DQ_BITS*8-1:0]mem_back[1:0][2:0][`TOTAL_ROW-1:0][`TOTAL_COL-1:0] ; //[rank][bank][row][col];

reg [DQ_BITS*8-1:0]write_data_temp ;
reg [DQ_BITS*8-1:0]write_data_tt[0:3] ;
reg [DQ_BITS*8-1:0]read_data_tt[0:3] ;

reg [31:0]bb_back,rr_back,cc_back;
reg [1:0] ra_back;
reg ran_rw;
reg [`TEST_ROW_WIDTH-1:0]ran_row;
reg [`TEST_COL_WIDTH-1:0]ran_col;
// reg [`TEST_BA_WIDTH-1:0]ran_ba;
reg [`TEST_COL_WIDTH-3-1:0]ran_col_div_8;
reg debug_on;

reg     [`DQ_BITS*8-1:0]    img0[0:38015];
reg     [`DQ_BITS*8-1:0]    img1[0:38015];

integer additonal_counts;
integer test_row_num;
user_command_type_t command_temp_in;


initial begin

FILE1 = $fopen("pattern_cmd.txt","w");
FILE2 = $fopen("pattern_wdata.txt","w");
//FILE3 = $fopen("IN_C1_128.txt","r");
//FILE4 = $fopen("IN_C2_128.txt","r");
$readmemh("IN_C1_128.txt", img0);
$readmemh("IN_C2_128.txt", img1);
wdata_count=0;
cmd_count=0;
bb=0;
rr=0;
cc=0;
ra=0;

bb_back=0;
rr_back=0;
cc_back=0;
ra_back=0;

debug_on=0;

//
test_row_num = 16;
// test_row_num = `TOTAL_ROW;

//===========================================
//   WRITE
//===========================================
    $display("========================================");
    $display("= Start to write the initial data!     =");
    $display("========================================");
	for(ra=0;ra<1;ra=ra+1) begin
		for(bb=0;bb<1;bb=bb+1) begin
			for(rr=0;rr<test_row_num;rr=rr+1) begin
				for(cc=0;cc<`TOTAL_COL;cc=cc+8) begin

					// Read write interleave
					// if(rw_ctl == 0)
				  	// 	rw_ctl = 1 ;//read
					// else
					// 	rw_ctl = 0;//write

					// write
					rw_ctl = 0;

				  	row_addr = rr ;
				  	col_addr = cc ;
				  	bl_ctl = 1 ;

				 // 	if(cc==32)
				 // 	  auto_pre = 1 ;
				 // 	else
				  	  auto_pre = 0 ;
				  	rank = ra ;
				  	bank = bb ;
					
					// Command assignements
					command_temp_in
					.rank_num = rank;
					command_temp_in.r_w = rw_ctl;
					command_temp_in.none_0 = 1'b0;
					command_temp_in.row_addr = row_addr;
					command_temp_in.none_1 = 1'b0;
					command_temp_in.burst_length = bl_ctl;
					command_temp_in.none_2 = 1'b0;
					command_temp_in.auto_precharge = auto_pre;
					command_temp_in.col_addr = col_addr;
					command_temp_in.bank_addr = bank;

				    command_table[cmd_count]=command_temp_in;
				    
					$fdisplay(FILE1,"%34b",command_table[cmd_count]);

				    if(rw_ctl==0)
					begin
					  //write, the write should now be extended to 1024 bits data instead of only 128bits
				      //write_data_table[wdata_count] = {$random,$random,$random,$random} ;
					  write_data_table[wdata_count] = img0[wdata_count] ;
				      write_data_temp = write_data_table[wdata_count] ;
				      write_data_tt[0] = write_data_temp[31:0] ;
				      write_data_tt[1] = write_data_temp[63:32] ;
				      write_data_tt[2] = write_data_temp[95:64] ;
				      write_data_tt[3] = write_data_temp[127:96] ;
				      $fdisplay(FILE2,"%128b",write_data_table[wdata_count]);

				      //`ifdef PATTERN_DISP_ON
				      $write("PATTERN INFO. => WRITE;"); $write("COMMAND # %d; ",cmd_count);

				      $write(" ROW:%d; ",row_addr);$write(" COL:%d; ",col_addr);$write(" BANK:%d; ",bank);$write(" RANK:%d; ",rank);$write("|");

				      //if(bl_ctl==0)
				      //  $write("Burst Legnth:4; ");
				      //else
				      //  $write("Burst Legnth:8; ");

				      if(auto_pre==0)
				        $display("AUTO PRE:Disable ");
				      else
				        $display("AUTO PRE:Enable ");
				      //`endif

				      $display("Write data : ");
					  $write(" %h ",write_data_temp);
				      //for(k=0;k<8;k=k+1) begin
				       //
				        //mem[bb][rr][cc+k] = write_data_temp[15:0] ;
						mem[ra][bb][rr][cc] = write_data_temp;
				        //write_data_temp=write_data_temp>>16;
				      //end
				      $display(" ");

				      wdata_count = wdata_count + 1 ;
				    end //end if rw_ctl



				  cmd_count=cmd_count+1 ;
				end
			end
		end
		/*
		for(stall=0;stall<100;stall=stall+1) begin
			command_table[cmd_count]=34'b0;
			cmd_count=cmd_count+1 ;
		end
		*/
	end

   	debug_on=1;

    $display("========================================");
    $display("=   Start to read all data to test!    =");
    $display("========================================");
//===========================================
//   READ
//===========================================
	for(ra=0;ra<1;ra=ra+1) begin
		for(bb=0;bb<1;bb=bb+1) begin
			for(rr=0;rr<test_row_num;rr=rr+1) begin
				for(cc=0;cc<`TOTAL_COL;cc=cc+8)	begin


				  	rw_ctl = 1 ;//read
				  	row_addr = rr ;
				  	col_addr = cc ;
				  	bl_ctl = 1 ;

				  //	if(cc==32)
				  //	  auto_pre = 1 ;
				  //	else
				  	auto_pre = 0 ;
				  	rank = ra;
				  	bank = bb ;

					command_temp_in = 'b0;

					// Command type assignements
					command_temp_in.rank_num = rank;
					command_temp_in.r_w = rw_ctl;
					command_temp_in.none_0 = 1'b0;
					command_temp_in.row_addr = row_addr;
					command_temp_in.none_1 = 1'b0;
					command_temp_in.burst_length = bl_ctl;
					command_temp_in.none_2 = 1'b0;
					command_temp_in.auto_precharge = auto_pre;
					command_temp_in.col_addr = col_addr;
					command_temp_in.bank_addr = bank;

				    command_table[cmd_count]=command_temp_in;
				    $fdisplay(FILE1,"%34b",command_table[cmd_count]);
			    /*
			    //`ifdef PATTERN_DISP_ON
				  if(rw_ctl==0)
				    $write("PATTERN INFO. => WRITE;");
				  else
				    $write("PATTERN INFO. => READ ;");

				  $write(" ROW:%h; ",row_addr);$write(" COL:%h; ",col_addr);$write(" BANK:%h; ",bank);$write("|");

				  if(bl_ctl==0)
				    $write("Burst Legnth:4; ");
				  else
				    $write("Burst Legnth:8; ");

				  if(auto_pre==0)
				    $display("AUTO PRE:Disable \n");
				  else
				    $display("AUTO PRE:Enable \n");
				  //`endif
				   */
				  cmd_count=cmd_count+1 ;
				end
			end
		end
		/*
		for(stall=0;stall<100;stall=stall+1) begin
			command_table[cmd_count]=34'b0;
			cmd_count=cmd_count+1 ;
		end
		*/
	end

/*
  for(cmd_count=0;cmd_count<`TOTAL_CMD;cmd_count=cmd_count+1) begin
  	rw_ctl = $random ;
  	row_addr = $random ;
  	col_addr = $random ;
  	//bl_ctl = $random ;
  	bl_ctl = 1 ;
  	//auto_pre = $random ;
  	auto_pre = 0 ;
  	bank = $random ;
    command_table[cmd_count]={rw_ctl,row_addr,1'b0,bl_ctl,1'b0,auto_pre,col_addr,bank};
    $fdisplay(FILE1,"%32b",command_table[cmd_count]);

    if(rw_ctl==0) begin//write
      write_data_table[wdata_count] = {$random,$random,$random,$random,$random,$random,$random,$random} ;
      $fdisplay(FILE2,"%256b",write_data_table[wdata_count]);
      wdata_count = wdata_count + 1 ;
    end //end if

  if(rw_ctl==0)
    $write("PATTERN INFO. => WRITE;");
  else
    $write("PATTERN INFO. => READ ;");

  $write(" ROW:%h; ",row_addr);$write(" COL:%h; ",col_addr);$write(" BANK:%h; ",bank);$write("|");

  if(bl_ctl==0)
    $write("Burst Legnth:4; ");
  else
    $write("Burst Legnth:8; ");

  if(auto_pre==0)
    $display("AUTO PRE:Disable \n");
  else
    $display("AUTO PRE:Enable \n");

  end//end for
*/
 // $fclose(FILE1);
 // $fclose(FILE2);



end //end initial

initial begin
clk = 1 ;
clk2 = 1 ;
power_on_rst_n = 1 ;
valid = 0 ;

@(negedge clk) ;
power_on_rst_n = 0 ;
@(negedge clk) ;
power_on_rst_n = 1 ;

end


always@* begin
command_table_out <= command_table[i];

case(command_table_out[2:0])
  0:pm_f = ba_cmd_pm[0] ;
  1:pm_f = ba_cmd_pm[1] ;
  2:pm_f = ba_cmd_pm[2] ;
  3:pm_f = ba_cmd_pm[3] ;
endcase

end

//command output control
always@(negedge clk) begin

  if(pm_f) begin

  	if(i==`TOTAL_CMD) begin
  	  command <= 0 ;
	    i<=i ;
	    valid<=0 ;
	    write_data <= 0 ;
  	end

  	else begin
  		if(i<cmd_count) begin
	      command <= command_table[i] ;
	      i<=i+1 ;
	      valid=1 ;
	      if(command_table_out[31]==0) begin //write
	        write_data <= write_data_table[j];
	        j<=j+1 ;
	      end
	      else begin
	        write_data <= 0 ;
	        j = j ;
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
if(read_data_valid==1 && debug_on==1) begin
  //$display("time: %t mem_back rank:%h  bank:%h  row:%h  col:%h data:%h \n",$time,ra_back, bb_back,rr_back,cc_back,read_data);
  mem_back[ra_back][bb_back][rr_back][cc_back]   = read_data;
end

end

always@(negedge clk) begin
if(read_data_valid==1 && debug_on==1) begin
  if(rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-8))
    rr_back <= 0;
  else if(cc_back==(`TOTAL_COL-8))
    rr_back <= rr_back + 1 ;
  else
    rr_back <= rr_back ;
end
end

always@(negedge clk) begin
if(read_data_valid==1 && debug_on==1)
  if(cc_back==(`TOTAL_COL-8))
    //if(bb_back==3)
      cc_back <= 0 ;
    //else
    //  cc_back <= cc_back ;
  else
    //if(bb_back==3)
      cc_back <= cc_back + 8;
    //else
     // cc_back <= cc_back ;

end

always@(negedge clk) begin
if(read_data_valid==1 && debug_on==1)
  if(rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-8) && bb_back==3)
    bb_back <= 0;
  else if (rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-8))
    bb_back <= bb_back + 1;
  else
    bb_back <= bb_back;

end

always@(negedge clk) begin
if(read_data_valid==1 && debug_on==1)
  if(bb_back==3 && rr_back==(`TOTAL_ROW-1) && cc_back==(`TOTAL_COL-8))
    ra_back <= ra_back + 1;
  else
    ra_back <= ra_back;

end

always@(negedge clk) begin
if(power_on_rst_n==0) begin
  read_data_count=0;
end
else begin
  if(read_data_valid==1 && debug_on==1)
    read_data_count=read_data_count+1;
end

end


initial begin

#(`CLK_DEFINE*`TOTAL_ROW*`TOTAL_COL*5) ;
//FILE1 = $fopen("mem.txt","w");

//===========================
//    CHECK RESULT         //
//===========================
for(ra_x=0;ra_x<1;ra_x=ra_x+1)
 for(bb_x=0;bb_x<1;bb_x=bb_x+1)
  for(rr_x=0;rr_x<`TOTAL_ROW;rr_x=rr_x+1)
   for(cc_x=0;cc_x<`TOTAL_COL;cc_x=cc_x+8)


       if(mem[ra_x][bb_x][rr_x][cc_x] !== mem_back[ra_x][bb_x][rr_x][cc_x]) begin
         $display("mem[%1d][%1d][%2d][%2d] ACCESS FAIL ! , mem=%4h , mem_back=%4h",ra_x,bb_x,rr_x,cc_x,mem[ra_x][bb_x][rr_x][cc_x],mem_back[ra_x][bb_x][rr_x][cc_x]) ;
     	   total_error=total_error+1;
     	 end
     	 else
     	   $display("mem[%1d][%1d][%2d][%2d] ACCESS SUCCESS ! ",ra_x,bb_x,rr_x,cc_x) ;

$display(" TOTAL design read data: %12d",read_data_count);
$display("=====================================") ;
$display(" TOTAL_ERROR: %12d",total_error);
$display("=====================================") ;

$finish;


end
endmodule
