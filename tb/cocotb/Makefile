SIM ?= vcs
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES ?= $(PWD)/../../hw/top_level.sv
TOPLEVEL ?= top_level
MODULE ?= top_test
SIM_ARGS = +fsdb+all=on -ucli -do ucli.do
WAVES = 1
COMPILE_ARGS = +incdir+$(PWD)/../../hw -pvalue+top_level.number_of_columns_per_frame=192 -pvalue+top_level.number_of_rows_per_frame=168 -pvalue+top_level.K=24

all: sim waveform

waveform: test.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim

test.vcd: test.fsdb | $(COCOTB_RESULTS_FILE)
	fsdb2vcd -o $@ $^
