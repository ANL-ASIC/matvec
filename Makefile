exe := bin/sim

verilator_out := obj_dir

top_mod := matvec
top_src := hw/$(top_mod).sv
top_tb_src := tb/sim_main.cpp

fpu_mod := FPmul
fpu_src := hw/$(fpu_mod).sv
fpu_tb_src := tb/fpu.cpp

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
VERILATOR_FLAGS += --build -j
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

default: top fpu

top:
	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) --version
	$(VERILATOR) $(VERILATOR_FLAGS) $(top_src) $(top_tb_src)

	# @echo
	# @echo "-- RUN ---------------------"
	# @rm -rf logs
	# @mkdir -p logs
	# obj_dir/V$(top_mod)

fpu:
	@echo
	@echo "-- VERILATE ----------------"
	$(VERILATOR) --version
	$(VERILATOR) $(VERILATOR_FLAGS) $(fpu_src) $(fpu_tb_src)

	# @echo
	# @echo "-- RUN ---------------------"
	# @rm -rf logs
	# @mkdir -p logs
	# obj_dir/V$(top_mod)
