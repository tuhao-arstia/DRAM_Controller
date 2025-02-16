`include "define.sv"
`include "userType_pkg.sv"
import command_definition_pkg::*; // Import the command definition package

module command_scheduler (
    // Clock and Reset
    input logic clk1,
    input logic clk2,
    input logic rst_n,

    // Initialization signal
    input logic init_done_flag, // Indicating that the initialization is done, state machine can starts

    // CMD CHANNEL FROM ISSUE FIFO
    input bank_command_t i_issue_command,
    output o_issue_queue_ren,
    input i_issue_queue_empty,

    // DATA CHANNEL FROM DATA FIFO
    input logic [8*`DQ_BITS-1:0] i_write_data,
    output o_write_data_ren,
    input i_write_data_queue_empty,
    output logic read_data_valid,
    output logic [8*`DQ_BITS-1:0] read_data,
    
    // CMD CHANNEL TO PHY
    output bank_command_t o_commands,
    output logic [2:0] o_mode_register_num,
    output logic [`BA_BITS-1:0] o_bank_address,
    output logic [`ROW_ADDR_WIDTH-1:0] o_activated_row_address,
    
    // DATA CHANNEL FROM PHY
    output rw_control_state_t o_data_type,
    output logic [`DQ_BITS-1:0] o_write_data,
    input logic [8*`DQ_BITS-1:0] i_full_read_data,
    output logic [8*`DQ_BITS-1:0] o_full_write_data
);

    //======================================
    //             CMD CHANNEL
    //======================================
    // State machine 15 states
    typedef enum logic [3:0] {
        FSM_INIT = 4'd0,
        FSM_IDLE = 4'd1,
        FSM_WR = 4'd2,
        FSM_RD = 4'd3,
        FSM_ACT = 4'd4,
        FSM_PRE = 4'd5,
        FSM_WAIT_TCCD = 4'd6,
        FSM_WAIT_TWTR = 4'd7,
        FSM_WAIT_TRTP = 4'd8,
        FSM_WAIT_TRRD = 4'd9,
        FSM_WAIT_TRCD = 4'd10,
        FSM_WAIT_TRTW = 4'd11,
        FSM_WAIT_TRP = 4'd12,
        FSM_WAIT_TWO_NOPS = 4'd13,
        FSM_REFRESH = 4'd14,
        FSM_WAIT_TWR = 4'd15
    }cmd_sch_fsm_state_t;


    cmd_sch_fsm_state_t cmd_sch_fsm_state;
    cmd_sch_fsm_state_t previous_cmd_state;
    logic[3:0]  wr_timing_cnt, act_timing_cnt, rd_timing_cnt, pre_timing_cnt;
    logic[15:0] refresh_timing_cnt;
    
    // Initialization
    wire issue_cmd_flag = ~i_issue_queue_empty;
    //write
    wire tCCD_waited_flag = wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TCCD;
    wire tWTR_waited_flag = wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TWTR;
    wire tWR_waited_flag  = wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TWR;
    wire tCL_tWR_waited_flag =  wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TCL_TWR;
    //activation
    wire tRCD_waited_flag = act_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRCD;
    wire tRRD_waited_flag = act_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRRD;
    //read
    wire tRTP_waited_flag = rd_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRTP;
    wire tRTW_waited_flag = rd_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRTW;
    //Precharge
    wire tRTP_waited_flag = pre_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRP;
    wire two_NOPS_waited_flag = pre_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TWO_NOPS;
    //Refresh
    wire refresh_done_flag = refresh_timing_cnt == 0 && cmd_sch_fsm_state == FSM_REFRESH;

    always_ff@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cmd_sch_fsm_state <= FSM_INIT;
            previous_cmd_state <= FSM_INIT;
            wr_timing_cnt <= 0;
            act_timing_cnt <= 0;
            rd_timing_cnt <= 0;
            pre_timing_cnt <= 0;
            refresh_timing_cnt <= 0;
        end else begin
            case(cmd_sch_fsm_state)
                // MAIN States
                FSM_INIT: begin
                    if(init_done_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_IDLE: begin
                    if(issue_cmd_flag) 
                    begin
                        case(i_issue_command.cmd)
                            CMD_READ: begin
                                cmd_sch_fsm_state <= FSM_RD;
                            end
                            CMD_WRITE: begin
                                cmd_sch_fsm_state <= FSM_WR;
                            end
                            CMD_ACTIVE: begin
                                cmd_sch_fsm_state <= FSM_ACT;
                            end
                            CMD_PRECHARGE: begin
                                cmd_sch_fsm_state <= FSM_PRE;
                            end
                            CMD_REFRESH: begin
                                cmd_sch_fsm_state <= FSM_REFRESH;
                            end
                            default: begin
                                cmd_sch_fsm_state <= FSM_IDLE;
                            end
                        endcase
                    end
                end
                FSM_WR: begin
                    if(issue_cmd_flag) 
                    begin
                        case(i_issue_command.cmd)
                            CMD_READ: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TWTR;
                            end
                            CMD_WRITE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TCCD;
                            end
                            CMD_PRECHARGE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TWR;
                            end
                            default: begin
                                cmd_sch_fsm_state <= FSM_IDLE;
                                // assert fatal error
                                assert(0) else $fatal("Error: Invalid command in FSM_WR");
                                // print out the current command
                                $display("Error: Invalid command in FSM_WR: %s", i_issue_command.cmd);
                            end
                        endcase
                    end
                end
                FSM_ACT: begin
                    if(issue_cmd_flag)begin
                       case(i_issue_command.cmd)
                            CMD_READ,CMD_WRITE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TRCD;
                            end
                            CMD_PRECHARGE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TRP;
                            end
                            default: begin
                                cmd_sch_fsm_state <= FSM_IDLE;
                                // assert fatal error
                                assert(0) else $fatal("Error: Invalid command in FSM_ACT");
                                // print out the current command
                                $display("Error: Invalid command in FSM_ACT: %s", i_issue_command.cmd);
                            end
                        endcase
                    end
                end
                FSM_RD: begin
                    if(issue_cmd_flag)begin
                        case(i_issue_command.cmd)
                            CMD_READ: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TCCD;
                                previous_cmd_state <= FSM_RD;
                            end
                            CMD_WRITE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TRTW;
                            end
                            CMD_PRECHARGE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TRTP;
                            end
                            default: begin
                                cmd_sch_fsm_state <= FSM_IDLE;
                                // assert fatal error
                                assert(0) else $fatal("Error: Invalid command in FSM_RD");
                                // print out the current command
                                $display("Error: Invalid command in FSM_RD: %s", i_issue_command.cmd);
                            end
                        endcase
                    end
                end
                FSM_PRE: begin
                    if(issue_cmd_flag)begin
                        case(i_issue_command.cmd)
                            CMD_ACTIVE: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TRP;
                            end
                            CMD_REFRESH: begin
                                cmd_sch_fsm_state <= FSM_WAIT_TWO_NOPS;
                            end
                            default: begin
                                cmd_sch_fsm_state <= FSM_IDLE;
                                // assert fatal error
                                assert(0) else $fatal("Error: Invalid command in FSM_PRE");
                                // print out the current command
                                $display("Error: Invalid command in FSM_PRE: %s", i_issue_command.cmd);
                            end
                        endcase
                    end
                end
                FSM_REFRESH: begin
                    if(refresh_done_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                // WAITING States
                FSM_WAIT_TCCD: begin
                    if(tCCD_waited_flag) begin
                        if(previous_cmd_state == FSM_RD) begin
                            cmd_sch_fsm_state <= FSM_RD;
                        end else if(previous_cmd_state == FSM_WR) begin
                            cmd_sch_fsm_state <= FSM_WR;
                        end
                        else begin
                            cmd_sch_fsm_state <= FSM_IDLE;
                            // assert fatal error
                            assert(0) else $fatal("Error: Invalid previous command in FSM_WAIT_TCCD");
                            // print out the current command
                            $display("Error: Invalid previous command in FSM_WAIT_TCCD: %s", previous_cmd_state);
                        end
                    end
                end
                FSM_WAIT_TWTR: begin
                    if(tWTR_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_RD;
                    end
                end
                FSM_WAIT_TWR: begin
                    if(tCL_tWR_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_PRE;
                    end
                end
                FSM_WAIT_TRCD: begin
                    if(tRCD_waited_flag) begin
                        if(previous_cmd_state == FSM_RD) begin
                            cmd_sch_fsm_state <= FSM_RD;
                        end else if(previous_cmd_state == FSM_WR) begin
                            cmd_sch_fsm_state <= FSM_WR;
                        end
                        else begin
                            cmd_sch_fsm_state <= FSM_IDLE;
                            // assert fatal error
                            assert(0) else $fatal("Error: Invalid previous command in FSM_WAIT_TCCD");
                            // print out the current command
                            $display("Error: Invalid previous command in FSM_WAIT_TCCD: %s", previous_cmd_state);
                        end
                    end
                end
                FSM_WAIT_TRRD: begin
                    if(tRRD_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_ACT;
                    end
                end
                FSM_WAIT_TRTP: begin
                    if(tRTP_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_PRE;
                    end
                end
                FSM_WAIT_TRTW: begin
                    if(tRTW_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRP: begin
                    if(tRTP_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TWO_NOPS: begin
                    if(two_NOPS_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TWR: begin
                    if(tWR_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRAS: begin
                    if(tRAS_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRC: begin
                    if(tRC_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRFC: begin
                    if(tRFC_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRRD: begin
                    if(tRRD_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRTP: begin
                    if(tRTP_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TCCD: begin
                    if(tCCD_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TWTR: begin
                    if(tWTR_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TWR: begin
                    if(tWR_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRCD: begin
                    if(tRCD_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRRD: begin
                    if(tRRD_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_WAIT_TRTP: begin
                    if(tRTP_waited_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
            endcase
        end
    end

    //======================================
    //         DATA RETURN CHANNEL
    //======================================





endmodule