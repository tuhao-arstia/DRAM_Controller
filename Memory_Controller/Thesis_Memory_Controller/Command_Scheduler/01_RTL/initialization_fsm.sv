`include "userType_pkg.sv"
`include "define.sv"
import command_definition_pkg::*; // Import the command definition package
import initialization_state_pkg::*; // Import the initialization state package

module dram_initialization_fsm(
    input  logic clk,
    input  logic rst_n,
    output logic dram_power_rst_n,
    output command_t command_ff_o, // Example: Command width (adjust as needed)
    output logic initialization_done_ff_o,
    output logic[1:0] mode_register_cnt
);

    init_state_t state;
    logic[31:0] initialization_cnt;
    logic nop_gen_flag;

    //Initialization elays parameters
    localparam  POWER_UP_200US_DELAY = 200000;        // Power up requires 200US/1ns = 200,000
    localparam  RESET_PROCEDURE_500US_DELAY = 500000; // Reset procedure requires 500US
    localparam  WAIT_TXPR_DELAY = 243; // 243ns (tXPR)             
    localparam  TZQ_INIT_DELAY = 512;  // 512ns (tZQINIT)
    localparam  WAIT_TDLLK_DELAY = 1;
    localparam  tMRD_DELAY = 5;  // MIN = 4CK 
    localparam  tMOD_DELAY = 20; // MIN = greater of 12CK or 15ns
    
    wire power_on_done_flag = initialization_cnt == POWER_UP_200US_DELAY && state == FSM_POWER_UP;
    wire reset_done_flag = initialization_cnt == RESET_PROCEDURE_500US_DELAY && state == FSM_RESET_PROCEDURE;
    wire wait_txpr_done_flag = initialization_cnt == WAIT_TXPR_DELAY && state == FSM_WAIT_TXPR;
    wire zq_done_flag = initialization_cnt == TZQ_INIT_DELAY && state == FSM_ZQ;
    wire lmr_done_flag = mode_register_cnt == 4'd3 && state == FSM_LMR;
    wire wait_tdllk_done_flag = initialization_cnt == WAIT_TDLLK_DELAY && state == FSM_WAIT_TDLLK;
    wire mode_register_set_flag = initialization_cnt == tMRD_DELAY && state == FSM_LMR;
    wire all_mode_register_set_flag = mode_register_cnt == 4'd3 && state == FSM_LMR;
    wire wait_tmod_done_flag = initialization_cnt == tMOD_DELAY && state == FSM_WAIT_TMOD;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= FSM_POWER_UP;
            initialization_cnt <= 16'd0;
            command_ff_o <= CMD_POWER_UP;
            initialization_done_ff_o <= 1'b0;
            mode_register_cnt <= 2'd0;
            dram_power_rst_n <= 1'b0;
            nop_gen_flag <= 1'b0;
        end else begin
            case(state)
                FSM_POWER_UP:
                begin
                    if(power_on_done_flag) begin
                        state <= FSM_RESET_PROCEDURE;
                        initialization_cnt <= 16'd0;
                        dram_power_rst_n <= 1'b1;
                        command_ff_o <= CMD_POWER_UP;
                    end else begin
                        state <= FSM_POWER_UP;
                        initialization_cnt <= initialization_cnt + 16'd1;
                        dram_power_rst_n <= 1'b0;
                        command_ff_o <= CMD_POWER_UP;
                    end
                end
                FSM_RESET_PROCEDURE:
                begin
                    if(reset_done_flag) begin
                        state <= FSM_WAIT_TXPR;
                        initialization_cnt <= 16'd0;
                        command_ff_o <= CMD_RESET;
                    end else begin
                        state <= FSM_RESET_PROCEDURE;
                        initialization_cnt <= initialization_cnt + 16'd1;
                        command_ff_o <= CMD_RESET;
                    end
                end
                FSM_WAIT_TXPR: begin
                    if(wait_txpr_done_flag) begin
                        state <= FSM_LMR;
                        initialization_cnt <= 16'd0;
                        command_ff_o <= CMD_NOP;
                    end else begin
                        state <= FSM_WAIT_TXPR;
                        initialization_cnt <= initialization_cnt + 16'd1;
                        command_ff_o <= CMD_NOP;
                    end
                end
                FSM_LMR: begin
                    if(all_mode_register_set_flag && mode_register_set_flag) begin
                        state <= FSM_WAIT_TMOD;
                        initialization_cnt <= 16'd0;
                        nop_gen_flag <= 1'b0;
                        command_ff_o <= CMD_NOP;
                    end else if(mode_register_set_flag) begin
                        mode_register_cnt <= mode_register_cnt + 2'd1;
                        state <= FSM_LMR;
                        initialization_cnt <= 16'd0;
                        command_ff_o <= CMD_NOP;
                        nop_gen_flag <= 1'b0;
                    end else begin
                        state              <= FSM_LMR;
                        initialization_cnt <= initialization_cnt + 16'd1;
                        command_ff_o <= (nop_gen_flag == 1'b0)  ? CMD_MRS : CMD_NOP; // NOP must be included between MRS commands
                        nop_gen_flag <= 1'b1; // To ensure only one cycle CMD_MRS is issued
                    end
                end
                FSM_WAIT_TMOD: begin
                    if(wait_tmod_done_flag) begin
                        state <= FSM_ZQ;
                        initialization_cnt <= 16'd0;
                        command_ff_o <= CMD_NOP;
                    end else begin
                        state <= FSM_WAIT_TMOD;
                        initialization_cnt <= initialization_cnt + 16'd1;
                        command_ff_o <= CMD_NOP;
                    end
                end
                FSM_ZQ: begin
                    if(zq_done_flag) begin
                        state <= FSM_INIT_DONE;
                        initialization_cnt <= 16'd0;
                        command_ff_o <= CMD_NOP;
                        nop_gen_flag <= 1'b0;
                    end else begin
                        state <= FSM_ZQ;
                        initialization_cnt <= initialization_cnt + 16'd1;
                        command_ff_o <=(nop_gen_flag == 1'b0) ? CMD_ZQCAL : CMD_NOP; // NOP must be included after ZQCAL
                        nop_gen_flag <= 1'b1; // To ensure one cycle CMD_ZQCAL
                    end
                end
                FSM_INIT_DONE: begin
                    state <= FSM_INIT_DONE;
                    initialization_done_ff_o <= 1'b1;
                end
                default: begin
                    state <= FSM_POWER_UP;
                end
            endcase
        end
    end
endmodule
