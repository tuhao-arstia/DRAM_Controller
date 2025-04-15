////////////////////////////////////////////////////////////////////////
// Project Name: 3D_DRAM_Backend_Controller
// Task Name   : Backend_Controller
// Module Name : Backend_Controller
// File Name   : Backend_Controller.sv
// Author      : YEH SHUN-LIANG
// Revision History:
// Date        : 2025/04/01
////////////////////////////////////////////////////////////////////////

`include "define.sv"
`include "Ctrl.sv"
`include "Usertype.sv"
`include "frontend_cmd_definition_pkg.sv"

//synopsys translate_off
`include "2048Mb_ddr3_parameters.vh"
//synopsys translate_on

module Backend_Controller(
			   // System Clock
               power_on_rst_n,
               clk,
               clk2,
               //=== Interface with frontend Scheduler ===
			   // Returned Data Channel
			   i_frontend_controller_ready,
               o_backend_read_data,
               o_backend_read_data_valid,
               i_backend_controller_ren,

               // Command Channel
               o_backend_controller_ready,
               i_frontend_command_valid,
			   i_frontend_command,

               // Wdata Channel
               i_frontend_write_data,

               //=== I/O from DDR3 interface ======
               rst_n,
               cke,
               cs_n,
               ras_n,
               cas_n,
               we_n,
               dm_tdqs_in,
               dm_tdqs_out,
               ba,
               addr,
               data_in,
               data_out,
               data_all_in,
               data_all_out,
               dqs_in,
               dqs_out,
               dqs_n_in,
               dqs_n_out,
               tdqs_n,
               odt,
               ddr3_rw

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
    input  i_backend_controller_ren;

    output o_backend_controller_ready;
    output o_backend_read_data_valid;

    //== I/O from DDR3 interface ======
    output wire   rst_n;
    output wire   cke;
    output wire   cs_n;
    output wire   ras_n;
    output wire   cas_n;
    output wire   we_n;

    input[`DM_BITS-1:0]  dm_tdqs_in;
    output[`DM_BITS-1:0] dm_tdqs_out;

    output[`BA_BITS-1:0] ba;
    output[`ADDR_BITS-1:0] addr;

    input [`DQ_BITS-1:0] data_in;
    output [`DQ_BITS-1:0] data_out;

    input [`DQ_BITS*8-1:0] data_all_in;
    output [`DQ_BITS*8-1:0] data_all_out;

    input[`DQS_BITS-1:0] dqs_in;
    output[`DQS_BITS-1:0] dqs_out;

    input[`DQS_BITS-1:0] dqs_n_in;
    output[`DQS_BITS-1:0] dqs_n_out;

    input[`DQS_BITS-1:0] tdqs_n;
    output wire odt;
    output wire ddr3_rw;

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

    // help me use port connection to connect ths signals
    Ctrl Rank0(
        //IO from system
        .power_on_rst_n(power_on_rst_n),
        .clk(clk),
        .clk2(clk2),
        //IO from frontend scheduler
        .write_data(i_frontend_write_data1),
        .i_command(command1),
        .read_data(read_data1),
        .valid(valid1),
        .ba_cmd_pm(ba_cmd_pm1),
        .read_data_valid(read_data_valid1),
        .i_controller_ren(i_backend_controller_ren),
        //IO to DDR3 interface
        .rst_n(rst_n),
        .cke(cke),
        .cs_n(cs_n),
        .ras_n(ras_n),
        .cas_n(cas_n),
        .we_n(we_n),
        .dm_tdqs_in(dm_tdqs_in),
        .dm_tdqs_out(dm_tdqs_out),
        .ba(ba),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .data_all_in(data_all_in),
        .data_all_out(data_all_out),
        .dqs_in(dqs_in),
        .dqs_out(dqs_out),
        .dqs_n_in(dqs_n_in),
        .dqs_n_out(dqs_n_out),
        .tdqs_n(tdqs_n),
        .odt(odt),
        .ddr3_rw(ddr3_rw)
    );


//====================================================
//  CMD translation from frontend to backend
//====================================================
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
        command1.auto_precharge = auto_precharge_flag;
        command1.col_addr       = frontend_command_in.col_addr;
        command1.bank_addr      = 3'b000; // bank0
    end

always_comb
begin
	o_backend_read_data = read_data1;
	valid1 = i_frontend_command_valid;
	i_frontend_write_data1 = i_frontend_write_data;
	o_backend_controller_ready = ba_cmd_pm1;
	o_backend_read_data_valid = read_data_valid1;
end

//====================================================
//  LLM Access Aware Row Policy Predictor (a)
//====================================================
// Key idea: Use the last slot of column to close the row and predicts whether the current row should be closed or not
// Due to data type access, Instruction, Weights & KV$, determine the optimal row policy for different data type
// Through the given data types, we can determine the row policy by analyzing the access traces
always_comb
begin: AUTO_PRECHARGE_PREDICTOR
    auto_precharge_flag = 1'b0;

    // Due to sequential access, the last slot of column can be closed
    if(frontend_command_in.col_addr == 15)
        auto_precharge_flag = 1'b1;
    else
        auto_precharge_flag = 1'b0;

end


endmodule