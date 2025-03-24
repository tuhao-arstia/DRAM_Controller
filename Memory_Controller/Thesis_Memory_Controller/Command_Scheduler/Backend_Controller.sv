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
`include "frontend_cmd_definition_pkg.sv"

module Backend_Controller(
			   // System Clock	
               power_on_rst_n,
               clk,
               clk2,
			   // Returned Data Channel
			   i_frontend_controller_ready,
               o_backend_read_data,
               o_backend_read_data_valid,
			   // Command Channel
               o_backend_controller_ready,
               i_frontend_command_valid,
			   i_frontend_command,
               i_frontend_write_data
);

	import usertype::*;
    import frontend_command_definition_pkg::*;


    // Declare Ports

    //== I/O from System ===============
    input  power_on_rst_n;
    input  clk;
    input  clk2;
	// Returned Data Channel
	input i_frontend_controller_ready;
    output [`DQ_BITS*8-1:0]    o_backend_read_data;

    input  [`DQ_BITS*8-1:0]   i_frontend_write_data;
    input  [`FRONTEND_CMD_BITS-1:0] i_frontend_command;
	input  i_frontend_command_valid ;

    output o_backend_controller_ready;
    output o_backend_read_data_valid;
    //==================================
    //== Output to slice controller =======

	reg [`DQ_BITS*8-1:0]   o_backend_read_data;
	reg o_backend_read_data_valid;
	reg o_backend_controller_ready;

	user_command_type_t command_in;
    frontend_command_t  frontend_command_in;

    command_t command1;
    reg  valid1;
    reg   [`DQ_BITS*8-1:0]  i_frontend_write_data1;
	wire  [`DQ_BITS*8-1:0]  read_data1;
    wire ba_cmd_pm1;
    wire read_data_valid1;
   //===================================
    reg auto_precharge_flag;

	always_comb 
	begin: COMMAND_IN
		frontend_command_in = i_frontend_command;
	end

//Slice Controller Module
    Ctrl Rank0 (
               power_on_rst_n,
               clk,
               clk2,
               i_frontend_write_data1,
               command1,
               read_data1,
               valid1,
               ba_cmd_pm1,
               read_data_valid1
    );

    //Translate from frontend command to the BackendController formats
    always_comb
    begin: FRONTEND_CMD_TO_BACKEND_CMD
        
        if(frontend_command_in.op_type == OP_READ)
            command1.r_w     = READ;
        else
            command1.r_w     = WRITE;

        command1.none_0         = 1'b0;
        command1.row_addr       = frontend_command_in.row_addr;
        command1.none_1         = 1'b0;      
        command1.burst_length   = BL_8;
        command1.none_2         = 1'b0;  
        command1.auto_precharge = auto_precharge_flag; // TODO, add the auto-precharge predictor here
        command1.col_addr       = frontend_command_in.col_addr;
        command1.bank_addr      = 3'b000; // bank0
    end

always@* 
begin
	o_backend_read_data = read_data1;
	valid1 = i_frontend_command_valid;
	i_frontend_write_data1 = i_frontend_write_data;
	o_backend_controller_ready = ba_cmd_pm1;
	o_backend_read_data_valid = read_data_valid1;
end

//TODO, add the auto-precharge predictor here, 2. Add the auto-precharge predictor here
// always_comb
// begin: AUTO_PRECHARGE_PREDICTOR
//     auto_precharge_flag = 1'b1;
// end

// logic auto_precharge_flag_nxt;

// always_ff @( posedge clk or negedge power_on_rst_n ) 
// begin : ROW_POLICY_PREDICTOR
//     if(~power_on_rst_n)
//         auto_precharge_flag <= 1'b0;   
//     else
//         auto_precharge_flag <= auto_precharge_flag_nxt;
// end

always_comb
begin: AUTO_PRECHARGE_PREDICTOR
    auto_precharge_flag = 1'b0;
    
    if(frontend_command_in.col_addr == 15)
        auto_precharge_flag = 1'b0;
    else
        auto_precharge_flag = 1'b0;

end



endmodule
