`timescale 1ns / 10ps
`include "PATTERN.sv"
`include "ddr3.sv"
`include "../01_RTL/init_ddr_phy_dram.sv"
`include "../00_TESTBED/INF.sv"

module TESTBED;

`include "2048Mb_ddr3_parameters.vh"

import command_definition_pkg::*;
import initialization_state_pkg::*;

INIT_PHY intf(); 

initial begin
	$fsdbDumpfile("initialization.fsdb");
    $fsdbDumpvars(0,"+all");
    $fsdbDumpSVA;
end

// Instantiate the init_ddr_phy_dram module
init_ddr_phy_dram init_ddr_phy_dram_inst (
    .clk1(intf.clk1),
    .clk2(intf.clk2),
    .rst_n(intf.rst_n),
    .init_done_flag(intf.init_ddr_phy_dram_done)
);

// connect it with the pattern
PATTERN pattern_inst (
    .clk1(intf.clk1),
    .clk2(intf.clk2),
    .rst_n(intf.rst_n),
    .init_done_flag(intf.init_ddr_phy_dram_done)
);

endmodule
