`include "userType_pkg.sv"
import command_definition_pkg::*; // Import the command definition package
import initialization_state_pkg::*; // Import the initialization state package
module phy_layer (
    // Additional Input/Output Ports
    input   logic clk1,                         // Additional clock signal
    input   logic clk2,                         // Additional clock signal
    input   logic rst_n,
    // DRAM Interface Ports
    output   logic ck,
    output   logic ck_n,
    output   logic cke,
    output   logic cs_n,
    output   logic ras_n,
    output   logic cas_n,
    output   logic we_n,
    inout    [`DM_BITS-1:0]   dm_tdqs,
    output   logic [`BA_BITS-1:0]   ba,
    output   logic [`ADDR_BITS-1:0] addr,
    inout    [`DQ_BITS-1:0]   dq,
    inout    [8*`DQ_BITS-1:0] dq_all,        // Added
    inout    [`DQS_BITS-1:0]  dqs,
    inout    [`DQS_BITS-1:0]  dqs_n,
    input   logic [`DQS_BITS-1:0]  tdqs_n,
    output   logic odt,

    // Interface with command scheduler and intialization FSM
    input   command_t i_command, // Input command signal
    input   [1:0]     i_mode_register_num,
    input   logic [`BANK_STATE_WIDTH-1:0] i_current_bank_addr, // Current bank address
    input   logic [`ROW_ADDR_WIDTH-1:0] i_activated_row_addr,   // Activated row address

    // Interface with data controls
    input   logic [`RW_CONTROL_WIDTH-1:0] i_rw_control_state,   // Read/Write control state
    input   logic [`DATA_WIDTH-1:0] i_data_wr_phy,             // Data for write PHY
    output  logic [`DATA_WIDTH-1:0] o_data_read_phy,           // Data from read PHY
    input   logic i_data_full_write_phy,                      // Full write PHY data path
    input   logic [`IO_CNT_WIDTH-1:0] i_read_write_io_cnt      // Read/Write IO counter
);

assign ck = clk1;
assign ck_n = ~clk1;

//====================================================
//MODE REGISTER
//====================================================
logic [15:0]MR0,MR1,MR2,MR3 ;
always_ff @(posedge clk1 or negedge rst_n) begin
    if(!rst_n) begin
        MR0 <= 16'h0000;
        MR1 <= 16'h0000;
        MR2 <= 16'h0000;
        MR3 <= 16'h0000;
    end else begin
        MR0 <= `MR0_CONFIG;
        MR1 <= `MR1_CONFIG;
        MR2 <= `MR2_CONFIG;
        MR3 <= `MR3_CONFIG;
    end
end

//====================================================
//COMMAND PHY
//====================================================
// {cke,cs_n,ras_n,cas_n,we_n}
always@(negedge clk1) begin: DRAM_PHY_CK_CS_RAS_CAS_WE
  case(i_command)
    CMD_POWER_UP : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_POWER_UP ;
    CMD_ZQCAL    : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_ZQ_CALIBRATION ;
    CMD_MRS      : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_LOAD_MODE ;
    CMD_RESET    : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_RESET ;
    CMD_NOP      : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_NOP ;
    CMD_WRITE    : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_WRITE ;

    // FSM_ACTIVE   : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_ACTIVE ;
    // FSM_READ     : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_READ ;
    // FSM_PRE      : {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_PRECHARGE ;
    default :       {cke,cs_n,ras_n,cas_n,we_n} <= `CMD_POWER_UP;
  endcase
end

always@(negedge clk1) begin: DRAM_PHY_ADDR
    case(i_command)
        CMD_POWER_UP : addr <= 16'h0000; // Example address for power up
        CMD_ZQCAL    : addr <= 1024;     // A10 = 1 for ZQ calibration
        CMD_MRS      : 
            case(i_mode_register_num)
                0 : addr <= MR0;      // Load mode register 0
                1 : addr <= MR1;      // Load mode register 1
                2 : addr <= MR2;      // Load mode register 2
                3 : addr <= MR3;      // Load mode register 0
            endcase
        CMD_RESET    : addr <= 16'h0000; // Example address for reset

        // FSM_ACTIVE   : addr <= act_addr;
        // FSM_READ     : addr <= act_addr;
        // FSM_WRITE    : addr <= act_addr;
        // FSM_PRE      : addr <= act_addr;
        default : addr <= addr;
    endcase
end

always@(negedge clk1) begin: DRAM_PHY_BA
    case(i_command)
        CMD_POWER_UP : ba <= 0;
        CMD_ZQCAL    : ba <= 0;
        CMD_MRS      : 
            case(i_mode_register_num)
                0 : ba <= 0;
                1 : ba <= 1;
                2 : ba <= 2;
                3 : ba <= 3;
                default : ba <= 0;
            endcase
        CMD_RESET    : ba <= 0;

        // FSM_ACTIVE   : ba <= act_bank;
        // FSM_READ     : ba <= act_bank;
        // FSM_WRITE    : ba <= act_bank;
        // FSM_PRE      : ba <= act_bank;
        default : ba <= ba;
    endcase
end

//====================================================
//DATA PHY
//====================================================
// connect all other signal to ground first
assign dq_all = 0;
assign dq = 0;
assign dqs = 0;
assign dqs_n = 0;
assign dm_tdqs = 0;
assign odt = 0;




endmodule
