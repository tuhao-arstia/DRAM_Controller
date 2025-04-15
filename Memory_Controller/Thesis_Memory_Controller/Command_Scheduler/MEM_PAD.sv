////////////////////////////////////////////////////////////////////////
// Project Name: eHome-II on-demand memory platform
// Task Name   : I/O interface
// Module Name : MEM_PAD
// File Name   : MEM_PAD.v
// Description : bidirectional path partition, I/O switching
// Author      : Yung Chang
// Revision History:
// Date        : 2009.10.15
////////////////////////////////////////////////////////////////////////
`include "define.sv"
module MEM_PAD(
         ddr3_rst_n       ,
         ddr3_cke         ,
         ddr3_cs_n        ,
         ddr3_ras_n       ,
         ddr3_cas_n       ,
         ddr3_we_n        ,
         ddr3_dm_tdqs_in  ,
         ddr3_dm_tdqs_out ,
         ddr3_ba          ,
         ddr3_addr        ,
         ddr3_data_in     ,
         ddr3_data_out    ,
         ddr3_data_all_in ,
         ddr3_data_all_out,
         ddr3_dqs_in      ,
         ddr3_dqs_out     ,
         ddr3_dqs_n_in    ,
         ddr3_dqs_n_out   ,
         ddr3_tdqs_n      ,
         ddr3_odt         ,
         ddr3_rw          ,
         ddr3_ck          ,

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


input   ddr3_rst_n;
input   ddr3_cke;
input   ddr3_cs_n;
input   ddr3_ras_n;
input   ddr3_cas_n;
input   ddr3_we_n;

output  [`DM_BITS-1:0]   ddr3_dm_tdqs_in;
input   [`DM_BITS-1:0]   ddr3_dm_tdqs_out;

input   [`BA_BITS-1:0]   ddr3_ba;
input   [`ADDR_BITS-1:0] ddr3_addr;

output  [`DQ_BITS-1:0]   ddr3_data_in;
input   [`DQ_BITS-1:0]   ddr3_data_out;

output [`DQ_BITS*8-1:0] ddr3_data_all_in;
input  [`DQ_BITS*8-1:0] ddr3_data_all_out;

output  [`DQS_BITS-1:0]  ddr3_dqs_in;
input   [`DQS_BITS-1:0]  ddr3_dqs_out;

output  [`DQS_BITS-1:0]  ddr3_dqs_n_in;
input   [`DQS_BITS-1:0]  ddr3_dqs_n_out;

output  [`DQS_BITS-1:0]  ddr3_tdqs_n;
input   ddr3_odt;
input   ddr3_rw ;     //0: bi-dirctional pad is output,
                      //1: bi-dirctional pad is input;

input   ddr3_ck;

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

wire   pad_rst_n = ddr3_rst_n ;
wire   pad_cke   = ddr3_cke   ;
wire   pad_cs_n  = ddr3_cs_n  ;
wire   pad_ras_n = ddr3_ras_n ;
wire   pad_cas_n = ddr3_cas_n ;
wire   pad_we_n  = ddr3_we_n  ;
wire   pad_odt   = ddr3_odt   ;

wire pad_ck = ddr3_ck ;
wire pad_ck_n = ~ddr3_ck ;

reg   [`DQ_BITS-1:0]   ddr3_data_out_d;
reg   [`DM_BITS-1:0]   ddr3_dm_tdqs_out_d;
//delay
always@* begin
   ddr3_data_out_d =  ddr3_data_out ;
   ddr3_dm_tdqs_out_d =  ddr3_dm_tdqs_out ;
end

assign pad_dm_tdqs = (ddr3_rw) ? ddr3_dm_tdqs_in : ddr3_dm_tdqs_out_d ;

assign pad_dq = (ddr3_rw) ? {(`DQ_BITS){1'bz}} : ddr3_data_out_d ;
assign ddr3_data_in = (ddr3_rw) ? pad_dq : {(`DQ_BITS){1'bz}} ;

assign pad_dq_all = (ddr3_rw) ? {(`DQ_BITS*8){1'bz}} : ddr3_data_all_out ;
assign ddr3_data_all_in = (ddr3_rw) ? pad_dq_all : {(`DQ_BITS*8){1'bz}} ;

assign pad_dqs = (ddr3_rw) ? 2'bz : ddr3_dqs_out ;
assign ddr3_dqs_in = (ddr3_rw) ? pad_dqs : 2'bz ;

assign pad_dqs_n = (ddr3_rw) ? 2'bz : ddr3_dqs_n_out ;
assign ddr3_dqs_n_in = (ddr3_rw) ? pad_dqs_n : 2'bz ;

assign pad_ba = ddr3_ba ;
assign pad_addr = ddr3_addr ;

endmodule
