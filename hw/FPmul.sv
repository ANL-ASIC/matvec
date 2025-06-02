// File vhdl/fpmult.vhd translated with vhd2vl 3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001-2023 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-reg.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2023 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// VHDL Entity HAVOC.FPmul.symbol
//
// Created by
// Guillermo Marcus, gmarcus@ieee.org
// using Mentor Graphics FPGA Advantage tools.
//
// Visit "http://fpga.mty.itesm.mx" for more info.
//
// 2003-2004. V1.0
//

module FPmul #(
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input wire [EWIDTH + SIGWIDTH:0] FP_A,
    input wire [EWIDTH + SIGWIDTH:0] FP_B,
    output wire [EWIDTH + SIGWIDTH:0] FP_Z);

// localparam WIDTH = 1 + EWIDTH + SIGWIDTH;
localparam BIAS = 2 ** (EWIDTH - 1) - 1;

`ifdef VERILATOR
initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end
`endif

//
// VHDL Architecture HAVOC.FPmul.single_cycle
//
// Created by
// Guillermo Marcus, gmarcus@ieee.org
// using Mentor Graphics FPGA Advantage tools.
//
// Visit "http://fpga.mty.itesm.mx" for more info.
//
// Copyright 2003-2004. V1.0
//
wire [EWIDTH - 1:0] A_EXP;
wire [SIGWIDTH:0] A_SIG;
wire A_SIGN;
wire A_isINF;
wire A_isNaN;
wire A_isZ;
wire [EWIDTH - 1:0] B_EXP;
wire [SIGWIDTH:0] B_SIG;
wire B_SIGN;
wire B_isINF;
wire B_isNaN;
wire B_isZ;
wire [EWIDTH - 1:0] EXP_addout;
wire [EWIDTH - 1:0] EXP_in;
wire [EWIDTH - 1:0] EXP_out;
wire [EWIDTH - 1:0] EXP_out_norm;
wire [EWIDTH - 1:0] EXP_out_round;
wire SIGN_out;
wire [2 * (SIGWIDTH + 1) - 1:0] SIG_in;
logic SIG_isZ;
wire [SIGWIDTH:0] SIG_out;
wire [SIGWIDTH + 3:0] SIG_out_norm;
wire [SIGWIDTH:0] SIG_out_round;
logic isINF;
logic isINF_tab;
logic isNaN;
wire isZ;
logic isZ_tab;
wire [2 * (SIGWIDTH + 1) - 1:0] prod;

wire [2 * (SIGWIDTH + 1) - 1:0] dtemp;


  assign SIG_in = prod[2 * (SIGWIDTH + 1) - 1:0];
  assign EXP_in = EXP_addout;
  assign SIG_out = SIG_out_round;
  assign EXP_out = EXP_out_round;
  always @(*) begin
    if(isZ == 1'b0) begin
      if(isINF_tab == 1'b1) begin
        isINF = 1'b1;
      end
      else if(EXP_out == {EWIDTH{1'b1}}) begin
        isINF = 1'b1;
      end
      else if((A_EXP[EWIDTH - 1] == 1'b1 && B_EXP[EWIDTH - 1] == 1'b1 && (EXP_out[EWIDTH - 1] == 1'b0))) begin
        isINF = 1'b1;
      end
      else begin
        isINF = 1'b0;
      end
    end
    else begin
      isINF = 1'b0;
    end
  end

  always @(*) begin : P3
    if((A_isINF == 1'b0) && (A_isNaN == 1'b0) && (A_isZ == 1'b0) && (B_isINF == 1'b0) && (B_isNaN == 1'b0) && (B_isZ == 1'b0)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b0;
      isNaN = 1'b0;
    end
    else if((A_isINF == 1'b1) && (B_isZ == 1'b1)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b0;
      isNaN = 1'b1;
    end
    else if((A_isZ == 1'b1) && (B_isINF == 1'b1)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b0;
      isNaN = 1'b1;
    end
    else if((A_isINF == 1'b1)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b1;
      isNaN = 1'b0;
    end
    else if((B_isINF == 1'b1)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b1;
      isNaN = 1'b0;
    end
    else if((A_isNaN == 1'b1)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b0;
      isNaN = 1'b1;
    end
    else if((B_isNaN == 1'b1)) begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b0;
      isNaN = 1'b1;
    end
    else if((A_isZ == 1'b1)) begin
      isZ_tab = 1'b1;
      isINF_tab = 1'b0;
      isNaN = 1'b0;
    end
    else if((B_isZ == 1'b1)) begin
      isZ_tab = 1'b1;
      isINF_tab = 1'b0;
      isNaN = 1'b0;
    end
    else begin
      isZ_tab = 1'b0;
      isINF_tab = 1'b0;
      isNaN = 1'b0;
    end
  end

  // check for 0 significand
  always @(*) begin
    if((EXP_out[EWIDTH - 1] == 1'b1 && ((A_EXP[EWIDTH - 1] == 1'b0 && !(A_EXP == {EWIDTH{1'b1}})) && (B_EXP[EWIDTH - 1] == 1'b0 && !(B_EXP == {EWIDTH{1'b1}}))))) begin
      // Underflow or zero significand
      SIG_isZ = 1'b1;
    end
    else begin
      SIG_isZ = 1'b0;
    end
  end

  // Add exponents
  assign EXP_addout = (A_EXP - BIAS) + (B_EXP - BIAS) + BIAS;

  // Multiply significand
  assign dtemp = (A_SIG) * (B_SIG);
  assign prod = dtemp;

  assign isZ = SIG_isZ | isZ_tab;
  assign SIGN_out = A_SIGN ^ B_SIGN;

  FPunpack #(
      .SIGWIDTH(SIGWIDTH),
      .EWIDTH(EWIDTH))
      unpack0(
      .FP(FP_A),
    .SIG(A_SIG),
    .EXP(A_EXP),
    .SIGN(A_SIGN),
    .isNaN(A_isNaN),
    .isINF(A_isINF),
    .isZ(A_isZ));
    // .isDN(/* open */));

  FPunpack #(
      .SIGWIDTH(SIGWIDTH),
      .EWIDTH(EWIDTH))
      unpack1(
      .FP(FP_B),
    .SIG(B_SIG),
    .EXP(B_EXP),
    .SIGN(B_SIGN),
    .isNaN(B_isNaN),
    .isINF(B_isINF),
    .isZ(B_isZ));
    // .isDN(/* open */));

  FPnormalizeMul #(
      .SIGWIDTH(SIGWIDTH),
      .EWIDTH(EWIDTH))
      norm(
      .SIG_in(SIG_in),
    .EXP_in(EXP_in),
    .SIG_out(SIG_out_norm),
    .EXP_out(EXP_out_norm));

  FPround #(
      .SIGWIDTH(SIGWIDTH),
      .EWIDTH(EWIDTH))
      round(
    .SIG_in(SIG_out_norm),
    .EXP_in(EXP_out_norm),
    .SIG_out(SIG_out_round),
    .EXP_out(EXP_out_round));

  FPpack #(
      .SIGWIDTH(SIGWIDTH),
      .EWIDTH(EWIDTH))
      pack(
      .SIGN(SIGN_out),
    .EXP(EXP_out),
    .SIG(SIG_out),
    .isNaN(isNaN),
    .isINF(isINF),
    .isZ(isZ),
    .FP(FP_Z));
endmodule
