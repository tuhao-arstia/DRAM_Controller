`include "userType_pkg.sv"
`include "ddr3.sv"
`include "define.sv"
`include "phy_layer.sv"
`include "initialization_fsm.sv"
import command_definition_pkg::*; // Import the command definition package
import initialization_state_pkg::*; // Import the initialization state package

module test_command_scheduler (
    input logic clk1,
    input logic clk2,
    input logic rst_n,
    //initialization signal
    output logic init_done_flag,
    // command scheduler inputs
    input  logic issue_queu_empty,
    output logic issue_queue_ren,
    input  bank_command_t issue_queue_cmd,
    
    // io data channel 
    input logic [`DQ_BITS-1:0]  i_write_data,
    output logic i_write_data_ren,
    input write_data_fifo_empty,

    output logic read_data_valid,
    output logic[`DQ_BITS-1:0] read_data;
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

    //wires for command scheduler
    //command channel
    command_t cmd_scheduler_cmd;
    logic [`ADDR_BITS-1:0] cmd_scheduler_bank_addr;
    logic [`ADDR_BITS-1:0] cmd_scheduler_activated_row_addr;
    
    //data channel
    rw_control_state_t cmd_scheduler_rw_control_state_o;
    logic [`DQ_BITS-1:0] cmd_scheduler_data_o;
    logic [8*`DQ_BITS-1:0] cmd_scheduler_full_data_o;

    //wires for command channel
    logic command_t command_in_phy;
    logic [`ADDR_BITS-1:0] bank_addr_phy;
    logic [`ADDR_BITS-1:0] activated_row_addr_phy;
    logic [1:0] mode_register_phy;

    // wires for data channel
    // rw_control_state_t i_rw_control_state;
    logic i_rw_control_state;
    logic [`DQ_BITS-1:0] i_data_wr_phy;

    logic [`DQ_BITS-1:0] o_data_read_phy;
    logic i_data_full_write_phy;
    // logic [`IO_CNT_WIDTH-1:0] i_read_write_io_cnt;
    logic  i_read_write_io_cnt;

    // declare a dram_initialization_fsm instance, from initialization_fsm.sv
    dram_initialization_fsm dram_initialization_fsm_inst (
        .clk(clk1),
        .dram_power_rst_n(dram_power_rst_n),
        .rst_n(rst_n),
        .command_ff_o(init_fsm_phy_command),
        .initialization_done_ff_o(init_done_flag),
        .mode_register_cnt(mode_register_cnt)
    );

    always_comb begin : SELECTS_INIT_CMD_SCH
        if(init_done_flag) begin
            command_in_phy = issue_queue_cmd;
            bank_addr_phy = issue_queue_cmd.bank_addr;
            activated_row_addr_phy = issue_queue_cmd.row_addr;
            mode_register_phy = 0;
        end else
        begin
            command_in_phy = init_fsm_phy_command;
            bank_addr_phy = 0;
            activated_row_addr_phy = 0;
            mode_register_phy = mode_register_cnt;
        end
    end

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

        // Command channel
        .i_command(command_in_phy),
        .i_mode_register_num(mode_register_phy),
        .i_current_bank_addr(current_bank_addr_phy),
        .i_activated_row_addr(activated_row_addr_phy),

        // Data Channel
        .i_rw_control_state(i_rw_control_state),
        .i_data_wr_phy(i_data_wr_phy),
        .o_data_read_phy(o_data_read_phy),
        .i_data_full_write_phy(i_data_full_write_phy),
        .i_read_write_io_cnt(i_read_write_io_cnt)
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


