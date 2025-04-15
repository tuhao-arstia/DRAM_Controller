//synopsys translate_off

//synopsys translate_on

`timescale 1ns / 10ps
`include "PATTERN.sv"
`include "define.sv"
`include "MEM_PAD.sv"
`include "ddr3.sv"

`ifdef RTL
      `include "Backend_Controller.sv"
`endif
`ifdef GATE
    `include "Backend_Controller_SYN.v"
`endif

module TESTBED;

`include "2048Mb_ddr3_parameters.vh"


wire power_on_rst_n ;
wire clk ;
wire clk2 ;
wire [`FRONTEND_CMD_BITS-1:0]command ;
wire valid;
wire ba_cmd_pm ;

wire  [`COL_BITS-1:0]  col_addr  ;
wire  [`ROW_BITS-1:0]  row_addr  ;
wire  [`DQ_BITS*8-1:0]  write_data;
wire  [`DQ_BITS*8-1:0]  read_data ;
wire read_data_valid ;
wire backend_controller_ren ;

wire                ddr3_rst_n       ;
wire                ddr3_cke         ;
wire                ddr3_cs_n        ;
wire                ddr3_ras_n       ;
wire                ddr3_cas_n       ;
wire                ddr3_we_n        ;
wire [`DM_BITS-1:0] ddr3_dm_tdqs_in  ;
wire [`DM_BITS-1:0] ddr3_dm_tdqs_out ;
wire [`BA_BITS-1:0]  ddr3_ba          ;
wire [`ADDR_BITS-1:0]ddr3_addr        ;
wire [`DQ_BITS-1:0]  ddr3_data_in     ;
wire [`DQ_BITS-1:0]  ddr3_data_out    ;

wire [`DQ_BITS*8-1:0]  ddr3_data_all_in ;
wire [`DQ_BITS*8-1:0]  ddr3_data_all_out;

wire [`DQS_BITS-1:0] ddr3_dqs_in      ;
wire [`DQS_BITS-1:0] ddr3_dqs_out     ;
wire [`DQS_BITS-1:0] ddr3_dqs_n_in    ;
wire [`DQS_BITS-1:0] ddr3_dqs_n_out   ;
wire [`DQS_BITS-1:0] ddr3_tdqs_n      ;
wire ddr3_odt         ;
wire ddr3_rw          ;

wire                  pad_rst_n    ;
wire                  pad_cke      ;
wire                  pad_cs_n     ;
wire                  pad_ras_n    ;
wire                  pad_cas_n    ;
wire                  pad_we_n     ;
wire  [`DQS_BITS-1:0]  pad_dm_tdqs  ;
wire  [`BA_BITS-1:0]   pad_ba       ;
wire  [`ADDR_BITS-1:0] pad_addr     ;
wire  [`DQ_BITS-1:0] pad_dq       ;
wire  [`DQ_BITS*8-1:0] pad_dq_all   ;
wire  [`DQS_BITS-1:0]  pad_dqs      ;
wire  [`DQS_BITS-1:0]  pad_dqs_n    ;
wire  [`DQS_BITS-1:0]  pad_tdqs_n   ;
wire  pad_odt                      ;


initial begin
    `ifdef RTL
        $fsdbDumpfile("Backend_Controller.fsdb");
        $fsdbDumpvars(0,"+all");
        $fsdbDumpSVA;
    `endif
    `ifdef GATE
        $sdf_annotate("Backend_Controller_SYN.sdf", I_BackendController);
        $fsdbDumpfile("Backend_Controller_SYN.fsdb");
        $fsdbDumpvars(0,"+mda");
    `endif
end

Backend_Controller I_BackendController(
//== I/O from System ===============
         .power_on_rst_n(power_on_rst_n),
         .clk         (clk            ),
         .clk2        (clk2           ),
//==================================

//== I/O from access command =======
//Command Channel
         .o_backend_controller_ready         (ba_cmd_pm),
         .i_frontend_write_data              (write_data     ),
         .i_frontend_command_valid           (valid          ),
         .i_frontend_command                 (command        ),
//Returned data channel
         .o_backend_read_data       (read_data      ),
         .o_backend_read_data_valid (read_data_valid),
         .i_backend_controller_ren (backend_controller_ren),
//==================================
 //=== I/O from pad interface ======
         .rst_n       (ddr3_rst_n      ),
         .cke         (ddr3_cke        ),
         .cs_n        (ddr3_cs_n       ),
         .ras_n       (ddr3_ras_n      ),
         .cas_n       (ddr3_cas_n      ),
         .we_n        (ddr3_we_n       ),
         .dm_tdqs_in  (ddr3_dm_tdqs_in ),
         .dm_tdqs_out (ddr3_dm_tdqs_out),
         .ba          (ddr3_ba         ),
         .addr        (ddr3_addr       ),
         .data_in     (ddr3_data_in    ),
         .data_out    (ddr3_data_out   ),
         .data_all_in (ddr3_data_all_in    ),
         .data_all_out(ddr3_data_all_out   ),
         .dqs_in      (ddr3_dqs_in     ),
         .dqs_out     (ddr3_dqs_out    ),
         .dqs_n_in    (ddr3_dqs_n_in   ),
         .dqs_n_out   (ddr3_dqs_n_out  ),
         .tdqs_n      (ddr3_tdqs_n     ),
         .odt         (ddr3_odt        ),
         .ddr3_rw     (ddr3_rw         )
         );

MEM_PAD I_MEM_PAD(
    //== I/O for Controller ===============
         .ddr3_rst_n       (ddr3_rst_n      ),
         .ddr3_cke         (ddr3_cke        ),
         .ddr3_cs_n        (ddr3_cs_n       ),
         .ddr3_ras_n       (ddr3_ras_n      ),
         .ddr3_cas_n       (ddr3_cas_n      ),
         .ddr3_we_n        (ddr3_we_n       ),
         .ddr3_dm_tdqs_in  (ddr3_dm_tdqs_in ),
         .ddr3_dm_tdqs_out (ddr3_dm_tdqs_out),
         .ddr3_ba          (ddr3_ba         ),
         .ddr3_addr        (ddr3_addr       ),
         .ddr3_data_in     (ddr3_data_in    ),
         .ddr3_data_out    (ddr3_data_out   ),
         .ddr3_data_all_in (ddr3_data_all_in    ),
         .ddr3_data_all_out(ddr3_data_all_out   ),
         .ddr3_dqs_in      (ddr3_dqs_in     ),
         .ddr3_dqs_out     (ddr3_dqs_out    ),
         .ddr3_dqs_n_in    (ddr3_dqs_n_in   ),
         .ddr3_dqs_n_out   (ddr3_dqs_n_out  ),
         .ddr3_tdqs_n      (ddr3_tdqs_n     ),
         .ddr3_odt         (ddr3_odt        ),
         .ddr3_rw          (ddr3_rw         ),
         .ddr3_ck          (clk             ),

    //== I/O for ddr3 ===============
         .pad_rst_n  (pad_rst_n  ),
         .pad_cke    (pad_cke    ),
         .pad_cs_n   (pad_cs_n   ),
         .pad_ras_n  (pad_ras_n  ),
         .pad_cas_n  (pad_cas_n  ),
         .pad_we_n   (pad_we_n   ),
         .pad_dm_tdqs(pad_dm_tdqs),
         .pad_ba     (pad_ba     ),
         .pad_addr   (pad_addr   ),
         .pad_dq     (pad_dq     ),
         .pad_dqs    (pad_dqs    ),
         .pad_dqs_n  (pad_dqs_n  ),
         .pad_tdqs_n (pad_tdqs_n ),
         .pad_odt    (pad_odt    ),
         .pad_ck     (pad_ck     ),
         .pad_ck_n   (pad_ck_n   ),
         .pad_dq_all (pad_dq_all     )

         );

ddr3 I0_ddr3(
    .rst_n  (pad_rst_n  ),
    .ck     (pad_ck     ),
    .ck_n   (pad_ck_n   ),
    .cke    (pad_cke    ),
    .cs_n   (pad_cs_n   ),
    .ras_n  (pad_ras_n  ),
    .cas_n  (pad_cas_n  ),
    .we_n   (pad_we_n   ),
    .dm_tdqs(pad_dm_tdqs),
    .ba     (pad_ba     ),
    .addr   (pad_addr   ),
    .dq     (pad_dq     ),
    .dq_all (pad_dq_all     ),
    .dqs    (pad_dqs    ),
    .dqs_n  (pad_dqs_n  ),
    .tdqs_n (pad_tdqs_n ),
    .odt    (pad_odt    )
);


PATTERN I_PATTERN(
         .power_on_rst_n  (power_on_rst_n ),
         .clk             (clk            ),
         .clk2            (clk2           ),


         .write_data      (write_data     ),
         .read_data       (read_data      ),
         .command         (command        ),
         .valid           (valid          ),
         .ba_cmd_pm       (ba_cmd_pm ),
         .read_data_valid (read_data_valid),
         .backend_controller_ren (backend_controller_ren)
);




endmodule