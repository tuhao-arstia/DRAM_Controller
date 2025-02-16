`include "userType_pkg.sv"
`include "ddr3.sv"
`include "define.sv"
`include "phy_layer.sv"
`include "initialization_fsm.sv"
import command_definition_pkg::*; // Import the command definition package
import initialization_state_pkg::*; // Import the initialization state package

module init_ddr_phy_dram (
    input logic clk1,
    input logic clk2,
    input logic rst_n,
    output logic init_done_flag
);      

    // wires for ddr3
    logic dram_power_rst_n;
    logic ck;
    logic ck_n;
    logic cke;
    logic cs_n;
    logic ras_n;
    logic cas_n;
    logic we_n;

    wire [`DM_BITS-1:0] dm_tdqs;
    wire [`DQ_BITS-1:0] dq;
    wire [8*`DQ_BITS-1:0] dq_all;		//added
    wire [`DQS_BITS-1:0] dqs;
    wire [`DQS_BITS-1:0] dqs_n;
    
    logic [`BA_BITS-1:0] ba;
    logic [`ADDR_BITS-1:0] addr;
    wire [`DQS_BITS-1:0] tdqs_n;
    logic odt;

    // wires for initialization fsm
    command_t init_fsm_phy_command;
    logic[1:0] mode_register_cnt;
    init_state_t i_current_bank_state;
    logic [`ADDR_BITS-1:0] i_activated_row_addr;

    // wires for data
    // rw_control_state_t i_rw_control_state;
    logic i_rw_control_state;
    logic [`DQ_BITS-1:0] i_data_wr_phy;

    logic [`DQ_BITS-1:0] o_data_read_phy;
    logic i_data_full_write_phy;
    // logic [`IO_CNT_WIDTH-1:0] i_read_write_io_cnt;
    logic  i_read_write_io_cnt;

    // declare a phy_layer instance, from phy_layer.sv
    phy_layer phy_layer_inst (
        // Clock and Reset
        .clk1(clk1),
        .clk2(clk2),
        .rst_n(rst_n),

        // DRAM Interface
        .ck(ck),
        .ck_n(ck_n),
        .cke(cke),
        .cs_n(cs_n),
        .ras_n(ras_n),
        .cas_n(cas_n),
        .we_n(we_n),
        .dm_tdqs(dm_tdqs),
        .ba(ba),
        .addr(addr),
        .dq(dq),
        .dq_all(dq_all),
        .dqs(dqs),
        .dqs_n(dqs_n),
        .tdqs_n(tdqs_n),
        .odt(odt),

        // Initialization FSM
        .i_command(init_fsm_phy_command),
        .i_mode_register_num(mode_register_cnt),
        .i_current_bank_state(i_current_bank_state),
        .i_activated_row_addr(i_activated_row_addr),

        // Data
        .i_rw_control_state(i_rw_control_state),
        .i_data_wr_phy(i_data_wr_phy),
        .o_data_read_phy(o_data_read_phy),
        .i_data_full_write_phy(i_data_full_write_phy),
        .i_read_write_io_cnt(i_read_write_io_cnt)
    );

    // declare a dram_initialization_fsm instance, from initialization_fsm.sv
    dram_initialization_fsm dram_initialization_fsm_inst (
        .clk(clk1),
        .dram_power_rst_n(dram_power_rst_n),
        .rst_n(rst_n),
        .command_ff_o(init_fsm_phy_command),
        .initialization_done_ff_o(init_done_flag),
        .mode_register_cnt(mode_register_cnt)
    );

    // connect the phy_layer instance to the ddr3 instance
    ddr3 ddr3_inst (
        .rst_n(dram_power_rst_n),
        .ck(ck),
        .ck_n(ck_n),
        .cke(cke),
        .cs_n(cs_n),
        .ras_n(ras_n),
        .cas_n(cas_n),
        .we_n(we_n),
        .dm_tdqs(dm_tdqs),
        .ba(ba),
        .addr(addr),
        .dq(dq),
        .dq_all(dq_all),
        .dqs(dqs),
        .dqs_n(dqs_n),
        .tdqs_n(tdqs_n),
        .odt(odt)
    );

endmodule


