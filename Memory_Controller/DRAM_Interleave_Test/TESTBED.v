//synopsys translate_off

//synopsys translate_on

`timescale 1ns / 10ps
`include "PATTERN.v"
`include "Package.v"
`include "ddr3.v"



module TESTBED;

`include "2048Mb_ddr3_parameters.vh"




wire power_on_rst_n ;
wire clk ;
wire clk2 ;
wire [33:0]command ;
wire valid;
wire [3:0]ba_cmd_pm ;

wire  [BA_BITS-1:0]    bank      ;
wire  [ADDR_BITS-1:0]  col_addr  ;
wire  [ADDR_BITS-1:0]  row_addr  ;
wire  [DQ_BITS*8-1:0]  write_data;
wire  [DQ_BITS*8-1:0]  read_data ;
wire read_data_valid ;


initial begin
	$fsdbDumpfile("Package.fsdb");
    $fsdbDumpvars(0,"+all");
    $fsdbDumpSVA;
end


Package I_Package(
//== I/O from System ===============
         .power_on_rst_n(power_on_rst_n),
         .clk         (clk            ),
         .clk2        (clk2           ),
//==================================

//== I/O from access command =======
         .write_data      (write_data     ),
         .read_data       (read_data      ),
         .command         (command        ),
         .valid           (valid          ),
         .ba_cmd_pm  (ba_cmd_pm ),
         .read_data_valid (read_data_valid)
//================================== 
              
         );


PATTERN I_PATTERN(
         .power_on_rst_n  (power_on_rst_n ),
         .clk             (clk            ),
         .clk2            (clk2           ),
       //  .bank            (bank           ),
       //  .col_addr        (col_addr       ),
       //  .row_addr        (row_addr       ),
         .write_data      (write_data     ),
         .read_data       (read_data      ),
         .command         (command        ),
         .valid           (valid          ),
         .ba_cmd_pm  (ba_cmd_pm ),
         .read_data_valid (read_data_valid)
);

endmodule
