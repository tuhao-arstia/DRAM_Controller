
`include "define.sv"


`define TOTAL_CMD 20000

`define TOTAL_ROW 16  //4bit
`define TOTAL_COL 64  //6bit
`define TEST_ROW_WIDTH 4
`define TEST_COL_WIDTH 6
`define TEST_BA_WIDTH 3

`define PATTERN_NUM 30000

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

//== I/O from System ===============
output  power_on_rst_n;
output  clk  ;
output  clk2 ;
//==================================
//== I/O from access command =======

output  [DQ_BITS*8-1:0]   write_data;
output  [33:0] command;
output  valid;
input   [DQ_BITS*8-1:0]   read_data;
input   [7:0] ba_cmd_pm;
input read_data_valid;
//==================================

reg  power_on_rst_n;
reg  clk;
reg  clk2;

reg  [DQ_BITS*8-1:0]   write_data;
reg  [33:0] command;
//command format = {read/write , row_addr , col_addr , bank } ;
//                  [31]         [30:17]    [16:3]     [2:0]

reg  valid;

always #(`CLK_DEFINE/2.0) clk = ~clk ;
always #(`CLK_DEFINE/4.0) clk2 = ~clk2 ;

reg [33:0]command_table[`TOTAL_CMD-1:0];

reg [DQ_BITS*8-1:0]write_data_table[`TOTAL_CMD-1:0];
reg pm_f;

reg rw_ctl ; //0:write ; 1:read
reg [12:0]row_addr;
reg [9:0]col_addr;
reg bl_ctl;
reg auto_pre;
reg [2:0]bank;
reg [1:0]rank;

integer i=0,j=0,k=0;
integer read_data_count,random_rw_num;
integer FILE1,FILE2,cmd_count,wdata_count ;

integer ra,rr,cc,bb,bb_x,rr_x,cc_x,ra_x;
integer total_error=0;
reg [33:0]command_t ;

reg [127:0]mem[1:0][2:0][`TOTAL_ROW-1:0][`TOTAL_COL-1:0] ; //[rank][bank][row][col];
reg [127:0]mem_back[1:0][2:0][`TOTAL_ROW-1:0][`TOTAL_COL-1:0] ; //[rank][bank][row][col];

reg [DQ_BITS*8-1:0]write_data_temp ;
reg [DQ_BITS-1:0]write_data_tt ;
reg [DQ_BITS-1:0]read_data_tt ;

reg [31:0]bb_back,rr_back,cc_back;
reg [1:0] ra_back;
reg ran_rw;
reg [`TEST_ROW_WIDTH-1:0]ran_row;
reg [`TEST_COL_WIDTH-1:0]ran_col;
reg [`TEST_BA_WIDTH-1:0]ran_ba;
reg [`TEST_COL_WIDTH-3-1:0]ran_col_div_8;
reg debug_on;

initial begin
FILE1 = $fopen("pattern_cmd.txt","w");
FILE2 = $fopen("pattern_wdata.txt","w");
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
 
//===========================================
//   WRITE
//===========================================  
    $display("========================================");
    $display("= Start to write the initial data!     =");
    $display("========================================");
	for(ra=0;ra<1;ra=ra+1) begin
		for(rr=0;rr<`TOTAL_ROW;rr=rr+1) begin
			for(cc=0;cc<`TOTAL_COL;cc=cc+8) begin	
				for(bb=0;bb<4;bb=bb+1) begin

				  	rw_ctl = 0 ;//write
				  	row_addr = rr ;
				  	col_addr = cc ;
				  	bl_ctl = 1 ;
				  	
				 // 	if(cc==32)
				 // 	  auto_pre = 1 ;
				 // 	else
				  	  auto_pre = 0 ;
				  	rank = ra ; 
				  	bank = bb ;
				    command_table[cmd_count]={rank,rw_ctl,1'b0,row_addr,1'b0,bl_ctl,1'b0,auto_pre,col_addr,bank};
				    $fdisplay(FILE1,"%34b",command_table[cmd_count]);
				        
				    if(rw_ctl==0) begin//write
				      write_data_table[wdata_count] = {$random,$random,$random,$random} ;  
				      write_data_temp = write_data_table[wdata_count] ;
				      write_data_tt[0] = write_data_temp[31:0] ;
				      write_data_tt[1] = write_data_temp[63:32] ;
				      write_data_tt[2] = write_data_temp[95:64] ;
				      write_data_tt[3] = write_data_temp[127:96] ;
				      $fdisplay(FILE2,"%128b",write_data_table[wdata_count]);
					 
				      //`ifdef PATTERN_DISP_ON
				      $write("PATTERN INFO. => WRITE;"); $write("COMMAND # %d; ",cmd_count);
				        
				      $write(" ROW:%h; ",row_addr);$write(" COL:%h; ",col_addr);$write(" BANK:%h; ",bank);$write(" RANK:%h; ",rank);$write("|");
				      
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
			end//end for
		end
	end
	
	
//===========================================
//   Random read/write
//===========================================

/*
    $display("========================================");
    $display("= Start to input the random pattern!   =");
    $display("========================================");
    
    for(random_rw_num=0;random_rw_num<`PATTERN_NUM;random_rw_num=random_rw_num+1) begin
      
      ran_rw=$random;
      ran_col_div_8=$random;
      ran_col={ran_col_div_8,3'd0};//*8
   
      ran_row=$random;
      
      ran_ba=$random;
      //$display("  Pattern No. %d --> RW:%b ; ROW:%h ; COL:%h ; BA:%d ",random_rw_num,ran_rw,ran_row,ran_col,ran_ba);
      bl_ctl = 1 ;
			// 	if(cc==32)
			// 	  auto_pre = 1 ;
			// 	else
			 	  auto_pre = 0 ;

			row_addr = 0 ;
			col_addr = 0 ;			  				  	  
			bank = 0 ;
			row_addr=ran_row;
			col_addr=ran_col;
			bank=ran_ba;
			
			command_table[cmd_count]={ran_rw,1'b0,row_addr,1'b0,bl_ctl,1'b0,auto_pre,col_addr,bank};
      
      if(ran_rw==0) begin//write

			  write_data_table[wdata_count] = {$random,$random,$random,$random} ;  
			  write_data_temp = write_data_table[wdata_count] ;
			  write_data_tt[0] = write_data_temp[31:0] ;
			  write_data_tt[1] = write_data_temp[63:32] ;
			  write_data_tt[2] = write_data_temp[95:64] ;
			  write_data_tt[3] = write_data_temp[127:96] ;
			  //$fdisplay(FILE2,"%128b",write_data_table[wdata_count]);
			  
			  $display("Write data : ");
			  for(k=0;k<8;k=k+1) begin
			    $write(" %4h ",write_data_temp[15:0]);
			    mem[bank][row_addr][col_addr+k] = write_data_temp[15:0] ;
			    write_data_temp=write_data_temp>>16;
			  end
			  $display(" ");
			           
			  wdata_count = wdata_count + 1 ;
      end    
      
      cmd_count=cmd_count+1 ;


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
			
    //$display("test A \n");
    end
    
   $display("test B \n"); 
   */
   wait(i==cmd_count-1);
   #(`CLK_DEFINE*1000);
   debug_on=1;
   
    $display("========================================");
    $display("=   Start to read all data to test!    =");
    $display("========================================");
//===========================================
//   READ
//===========================================
	for(ra=0;ra<1;ra=ra+1) begin
		for(rr=0;rr<`TOTAL_ROW;rr=rr+1) begin
			for(cc=0;cc<`TOTAL_COL;cc=cc+8)	begin
				for(bb=0;bb<4;bb=bb+1) begin
		  	
		  		
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
				    command_table[cmd_count]={rank,rw_ctl,1'b0,row_addr,1'b0,bl_ctl,1'b0,auto_pre,col_addr,bank};
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
			end//end for
		end	  
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
command_t <= command_table[i];

case(command_t[2:0])
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
	      if(command_t[31]==0) begin //write
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
    command <= 34'd0 ;
    i<=i ;
    valid=0 ;
  end
end

//read data receive control

always@(negedge clk) begin

	
if(read_data_valid==1 && debug_on==1) begin
  $display("time: %t mem_back rank:%h  bank:%h  row:%h  col:%h data:%h \n",$time,ra_back, bb_back,rr_back,cc_back,read_data);
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
		
#(`CLK_DEFINE*15000) ;
//FILE1 = $fopen("mem.txt","w");

//===========================
//    CHECK RESULT         //
//===========================
for(ra_x=0;ra_x<1;ra_x=ra_x+1)
 
  for(rr_x=0;rr_x<`TOTAL_ROW;rr_x=rr_x+1)
   for(cc_x=0;cc_x<`TOTAL_COL;cc_x=cc_x+8)
    for(bb_x=0;bb_x<4;bb_x=bb_x+1)
     
      
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


