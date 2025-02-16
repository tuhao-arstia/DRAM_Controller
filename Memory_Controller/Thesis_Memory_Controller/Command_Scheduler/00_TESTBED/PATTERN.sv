`include "define.sv"
`include "userType_pkg.sv"
`include "../00_TESTBED/INF.sv"

program automatic PATTERN(clk1,clk2,rst_n,init_done_flag);

output logic clk1;
output logic clk2;
output logic rst_n;
input  logic init_done_flag;

logic[31:0] SIM_CLK_CYCLE = 30000;
logic[31:0] clock_cycle = 0;

initial exe_task;
initial clock_cycle_cnt_task;
initial gen_clk;
initial gen_clk2;
// initial force_exiting_task;
//======================================
//              MAIN
//======================================
task exe_task;
    reset_task();
    wait_initialization();
    send_command();
    congratulation();
endtask

//======================================
//              TASKS
//======================================
task clock_cycle_cnt_task;
    forever begin
        clock_cycle = clock_cycle + 1;
        @(negedge clk1);
    end
endtask


task force_exiting_task;
    forever begin
        // if(clock_cycle > SIM_CLK_CYCLE)
            // $finish;
        @(negedge clk1);
    end
endtask

task reset_task;
    // reseting the ddr3
    // display
    $display("======================================");
    $display("====       Resetting the DDR3      ===");
    $display("======================================");
    rst_n = 0;
    clk1 = 0;
    clk2 = 0;

    #(`CLK_DEFINE*10) rst_n = 0;
    #(`CLK_DEFINE*10) rst_n = 1;
    $display("======================================");
    $display("====       Done Reset the DDR3     ===");
    $display("======================================");

endtask

task wait_initialization;
    // waiting for the initialization to be done
    $display("======================================");
    $display("====     WAITING INITIALIZATION    ===");
    $display("======================================");
    forever begin
        if(init_done_flag == 1'b1) // MEANING the initialization is done
            break;
        @(negedge clk1);
    end
    $display("=======================================");
    $display("====     DONE INITILIZATION         ===");
    $display("=======================================");
endtask

task gen_clk;
    forever begin
        #(`CLK_DEFINE/2.0) clk1 = ~clk1;
    end
endtask

task gen_clk2;
    forever begin
        #(`CLK_DEFINE/4.0) clk2 = ~clk2;
    end
endtask

task send_command;
    // sending the command
    $display("======================================");
    $display("====     SENDING COMMANDS          ===");
    $display("======================================");
    // sending the command
    @(negedge clk1);
endtask

task congratulation;
    $display("Congratulations! All tests passed");
    $finish;
endtask

//======================================
//              Functions
//======================================
function write_request(input logic[31:0] addr, input logic[1023:0] data);
    

endfunction


endprogram
