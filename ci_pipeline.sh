#!/bin/bash
# Continuous Integration Pipeline for Xilinx Projects

set -e  # Exit on any error

# Configuration
PROJECT_NAME="advanced_system"
VIVADO_VERSION="2023.2"
REPORTS_DIR="reports"
DASHBOARD_DIR="dashboard"
ARTIFACTS_DIR="artifacts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Setup environment
setup_environment() {
    log_info "Setting up build environment..."
    
    # Source Vivado settings
    if [ -f "/tools/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh" ]; then
        source /tools/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh
        log_info "Vivado ${VIVADO_VERSION} environment loaded"
    else
        log_error "Vivado ${VIVADO_VERSION} not found"
        exit 1
    fi
    
    # Create directories
    mkdir -p ${REPORTS_DIR}
    mkdir -p ${DASHBOARD_DIR}
    mkdir -p ${ARTIFACTS_DIR}
    
    # Check Python dependencies
    if ! python3 -c "import matplotlib, pandas" 2>/dev/null; then
        log_warning "Installing Python dependencies..."
        pip3 install matplotlib pandas
    fi
}

# Static analysis
run_static_analysis() {
    log_info "Running static analysis..."
    
    # Check for common coding issues
    find src -name "*.v" -o -name "*.sv" | while read file; do
        # Check for blocking assignments in always_ff
        if grep -n "always_ff.*=" "$file" | grep -v "<=" > /dev/null; then
            log_warning "Potential blocking assignment in always_ff found in $file"
        fi
        
        # Check for missing reset conditions
        if grep -n "always_ff" "$file" | grep -v "rst\|reset" > /dev/null; then
            log_warning "Missing reset condition in always_ff found in $file"
        fi
        
        # Check for clock domain crossing without synchronizers
        if grep -n "assign.*clk" "$file" > /dev/null; then
            log_warning "Potential clock domain crossing without synchronizer in $file"
        fi
    done
    
    log_info "Static analysis completed"
}

# Synthesis
run_synthesis() {
    log_info "Running synthesis..."
    
    make synthesis 2>&1 | tee ${REPORTS_DIR}/synthesis.log
    
    # Check synthesis results
    if grep -q "ERROR" ${REPORTS_DIR}/synthesis.log; then
        log_error "Synthesis failed with errors"
        exit 1
    elif grep -q "CRITICAL WARNING" ${REPORTS_DIR}/synthesis.log; then
        log_warning "Synthesis completed with critical warnings"
    else
        log_info "Synthesis completed successfully"
    fi
}

# Implementation
run_implementation() {
    log_info "Running implementation..."
    
    make implementation 2>&1 | tee ${REPORTS_DIR}/implementation.log
    
    # Check implementation results
    if grep -q "ERROR" ${REPORTS_DIR}/implementation.log; then
        log_error "Implementation failed with errors"
        exit 1
    else
        log_info "Implementation completed successfully"
    fi
}

# Timing analysis
run_timing_analysis() {
    log_info "Running timing analysis..."
    
    make timing_analysis 2>&1 | tee ${REPORTS_DIR}/timing_analysis.log
    
    # Check for timing violations
    if find ${REPORTS_DIR} -name "*timing*.rpt" -exec grep -l "VIOLATED" {} \; | grep -q .; then
        log_error "Timing violations detected!"
        
        # Extract worst violations
        find ${REPORTS_DIR} -name "*timing*.rpt" -exec grep -A 5 -B 5 "VIOLATED" {} \; > ${REPORTS_DIR}/timing_violations.txt
        
        return 1
    else
        log_info "All timing constraints met"
        return 0
    fi
}

# Power analysis
run_power_analysis() {
    log_info "Running power analysis..."
    
    make power_analysis 2>&1 | tee ${REPORTS_DIR}/power_analysis.log
    
    # Extract power consumption
    if [ -f "${REPORTS_DIR}/power_detailed.rpt" ]; then
        total_power=$(grep "Total On-Chip Power" ${REPORTS_DIR}/power_detailed.rpt | awk '{print $5}')
        log_info "Total power consumption: ${total_power} W"
        
        # Check power limits (example: 25W limit)
        if (( $(echo "$total_power > 25.0" | bc -l) )); then
            log_warning "Power consumption exceeds 25W limit"
        fi
    fi
}

# Generate performance dashboard
generate_dashboard() {
    log_info "Generating performance dashboard..."
    
    python3 scripts/performance_monitor.py \
        --reports-dir ${REPORTS_DIR} \
        --output-dir ${DASHBOARD_DIR} \
        --json-output ${ARTIFACTS_DIR}/performance_metrics.json
    
    log_info "Dashboard generated at ${DASHBOARD_DIR}/dashboard.html"
}

# Resource utilization check
check_resource_utilization() {
    log_info "Checking resource utilization..."
    
    if [ -f "${REPORTS_DIR}/utilization_optimized.rpt" ]; then
        # Extract utilization percentages
        lut_util=$(grep "CLB LUTs" ${REPORTS_DIR}/utilization_optimized.rpt | awk '{print $6}' | tr -d '%')
        ff_util=$(grep "CLB Registers" ${REPORTS_DIR}/utilization_optimized.rpt | awk '{print $6}' | tr -d '%')
        bram_util=$(grep "Block RAM Tile" ${REPORTS_DIR}/utilization_optimized.rpt | awk '{print $6}' | tr -d '%')
        dsp_util=$(grep "DSPs" ${REPORTS_DIR}/utilization_optimized.rpt | awk '{print $6}' | tr -d '%')
        
        log_info "Resource Utilization:"
        log_info "  LUTs: ${lut_util}%"
        log_info "  FFs: ${ff_util}%"
        log_info "  BRAMs: ${bram_util}%"
        log_info "  DSPs: ${dsp_util}%"
        
        # Check utilization limits
        if (( $(echo "$lut_util > 90.0" | bc -l) )); then
            log_warning "LUT utilization > 90%"
        fi
        if (( $(echo "$ff_util > 90.0" | bc -l) )); then
            log_warning "FF utilization > 90%"
        fi
        if (( $(echo "$bram_util > 90.0" | bc -l) )); then
            log_warning "BRAM utilization > 90%"
        fi
        if (( $(echo "$dsp_util > 90.0" | bc -l) )); then
            log_warning "DSP utilization > 90%"
        fi
    fi
}

# Generate bitstream
generate_bitstream() {
    log_info "Generating bitstream..."
    
    make bitstream 2>&1 | tee ${REPORTS_DIR}/bitstream.log
    
    if [ -f "build/${PROJECT_NAME}/${PROJECT_NAME}.runs/impl_1/${PROJECT_NAME}.bit" ]; then
        cp "build/${PROJECT_NAME}/${PROJECT_NAME}.runs/impl_1/${PROJECT_NAME}.bit" ${ARTIFACTS_DIR}/
        log_info "Bitstream generated successfully"
    else
        log_error "Bitstream generation failed"
        exit 1
    fi
}

# Archive artifacts
archive_artifacts() {
    log_info "Archiving build artifacts..."
    
    # Create archive with timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    archive_name="${PROJECT_NAME}_${timestamp}.tar.gz"
    
    tar -czf ${ARTIFACTS_DIR}/${archive_name} \
        ${REPORTS_DIR}/ \
        ${DASHBOARD_DIR}/ \
        ${ARTIFACTS_DIR}/*.bit \
        ${ARTIFACTS_DIR}/*.json
    
    log_info "Artifacts archived as ${archive_name}"
}

# Send notifications
send_notifications() {
    local status=$1
    local message=$2
    
    # Slack notification (if webhook URL is set)
    if [ ! -z "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"Build ${status}: ${PROJECT_NAME} - ${message}\"}" \
            $SLACK_WEBHOOK_URL
    fi
    
    # Email notification (if configured)
    if [ ! -z "$NOTIFICATION_EMAIL" ]; then
        echo "${message}" | mail -s "Build ${status}: ${PROJECT_NAME}" $NOTIFICATION_EMAIL
    fi
}

# Main CI pipeline
main() {
    local start_time=$(date +%s)
    local exit_code=0
    
    log_info "Starting CI pipeline for ${PROJECT_NAME}"
    
    # Setup
    setup_environment
    
    # Clean previous build
    make clean
    
    # Run pipeline stages
    run_static_analysis
    
    if ! run_synthesis; then
        send_notifications "FAILED" "Synthesis failed"
        exit 1
    fi
    
    if ! run_implementation; then
        send_notifications "FAILED" "Implementation failed"
        exit 1
    fi
    
    # Timing analysis (non-blocking for warnings)
    if ! run_timing_analysis; then
        log_warning "Timing violations detected, but continuing..."
        exit_code=1
    fi
    
    run_power_analysis
    check_resource_utilization
    generate_dashboard
    
    # Generate bitstream only if timing is met
    if [ $exit_code -eq 0 ]; then
        generate_bitstream
    else
        log_warning "Skipping bitstream generation due to timing violations"
    fi
    
    archive_artifacts
    
    # Calculate build time
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local build_time_formatted=$(printf '%02d:%02d:%02d' $((build_time/3600)) $((build_time%3600/60)) $((build_time%60)))
    
    if [ $exit_code -eq 0 ]; then
        log_info "CI pipeline completed successfully in ${build_time_formatted}"
        send_notifications "SUCCESS" "Build completed in ${build_time_formatted}"
    else
        log_warning "CI pipeline completed with warnings in ${build_time_formatted}"
        send_notifications "WARNING" "Build completed with timing violations in ${build_time_formatted}"
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
