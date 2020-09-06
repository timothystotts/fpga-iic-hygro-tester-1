// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (lin64) Build 2552052 Fri May 24 14:47:09 MDT 2019
// Date        : Sat Sep  5 21:29:18 2020
// Host        : l4study running 64-bit Ubuntu 18.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/timothystotts/Workareas/GitHub/timothystotts/fpga-iic-hygro-tester-1/HYGRO-Tester-Design-AXI/IPI-BDs/system_100/ip/system_100_dlmb_v10_0/system_100_dlmb_v10_0_stub.v
// Design      : system_100_dlmb_v10_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100ticsg324-1L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "lmb_v10,Vivado 2019.1" *)
module system_100_dlmb_v10_0(LMB_Clk, SYS_Rst, LMB_Rst, M_ABus, M_ReadStrobe, 
  M_WriteStrobe, M_AddrStrobe, M_DBus, M_BE, Sl_DBus, Sl_Ready, Sl_Wait, Sl_UE, Sl_CE, LMB_ABus, 
  LMB_ReadStrobe, LMB_WriteStrobe, LMB_AddrStrobe, LMB_ReadDBus, LMB_WriteDBus, LMB_Ready, 
  LMB_Wait, LMB_UE, LMB_CE, LMB_BE)
/* synthesis syn_black_box black_box_pad_pin="LMB_Clk,SYS_Rst,LMB_Rst,M_ABus[0:31],M_ReadStrobe,M_WriteStrobe,M_AddrStrobe,M_DBus[0:31],M_BE[0:3],Sl_DBus[0:31],Sl_Ready[0:0],Sl_Wait[0:0],Sl_UE[0:0],Sl_CE[0:0],LMB_ABus[0:31],LMB_ReadStrobe,LMB_WriteStrobe,LMB_AddrStrobe,LMB_ReadDBus[0:31],LMB_WriteDBus[0:31],LMB_Ready,LMB_Wait,LMB_UE,LMB_CE,LMB_BE[0:3]" */;
  input LMB_Clk;
  input SYS_Rst;
  output LMB_Rst;
  input [0:31]M_ABus;
  input M_ReadStrobe;
  input M_WriteStrobe;
  input M_AddrStrobe;
  input [0:31]M_DBus;
  input [0:3]M_BE;
  input [0:31]Sl_DBus;
  input [0:0]Sl_Ready;
  input [0:0]Sl_Wait;
  input [0:0]Sl_UE;
  input [0:0]Sl_CE;
  output [0:31]LMB_ABus;
  output LMB_ReadStrobe;
  output LMB_WriteStrobe;
  output LMB_AddrStrobe;
  output [0:31]LMB_ReadDBus;
  output [0:31]LMB_WriteDBus;
  output LMB_Ready;
  output LMB_Wait;
  output LMB_UE;
  output LMB_CE;
  output [0:3]LMB_BE;
endmodule
