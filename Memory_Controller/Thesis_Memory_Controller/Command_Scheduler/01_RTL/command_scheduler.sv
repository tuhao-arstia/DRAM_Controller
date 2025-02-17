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
    output command_t o_commands_ff,        // commands are being sent to PHY when triggered, it raises for 1 cycle
    output logic [2:0] o_mode_register_num_ff,
    output logic [`BA_BITS-1:0] o_bank_address_ff,
    output logic [`ROW_ADDR_WIDTH-1:0] o_activated_row_address_ff,
    
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
    logic[3:0]  wr_timing_cnt, act_timing_cnt, rd_timing_cnt, pre_timing_cnt,timeout_timing_cnt;
    logic[15:0] refresh_timing_cnt;
    
    // Initialization
    wire issue_cmd_flag = ~i_issue_queue_empty;
    //write
    wire tCCD_waited_flag = 
    ((wr_timing_cnt == 0 && previous_cmd_state == FSM_WR) || (rd_timing_cnt == 0 && previous_cmd_state == FSM_RD)) 
    && cmd_sch_fsm_state == FSM_WAIT_TCCD;
    wire tWTR_waited_flag = wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TWTR;
    wire tWR_waited_flag  = wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TWR;
    wire tCL_tWR_waited_flag =  wr_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TCL_TWR;
    // wr time out
    wire tCCD_timeout_flag = timeout_timing_cnt >= `CYCLE_TCCD-1 && cmd_sch_fsm_state == FSM_WR;
    wire tWTR_timeout_flag = timeout_timing_cnt >= `CYCLE_TWTR-1 && cmd_sch_fsm_state == FSM_WR;
    wire tWR_timeout_flag  = timeout_timing_cnt >= `CYCLE_TWR-1 && cmd_sch_fsm_state == FSM_WR;
    wire tCL_tWR_timeout_flag = timeout_timing_cnt >= `CYCLE_TCL_TWR-1 && cmd_sch_fsm_state == FSM_WR;

    //activation
    wire tRCD_waited_flag = act_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRCD;
    wire tRRD_waited_flag = act_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRRD;
    // act time out
    wire tRCD_timeout_flag = timeout_timing_cnt >= `CYCLE_TRCD-1 && cmd_sch_fsm_state == FSM_ACT;
    wire tRRD_timeout_flag = timeout_timing_cnt >= `CYCLE_TRRD-1 && cmd_sch_fsm_state == FSM_ACT;

    //read
    wire tRTP_waited_flag = rd_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRTP;
    wire tRTW_waited_flag = rd_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRTW;
    // read time out
    wire tRTP_timeout_flag = timeout_timing_cnt >= `CYCLE_TRTP-1 && cmd_sch_fsm_state == FSM_RD;
    wire tRTW_timeout_flag = timeout_timing_cnt >= `CYCLE_TRTW-1 && cmd_sch_fsm_state == FSM_RD;

    //Precharge
    wire tRP_waited_flag = pre_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TRP;
    wire two_NOPS_waited_flag = pre_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WAIT_TWO_NOPS;
    // pre time out
    wire tRTP_timeout_flag = timeout_timing_cnt >= `CYCLE_TRP-1 && cmd_sch_fsm_state == FSM_PRE;
    wire two_NOPS_timeout_flag = timeout_timing_cnt >= 1 && cmd_sch_fsm_state == FSM_PRE;

    //Refresh
    wire refresh_done_flag = refresh_timing_cnt == 0 && cmd_sch_fsm_state == FSM_REFRESH;

    // Time out flags, wr,act,rd,pre
    // Returns to the IDLE states when the timeout is reached
    // No need to wait for those timing constraints, if enough cycles is reached
    // The max cycles of all the timing constraints
    wire wr_time_out_flag = timeout_timing_cnt == 0 && cmd_sch_fsm_state == FSM_WR;   // max(tCCD,tWTR,tWR+tCL)
    wire act_time_out_flag = timeout_timing_cnt == 0 && cmd_sch_fsm_state == FSM_ACT; // max(tRCD,tRRD)
    wire rd_time_out_flag = timeout_timing_cnt == 0 && cmd_sch_fsm_state == FSM_RD;   // max(tCCD,tRTP,tRTW)
    wire pre_time_out_flag = timeout_timing_cnt == 0 && cmd_sch_fsm_state == FSM_PRE; // max(tRP,t2NOP)

    always_ff@(posedge clk or negedge rst_n)begin : CMD_SCHEDULER
        if(!rst_n)begin
            cmd_sch_fsm_state <= FSM_INIT;
            // Previous command state
            previous_cmd_state <= FSM_INIT;

            // Bank Timing counters
            wr_timing_cnt <= 0;
            act_timing_cnt <= 0;
            rd_timing_cnt <= 0;
            pre_timing_cnt <= 0;
            refresh_timing_cnt <= 0;
            timeout_timing_cnt <= 0;

            // Commands to PHY
            o_commands_ff <= CMD_NOP;

            //address send to phy when command is valid
            o_activated_row_address_ff <= 0;
        end else begin
            case(cmd_sch_fsm_state)
                // MAIN States
                FSM_INIT: begin
                    if(init_done_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                end
                FSM_IDLE: begin
                    // command read from the cmd issue queue
                    if(issue_cmd_flag) 
                    begin
                        case(i_issue_command.cmd)
                            CMD_READ: begin
                                cmd_sch_fsm_state <= FSM_RD;
                                o_commands_ff <= CMD_READ;
                            end
                            CMD_WRITE: begin
                                cmd_sch_fsm_state <= FSM_WR;
                                o_commands_ff <= CMD_WRITE;
                            end
                            CMD_ACTIVE: begin
                                cmd_sch_fsm_state <= FSM_ACT;
                                o_commands_ff <= CMD_ACTIVE;
                            end
                            CMD_PRECHARGE: begin
                                cmd_sch_fsm_state <= FSM_PRE;
                                o_commands_ff <= CMD_PRECHARGE;
                            end
                            CMD_REFRESH: begin
                                cmd_sch_fsm_state <= FSM_REFRESH;
                                o_commands_ff <= CMD_REFRESH;
                            end
                            default: begin
                                cmd_sch_fsm_state <= FSM_IDLE;
                            end
                        endcase
                    end

                    previous_cmd_state <= FSM_IDLE;
                    rd_timing_cnt <= 0;
                    wr_timing_cnt <= 0;
                    act_timing_cnt <= 0;
                    pre_timing_cnt <= 0;
                    refresh_timing_cnt <= 0;
                    timeout_timing_cnt <= 0;
                end
                FSM_WR: begin
                    if(tWTR_timeout_flag && tCCD_timeout_flag && tWR_timeout_flag && tCL_tWR_timeout_flag)
                    begin
                        timeout_timing_cnt <= 0;
                        cmd_sch_fsm_state <= FSM_IDLE;
                        o_commands_ff <= CMD_NOP;
                    end
                    else if(issue_cmd_flag) 
                    begin
                        case(i_issue_command.cmd)
                            CMD_READ: begin
                                if(tWTR_timeout_flag)
                                begin
                                    wr_timing_cnt <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end else begin
                                    wr_timing_cnt <= `CYCLE_TWTR;
                                    cmd_sch_fsm_state <= FSM_WAIT_TWTR;  
                                end
                            end
                            CMD_WRITE: begin
                                if(tCCD_timeout_flag) begin
                                    wr_timing_cnt <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else
                                begin
                                    wr_timing_cnt <= `CYCLE_TCCD - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TCCD;

                                    assert (timeout_timing_cnt<=`CYCLE_TCCD) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_WR");
                                end
                            end
                            CMD_PRECHARGE: begin
                                if(tWR_timeout_flag) begin
                                    wr_timing_cnt <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else
                                begin
                                    wr_timing_cnt <= `CYCLE_TWR - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TWR;

                                    assert (timeout_timing_cnt<=`CYCLE_TWR) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_WR");
                                end
                            end
                            default: begin
                                wr_timing_cnt <= 0;
                                cmd_sch_fsm_state <= FSM_IDLE;
                                // assert fatal error
                                assert(0) else $fatal("Error: Invalid command in FSM_WR");
                                // print out the current command
                                $display("Error: Invalid command in FSM_WR: %s", i_issue_command.cmd);
                            end
                        endcase
                    end

                    o_commands_ff <= CMD_NOP;
                    timeout_timing_cnt <= timeout_timing_cnt + 1;
                end
                FSM_ACT: begin
                    if(tRCD_timeout_flag && tRRD_timeout_flag)begin
                        timeout_timing_cnt <= 0;
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                    else if(issue_cmd_flag)begin
                       case(i_issue_command.cmd)
                            CMD_READ,CMD_WRITE: begin
                                if(tRCD_timeout_flag)begin
                                    act_timing_cnt    <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    act_timing_cnt    <= `CYCLE_TRCD - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TRCD;

                                    assert (timeout_timing_cnt<=`CYCLE_TRCD) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_ACT");
                                end
                            end
                            CMD_PRECHARGE: begin
                                if(tRTP_timeout_flag)begin
                                    act_timing_cnt    <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    act_timing_cnt    <= `CYCLE_TRTP - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TRTP;

                                    assert (timeout_timing_cnt<=`CYCLE_TRTP) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_ACT");
                                end
                            end
                            default: begin
                                act_timing_cnt    <= 0;
                                cmd_sch_fsm_state <= FSM_IDLE;
                                // assert fatal error
                                assert(0) else $fatal("Error: Invalid command in FSM_ACT");
                                // print out the current command
                                $display("Error: Invalid command in FSM_ACT: %s", i_issue_command.cmd);
                            end
                        endcase
                    end

                    o_commands_ff <= CMD_NOP;
                    timeout_timing_cnt <= timeout_timing_cnt + 1;
                end
                FSM_RD: begin
                    if(tRTP_timeout_flag && tRTW_timeout_flag && tCCD_timeout_flag)begin
                        timeout_timing_cnt <= 0;
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                    else if(issue_cmd_flag)begin
                        case(i_issue_command.cmd)
                            CMD_READ: begin
                                if(tCCD_timeout_flag)begin
                                    rd_timing_cnt   <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    rd_timing_cnt   <= `CYCLE_TCCD - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TCCD;
                                    previous_cmd_state <= FSM_RD;

                                    assert (timeout_timing_cnt<=`CYCLE_TCCD) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_RD");
                                end
                            end
                            CMD_WRITE: begin
                                if(tRTW_timeout_flag)begin
                                    rd_timing_cnt   <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    rd_timing_cnt   <= `CYCLE_TRTW - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TRTW;
                                    previous_cmd_state <= FSM_WR;

                                    assert (timeout_timing_cnt<=`CYCLE_TRTW) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_RD");
                                end
                            end
                            CMD_PRECHARGE: begin
                                if(tRTP_timeout_flag)begin
                                    rd_timing_cnt   <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    rd_timing_cnt   <= `CYCLE_TRTP - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TRTP;
                                    previous_cmd_state <= FSM_PRE;

                                    assert (timeout_timing_cnt<=`CYCLE_TRTP) 
                                    else   $fatal("Error: Invalid timeout_timing_cnt time in FSM_RD");
                                end
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

                    o_commands_ff <= CMD_NOP;
                    timeout_timing_cnt <= timeout_timing_cnt + 1;
                end
                FSM_PRE: begin
                    if(tRTP_timeout_flag && two_NOPS_timeout_flag)begin
                        timeout_timing_cnt <= 0;
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end
                    else if(issue_cmd_flag)begin
                        case(i_issue_command.cmd)
                            CMD_ACTIVE: begin
                                if(tRP_waited_flag)begin
                                    act_timing_cnt    <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    act_timing_cnt    <= `CYCLE_TRP
                                    cmd_sch_fsm_state <= FSM_WAIT_TRP;
                                end
                            end
                            CMD_REFRESH: begin
                                if(two_NOPS_waited_flag)begin
                                    act_timing_cnt    <= 0;
                                    cmd_sch_fsm_state <= FSM_IDLE;
                                end
                                else begin
                                    act_timing_cnt    <= 2 - timeout_timing_cnt;
                                    cmd_sch_fsm_state <= FSM_WAIT_TWO_NOPS;
                                end
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

                    o_commands_ff <= CMD_NOP;
                    timeout_timing_cnt <= timeout_timing_cnt + 1;
                end
                FSM_REFRESH: begin
                    if(refresh_done_flag) begin
                        cmd_sch_fsm_state <= FSM_IDLE;
                    end

                    o_commands_ff <= CMD_NOP;
                end
                // WAITING States
                FSM_WAIT_TCCD: begin
                    if(tCCD_waited_flag) begin
                        if(previous_cmd_state == FSM_RD) begin
                            o_commands_ff <= CMD_READ;
                            cmd_sch_fsm_state <= FSM_RD;
                        end else if(previous_cmd_state == FSM_WR) begin
                            o_commands_ff <= CMD_WRITE;
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

                    wr_timing_cnt <= wr_timing_cnt - 1;
                end
                FSM_WAIT_TWTR: begin
                    if(tWTR_waited_flag) begin
                        o_commands_ff     <= CMD_READ;
                        cmd_sch_fsm_state <= FSM_RD;
                    end

                    wr_timing_cnt <= wr_timing_cnt - 1;
                end
                FSM_WAIT_TWR: begin
                    if(tCL_tWR_waited_flag) begin
                        o_commands_ff <= CMD_PRECHARGE;
                        cmd_sch_fsm_state <= FSM_PRE;
                    end

                    //! Can only start counter only after waiting for tCL cycles
                    wr_timing_cnt <= wr_timing_cnt - 1;
                end
                FSM_WAIT_TRCD: begin
                    if(tRCD_waited_flag) begin
                        if(previous_cmd_state == FSM_RD) begin
                            o_commands_ff     <= CMD_READ;
                            cmd_sch_fsm_state <= FSM_RD;
                        end else if(previous_cmd_state == FSM_WR) begin
                            o_commands_ff     <= CMD_WRITE;
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

                    act_timing_cnt <= act_timing_cnt - 1;
                end
                FSM_WAIT_TRRD: begin
                    if(tRRD_waited_flag) begin
                        o_commands_ff    <= CMD_ACTIVE;
                        cmd_sch_fsm_state <= FSM_ACT;
                    end

                    act_timing_cnt <= act_timing_cnt - 1;
                end
                FSM_WAIT_TRTP: begin
                    if(tRTP_waited_flag) begin
                        o_commands_ff    <= CMD_PRECHARGE;
                        cmd_sch_fsm_state <= FSM_PRE;
                    end

                    rd_timing_cnt <= rd_timing_cnt - 1;
                end
                FSM_WAIT_TRTW: begin
                    if(tRTW_waited_flag) begin
                        o_commands_ff     <= CMD_WRITE;
                        cmd_sch_fsm_state <= FSM_WR;
                    end

                    rd_timing_cnt <= rd_timing_cnt - 1;
                end
                FSM_WAIT_TRP: begin
                    if(tRP_waited_flag) begin
                        o_commands_ff     <= CMD_ACTIVE;
                        cmd_sch_fsm_state <= FSM_ACT;
                    end

                    pre_timing_cnt <= pre_timing_cnt - 1;
                end
                FSM_WAIT_TWO_NOPS: begin
                    if(two_NOPS_waited_flag) begin
                        o_commands_ff     <= CMD_REFRESH;
                        cmd_sch_fsm_state <= FSM_REFRESH;
                    end

                    pre_timing_cnt <= pre_timing_cnt - 1;
                end
                default:
                    cmd_sch_fsm_state <= cmd_sch_fsm_state;
            endcase
        end
    end

    //bank address and mode register number
    always_ff @( posedge clk1 or negedge rst_n) begin :BANK_ADDRESS_MODES
        if(~rst_n)begin
            o_bank_address_ff <= 0;
            o_mode_register_num_ff <= 0;
        end else
        begin
            o_bank_address_ff <= 0;
            o_mode_register_num_ff <= 0;
        end
    end

    //refresh counter + WUPR


    //

    //======================================
    //         DATA RETURN CHANNEL
    //======================================

endmodule

// Give me a verilog function that given 2 inputs returns the max of two numbers
function [3:0] max_3_numbers;
    input [3:0] a;
    input [3:0] b;
    input [3:0] c;

    if(a > b && a > c) begin
        max_3_numbers = a;
    end else if(b > a && b > c) begin
        max_3_numbers = b;
    end else begin
        max_3_numbers = c;
    end

endfunction

// Give me a verilog function that given 3 values returns the max of 3 numbers
function [3:0] max_2_numbers;
    input [3:0] a;
    input [3:0] b;

    if(a > b) begin
        max_2_numbers = a;
    end else begin
        max_2_numbers = b;
    end
endfunction