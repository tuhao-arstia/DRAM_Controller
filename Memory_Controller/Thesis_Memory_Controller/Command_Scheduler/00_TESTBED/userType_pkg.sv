`include "define.sv"
package frontend_command_definition_pkg;
    typedef enum logic{
        OP_READ = 1'b1,
        OP_WRITE = 1'b0
    } request_op_type_t;

    typedef enum logic{
        DATA_TYPE_WEIGHTS = 1'b0,
        DATA_TYPE_KV$ = 1'b1
    } request_data_type_t;
    
    // command definition
    typedef struct packed {
        request_op_type_t op_type;
        request_data_type_t data_type;
        logic[`ROW_ADDR_BITS-1:0] row_addr;
        logic[`COL_ADDR_BITS-1:0] col_addr;
        logic[`BANK_ADDR_BITS-1:0] bank_addr;
    } frontend_command_t;

    typedef logic[4:0] req_id_t;
    typedef logic[1:0] core_num_t; 

    // interconnection request definition
    typedef struct packed {
        frontend_command_t command;
        // Tag
        req_id_t req_id;
        core_num_t core_num;
    } frontend_interconnection_request_t;

endpackage

package command_definition_pkg;
    // read write control state
    typedef enum logic {
        TYPE_READ = 1'b1,
        TYPE_WRITE = 1'b0
    } rw_control_state_t;

    // Schedule command definition, the physical IO FSM controlled by current bank state and counters
    typedef enum logic [3:0] {
        CMD_NOP        = 4'd0,
        CMD_READ       = 4'd1,
        CMD_WRITE      = 4'd2,
        CMD_POWER_DOWN = 4'd3,
        CMD_POWER_UP   = 4'd4,
        CMD_REFRESH    = 4'd5,
        CMD_ACTIVE     = 4'd6,
        CMD_PRECHARGE  = 4'd7,
        CMD_ZQCAL      = 4'd8,
        CMD_MRS        = 4'd9,
        CMD_RESET      = 4'd10,
        CMD_LOAD_MODE  = 4'd11,
        CMD_ZQ_CALIBRATION = 4'd12
    } command_t;

    //burst length
    typedef enum logic	{
	BL_4 = 0,
	BL_8 = 1
    } burst_legnth_t;
    
    // command_scheduler command type
    typedef struct packed {
      command_t cmd;
      burst_legnth_t burst_length;
      logic[13:0] row_addr;
      logic[13:0] col_addr;
      logic[2:0] bank_addr;
    } bank_command_t;
endpackage

