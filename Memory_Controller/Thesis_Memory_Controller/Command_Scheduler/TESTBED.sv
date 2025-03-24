//synopsys translate_off

//synopsys translate_on

`timescale 1ns / 10ps
`include "PATTERN.sv"
`include "Backend_Controller.sv"
`include "define.sv"
`include "ddr3.sv"



module TESTBED;

`include "2048Mb_ddr3_parameters.vh"


wire power_on_rst_n ;
wire clk ;
wire clk2 ;
wire [`FRONTEND_CMD_BITS-1:0]command ;
wire valid;
wire ba_cmd_pm ;

wire  [`COL_BITS-1:0]  col_addr  ;
wire  [`ROW_BITS-1:0]  row_addr  ;
wire  [`DQ_BITS*8-1:0]  write_data;
wire  [`DQ_BITS*8-1:0]  read_data ;
wire read_data_valid ;


initial begin
	$fsdbDumpfile("Package.fsdb");
      $fsdbDumpvars(0,"+all");
      $fsdbDumpSVA;
end


Backend_Controller I_BackendController(
//== I/O from System ===============
         .power_on_rst_n(power_on_rst_n),
         .clk         (clk            ),
         .clk2        (clk2           ),
//==================================

//== I/O from access command =======
//Command Channel
         .o_backend_controller_ready         (ba_cmd_pm),
         .i_frontend_write_data              (write_data     ),
         .i_frontend_command_valid           (valid          ),
         .i_frontend_command                 (command        ),
//Returned data channel
         .o_backend_read_data       (read_data      ),
         .o_backend_read_data_valid (read_data_valid)
//==================================
         );


PATTERN I_PATTERN(
         .power_on_rst_n  (power_on_rst_n ),
         .clk             (clk            ),
         .clk2            (clk2           ),


         .write_data      (write_data     ),
         .read_data       (read_data      ),
         .command         (command        ),
         .valid           (valid          ),
         .ba_cmd_pm  (ba_cmd_pm ),
         .read_data_valid (read_data_valid)
);

endmodule
