module Backend_Controller_TOP(
    // System Clock
    power_on_rst_n,
    clk,
    clk2,
    //=== Interface with frontend Scheduler ===
    // Returned Data Channel
    i_frontend_controller_ready,
    o_backend_read_data,
    i_backend_controller_stall,
    o_backend_read_data_valid,

    // Command Channel
    o_backend_controller_ready,
    i_frontend_command_valid,
    i_frontend_command,

    // Wdata Read Channel
    i_frontend_write_data,
    o_backend_controller_ren,

    //=== I/O to interface ======
    pad_rst_n  ,
    pad_cke    ,
    pad_cs_n   ,
    pad_ras_n  ,
    pad_cas_n  ,
    pad_we_n   ,
    pad_dm_tdqs,
    pad_ba     ,
    pad_addr   ,
    pad_dq     ,
    pad_dq_all,
    pad_dqs    ,
    pad_dqs_n  ,
    pad_tdqs_n ,
    pad_odt    ,
    pad_ck     ,
    pad_ck_n
);

    // Declare Ports
    //== I/O from System ===============
    input  power_on_rst_n;
    input  clk;
    input  clk2;
	// Returned Data Channel
	input                      i_frontend_controller_ready;
    output [`DQ_BITS*8-1:0]    o_backend_read_data;

    input  [`DQ_BITS*8-1:0]   i_frontend_write_data;
    input  [`FRONTEND_CMD_BITS-1:0] i_frontend_command;
	input  i_frontend_command_valid ;
    input  i_backend_controller_stall;

    output o_backend_controller_ready;
    output o_backend_read_data_valid;
    output o_backend_controller_ren;

    output   pad_rst_n;
    output   pad_cke;
    output   pad_cs_n;
    output   pad_ras_n;
    output   pad_cas_n;
    output   pad_we_n;
    inout    [`DM_BITS-1:0]   pad_dm_tdqs;
    output   [`BA_BITS-1:0]   pad_ba;
    output   [`ADDR_BITS-1:0] pad_addr;
    inout    [`DQ_BITS-1:0]   pad_dq;
    inout    [`DQ_BITS*8-1:0]  pad_dq_all;
    inout    [`DQS_BITS-1:0]  pad_dqs;
    inout    [`DQS_BITS-1:0]  pad_dqs_n;
    input    [`DQS_BITS-1:0]  pad_tdqs_n;
    output   pad_odt;
    output   pad_ck ;
    output   pad_ck_n;

    // Wires from controller to pads
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

    // Backend Controller
    Backend_Controller u_Backend_Controller(
        .power_on_rst_n(power_on_rst_n),
        .clk(clk),
        .clk2(clk2),
        //=== Interface with frontend Scheduler ===
        // Returned Data Channel
        .i_frontend_controller_ready(i_frontend_controller_ready),
        .o_backend_read_data(o_backend_read_data),
        .i_backend_controller_stall(i_backend_controller_stall),
        .o_backend_read_data_valid(o_backend_read_data_valid),

        // Command Channel
        .o_backend_controller_ready(o_backend_controller_ready),
        .i_frontend_command_valid(i_frontend_command_valid),
        .i_frontend_command(i_frontend_command),

        // Wdata Read Channel
        .i_frontend_write_data(i_frontend_write_data),
        .o_backend_controller_ren(o_backend_controller_ren),

        //=== I/O to interface ======
        .ddr3_rst_n(ddr3_rst_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_dm_tdqs_in(ddr3_dm_tdqs_in),
        .ddr3_dm_tdqs_out(ddr3_dm_tdqs_out),
        .ddr3_ba(ddr3_ba),
        .ddr3_addr(ddr3_addr),
        .ddr3_data_in(ddr3_data_in),
        .ddr3_data_out(ddr3_data_out),

        .ddr3_data_all_in(ddr3_data_all_in),
        .ddr3_data_all_out(ddr3_data_all_out),

        .ddr3_dqs_in(ddr3_dqs_in),
        .ddr3_dqs_out(ddr3_dqs_out),
        .ddr3_dqs_n_in(ddr3_dqs_n_in),
        .ddr3_dqs_n_out(ddr3_dqs_n_out),
        .ddr3_tdqs_n(ddr3_tdqs_n),
        .ddr3_odt(ddr3_odt)
    );

    //MEM PAD
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
endmodule