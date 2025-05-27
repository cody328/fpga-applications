# Advanced Makefile for Xilinx projects
PROJECT_NAME = advanced_system
PART = xcvu9p-flga2104-2-i
BOARD = xilinx.com:vcu118:part0:2.4

# Directories
SRC_DIR = src
IP_DIR = ip
CONSTRAINTS_DIR = constraints
BUILD_DIR = build
REPORTS_DIR = reports

# Source files
RTL_SOURCES = $(wildcard $(SRC_DIR)/*.v) $(wildcard $(SRC_DIR)/*.sv)
HLS_SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
CONSTRAINTS = $(wildcard $(CONSTRAINTS_DIR)/*.xdc)

# Vivado settings
VIVADO_VERSION = 2023.2
VIVADO_SETTINGS = /tools/Xilinx/Vivado/$(VIVADO_VERSION)/settings64.sh

# Build targets
.PHONY: all clean synthesis implementation bitstream program timing_analysis

all: bitstream

# Create project and add sources
project:
	@echo "Creating Vivado project..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/create_project.tcl \
		-tclargs $(PROJECT_NAME) $(PART) $(BOARD)

# Run HLS if needed
hls: $(HLS_SOURCES)
	@echo "Running High-Level Synthesis..."
	@source $(VIVADO_SETTINGS) && \
	vitis_hls -f scripts/run_hls.tcl

# Synthesis
synthesis: project
	@echo "Running synthesis..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/run_synthesis.tcl \
		-tclargs $(PROJECT_NAME)
	@mkdir -p $(REPORTS_DIR)
	@cp $(BUILD_DIR)/$(PROJECT_NAME).runs/synth_1/*.rpt $(REPORTS_DIR)/

# Implementation  
implementation: synthesis
	@echo "Running implementation..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/run_implementation.tcl \
		-tclargs $(PROJECT_NAME)
	@cp $(BUILD_DIR)/$(PROJECT_NAME).runs/impl_1/*.rpt $(REPORTS_DIR)/

# Generate bitstream
bitstream: implementation
	@echo "Generating bitstream..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/generate_bitstream.tcl \
		-tclargs $(PROJECT_NAME)

# Program device
program: bitstream
	@echo "Programming device..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/program_device.tcl \
		-tclargs $(PROJECT_NAME)

# Timing analysis
timing_analysis: implementation
	@echo "Running timing analysis..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/timing_analysis.tcl \
		-tclargs $(PROJECT_NAME)

# Power analysis
power_analysis: implementation
	@echo "Running power analysis..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/power_analysis.tcl \
		-tclargs $(PROJECT_NAME)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(REPORTS_DIR)
	@rm -rf .Xil
	@rm -rf *.jou *.log

# Continuous integration target
ci: clean synthesis implementation timing_analysis power_analysis
	@echo "CI build complete"
	@if grep -q "VIOLATED" $(REPORTS_DIR)/*timing*.rpt; then \
		echo "ERROR: Timing violations detected"; \
		exit 1; \
	fi

# Performance optimization
optimize: 
	@echo "Running performance optimization..."
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/optimize_design.tcl \
		-tclargs $(PROJECT_NAME)

# Generate documentation
docs:
	@echo "Generating documentation..."
	@doxygen docs/Doxyfile
	@source $(VIVADO_SETTINGS) && \
	vivado -mode batch -source scripts/generate_docs.tcl \
		-tclargs $(PROJECT_NAME)
