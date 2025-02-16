package command_definition_pkg;
    // Schedule command definition, the physical IO FSM controlled by current bank state and counters
    typedef enum logic [3:0] {
        CMD_NOP        = 4'd0,
        CMD_READ       = 4'd1,
        CMD_WRITE      = 4'd2,
        CMD_POWER_DOWN    = 4'd3,
        CMD_POWER_UP    = 4'd4,
        CMD_REFRESH    = 4'd5,
        CMD_ACTIVE     = 4'd6,
        CMD_PRECHARGE  = 4'd7,
        CMD_ZQCAL      = 4'd8,
        CMD_MRS        = 4'd9,
        CMD_RESET      = 4'd10,
        CMD_LOAD_MODE  = 4'd11,
        CMD_ZQ_CALIBRATION = 4'd12
    } command_t;
endpackage

package initialization_state_pkg;
    typedef enum logic [3:0] {
        FSM_POWER_UP        = 4'd0,
        FSM_RESET_PROCEDURE = 4'd1,
        FSM_WAIT_TXPR       = 4'd2,
        FSM_ZQ              = 4'd3,
        FSM_LMR             = 4'd4,
        FSM_WAIT_TDLLK      = 4'd5,
        FSM_INIT_DONE       = 4'd6,
        FSM_WAIT_TMOD       = 4'd7,
        FSM_TEST_WRITE      = 4'd8,
        FSM_NOP_BEFORE_MRS  = 4'd9,
        FSM_NOP_MRS_ZQ      = 4'd10
    }init_state_t;

endpackage