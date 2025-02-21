////////////////////////////////////////////////////////////////////////
// Project Name: eHome-IV
// Task Name   : Package
// Module Name : Package
// File Name   : Package.v
// Description : External memory interface construction
// Author      : Chih-Yuan Chang
// Revision History:
// Date        : 2013.04.06
////////////////////////////////////////////////////////////////////////

`include "define.sv"
`include "Ctrl.sv"
`include "2048Mb_ddr3_parameters.vh"
`include "Usertype.sv"


module Package(
               power_on_rst_n,
               clk,
               clk2,
			   command,
               write_data,
               read_data,
               valid,
               ba_cmd_pm,
               read_data_valid
);

	// typedef struct packed {
	// 	logic r_w;
	// 	logic none_0;
	// 	logic[`ROWB:0] row_addr;
	// 	logic none_1;
	// 	logic burst_length;
	// 	logic none_2;
	// 	logic auto_precharge;
	// 	logic[9:0] col_addr;
	// 	logic[2:0] bank_addr;
	// } command_t;
	import usertype::*;


    // Declare Ports

    //== I/O from System ===============
    input  power_on_rst_n;
    input  clk;
    input clk2;
    input  [`DQ_BITS*8-1:0]   write_data;
    output [`DQ_BITS*8-1:0]    read_data;
    input  [`USER_COMMAND_BITS-1:0] command;
	input  valid ;

    output [3:0] ba_cmd_pm; //{power_up,power_down,refresh,write,read,active}
    output read_data_valid;
    //==================================
    //== Output to slice controller =======

	reg [`DQ_BITS*8-1:0]    read_data;
	reg read_data_valid;
	reg [3:0]ba_cmd_pm ;

	user_command_type_t command_in;

    command_t command1,command2,command3,command4;
    reg  valid1,valid2,valid3,valid4;
    reg [`DQ_BITS*8-1:0]  write_data1,write_data2,write_data3,write_data4;
	wire  [`DQ_BITS*8-1:0]  read_data1,read_data2,read_data3,read_data4;
    wire [3:0] ba_cmd_pm1,ba_cmd_pm2,ba_cmd_pm3,ba_cmd_pm4; //{power_up,power_down,refresh,write,read,active}
    wire read_data_valid1,read_data_valid2,read_data_valid3,read_data_valid4;
   //===================================

	always_comb begin: COMMAND_IN
		command_in = command;
	end

//Slice Controller Module
    Ctrl Rank0 (
               power_on_rst_n,
               clk,
               clk2,
               write_data1,
               command1,
               read_data1,
               valid1,
               ba_cmd_pm1,
               read_data_valid1
    );

    Ctrl Rank1 (
               power_on_rst_n,
               clk,
               clk2,
               write_data2,
               command2,
               read_data2,
               valid2,
               ba_cmd_pm2,
               read_data_valid2
    );

    Ctrl Rank2 (
               power_on_rst_n,
               clk,
               clk2,
               write_data3,
               command3,
               read_data3,
               valid3,
               ba_cmd_pm3,
               read_data_valid3
    );

    Ctrl Rank3 (
               power_on_rst_n,
               clk,
               clk2,
               write_data4,
               command4,
               read_data4,
               valid4,
               ba_cmd_pm4,
               read_data_valid4
    );

always@* begin
case(command_in.rank_num)
  2'b00  : begin
		   command1 = command[`MEM_CTR_COMMAND_BITS-1:0] ;
		   command2 = 'b0;
		   command3 = 'b0;
		   command4 = 'b0;
		   read_data = read_data1;
		   valid1 = valid;
		   valid2 = 0;
		   valid3 = 0;
		   valid4 = 0;
		   write_data1 = write_data;
		   write_data2 = 'b0;
		   write_data3 = 'b0;
		   write_data4 = 'b0;
		   ba_cmd_pm = ba_cmd_pm1;
		   read_data_valid = read_data_valid1;
		   end
  2'b01  : begin
		   command2 = command[`MEM_CTR_COMMAND_BITS-1:0] ;
		   command1 = 'b0;
		   command3 = 'b0;
		   command4 = 'b0;
		   read_data = read_data2;
		   valid2 = valid;
		   valid1 = 0;
		   valid3 = 0;
		   valid4 = 0;
		   write_data2 = write_data;
		   write_data1 = 'b0;
		   write_data3 = 'b0;
		   write_data4 = 'b0;
		   ba_cmd_pm = ba_cmd_pm2;
		   read_data_valid = read_data_valid2;
		   end
  2'b10  : begin
		   command3 = command[`MEM_CTR_COMMAND_BITS-1:0] ;
		   command1 = 'b0;
		   command2 = 'b0;
		   command4 = 'b0;
		   read_data = read_data3;
		   valid3 = valid;
		   valid1 = 0;
		   valid2 = 0;
		   valid4 = 0;
		   write_data3 = write_data;
		   write_data1 = 'b0;
		   write_data2 = 'b0;
		   write_data4 = 'b0;
		   ba_cmd_pm = ba_cmd_pm3;
		   read_data_valid = read_data_valid3;
		   end
  2'b11  : begin
		   command4 = command[`MEM_CTR_COMMAND_BITS-1:0] ;
		   command1 = 'b0;
		   command2 = 'b0;
		   command3 = 'b0;
		   read_data = read_data4;
		   valid4 = valid;
		   valid1 = 0;
		   valid2 = 0;
		   valid3 = 0;
		   write_data4 = write_data;
		   write_data1 = 'b0;
		   write_data2 = 'b0;
		   write_data3 = 'b0;
		   ba_cmd_pm = ba_cmd_pm4;
		   read_data_valid = read_data_valid4;
		   end
  default  : begin

		   command1 = 32'b0;
		   command2 = 32'b0;
		   command3 = 32'b0;
		   command4 = 32'b0;
		   //read_data = 128'b0;
		   valid1 = 0;
		   valid2 = 0;
		   valid3 = 0;
		   valid4 = 0;
		   write_data1 = 128'b0;
		   write_data2 = 128'b0;
		   write_data3 = 128'b0;
		   write_data4 = 128'b0;
		   //ba_cmd_pm = ba_cmd_pm1;
		   //read_data_valid = read_data_valid1;
		   end
endcase
end




endmodule
