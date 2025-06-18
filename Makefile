exe := bin/sim

verilator_out := obj_dir

top_mod := matvec_wrapper
top_src := hw/$(top_mod).sv
top_tb_src := tb/verilator/sim_main.cpp

fmul_mod := int_fp_mult
fmul_src := hw/$(fmul_mod).sv
fmul_tb_src := tb/verilator/fmult.cpp

fadd_mod := FPadd
fadd_src := hw/$(fadd_mod).sv
fadd_tb_src := tb/verilator/fadd.cpp

fconv_mod := int_to_float
fconv_src := hw/$(fconv_mod).sv
fconv_tb_src := tb/verilator/fconv.cpp

N ?= 16
K ?= 8

# If $VERILATOR_ROOT isn't in the environment, we assume it is part of a
# package install, and verilator is in your path. Otherwise find the
# binary relative to $VERILATOR_ROOT (such as when inside the git sources).
ifeq ($(VERILATOR_ROOT),)
VERILATOR = verilator
VERILATOR_COVERAGE = verilator_coverage
else
export VERILATOR_ROOT
VERILATOR = $(VERILATOR_ROOT)/bin/verilator
VERILATOR_COVERAGE = $(VERILATOR_ROOT)/bin/verilator_coverage
endif

VERILATOR_FLAGS =
# Generate C++ in executable form
VERILATOR_FLAGS += -cc --exe
# Generate makefile dependencies (not shown as complicates the Makefile)
#VERILATOR_FLAGS += -MMD
# Optimize
VERILATOR_FLAGS += --x-assign 0
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS += -Wall
# Make waveforms
VERILATOR_FLAGS += --trace
# Check SystemVerilog assertions
VERILATOR_FLAGS += --assert
# Generate coverage analysis
# VERILATOR_FLAGS += --coverage
# Run make to compile model, with as many CPUs as are free
VERILATOR_FLAGS += --build -j 20
# Run Verilator in debug mode
#VERILATOR_FLAGS += --debug
# Add this trace to get a backtrace in gdb
# VERILATOR_FLAGS += --gdbbt
# include director for verilog
VERILATOR_FLAGS += -Ihw
# VERILATOR_FLAGS += --decorations node -CFLAGS -ggdb -LDFLAGS -ggdb -CFLAGS -D_GLIBCXX_DEBUG -CFLAGS -DVL_DEBUG=1

# Input files for Verilator
# VERILATOR_INPUT = $(top_src) $(top_tb_src)

######################################################################

# Create annotated source
VERILATOR_COV_FLAGS += --annotate logs/annotated
# A single coverage hit is considered good enough
VERILATOR_COV_FLAGS += --annotate-min 1
# Create LCOV info
VERILATOR_COV_FLAGS += --write-info logs/coverage.info
# Input file from Verilator
VERILATOR_COV_FLAGS += logs/coverage.dat

######################################################################

default: top fmul fadd fconv

clean:
	rm -rf obj_dir
	cd tb/cocotb && $(MAKE) clean

run_coco:
	cd tb/cocotb && $(MAKE)

top:
	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) --version
	$(VERILATOR) $(VERILATOR_FLAGS) -GN=$(N) -GM=$(K) $(top_src) $(top_tb_src)

	# @echo
	# @echo "-- RUN ---------------------"
	# @rm -rf logs
	# @mkdir -p logs
	# obj_dir/V$(top_mod)

fmul:
	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) --version
	$(VERILATOR) $(VERILATOR_FLAGS) $(fmul_src) $(fmul_tb_src)

	# @echo
	# @echo "-- RUN ---------------------"
	# @rm -rf logs
	# @mkdir -p logs
	# obj_dir/V$(top_mod)

fadd:
	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) --version
	$(VERILATOR) $(VERILATOR_FLAGS) $(fadd_src) $(fadd_tb_src)

	# @echo
	# @echo "-- RUN ---------------------"
	# @rm -rf logs
	# @mkdir -p logs
	# obj_dir/V$(top_mod)

fconv:
	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) --version
	$(VERILATOR) $(VERILATOR_FLAGS) $(fconv_src) $(fconv_tb_src)

	# @echo
	# @echo "-- RUN ---------------------"
	# @rm -rf logs
	# @mkdir -p logs
	# obj_dir/V$(top_mod)
