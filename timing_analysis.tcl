# Comprehensive timing analysis script
proc analyze_timing {project_name} {
    open_project build/${project_name}/${project_name}.xpr
    open_run impl_1
    
    # Create timing reports directory
    file mkdir reports/timing
    
    # Setup analysis
    report_timing_summary -delay_type min_max \
                         -report_unconstrained \
                         -check_timing_verbose \
                         -max_paths 100 \
                         -input_pins \
                         -routable_nets \
                         -file reports/timing/timing_summary.rpt
    
    # Clock domain analysis
    set clocks [get_clocks]
    foreach clk $clocks {
        set clk_name [get_property NAME $clk]
        puts "Analyzing clock domain: $clk_name"
        
        # Setup timing
        report_timing -from [get_clocks $clk_name] \
                     -to [get_clocks $clk_name] \
                     -delay_type max \
                     -max_paths 10 \
                     -sort_by slack \
                     -file reports/timing/setup_${clk_name}.rpt
        
        # Hold timing
        report_timing -from [get_clocks $clk_name] \
                     -to [get_clocks $clk_name] \
                     -delay_type min \
                     -max_paths 10 \
                     -sort_by slack \
                     -file reports/timing/hold_${clk_name}.rpt
    }
    
    # Cross-clock domain analysis
    foreach clk1 $clocks {
        foreach clk2 $clocks {
            if {$clk1 != $clk2} {
                set clk1_name [get_property NAME $clk1]
                set clk2_name [get_property NAME $clk2]
                
                report_timing -from [get_clocks $clk1_name] \
                             -to [get_clocks $clk2_name] \
                             -delay_type max \
                             -max_paths 5 \
                             -file reports/timing/cross_${clk1_name}_to_${clk2_name}.rpt
            }
        }
    }
    
    # Critical path analysis
    report_timing -delay_type max \
                 -max_paths 50 \
                 -sort_by slack \
                 -path_type summary \
                 -file reports/timing/critical_paths.rpt
    
    # Clock skew analysis
    report_clock_networks -file reports/timing/clock_networks.rpt
    
    # Check for timing violations
    set timing_met [check_timing -verbose -file reports/timing/check_timing.rpt]
    
    if {$timing_met} {
        puts "INFO: All timing constraints are met"
    } else {
        puts "WARNING: Timing violations detected"
    }
    
    close_project
    return $timing_met
}

# Run timing analysis
set project_name [lindex $argv 0]
analyze_timing $project_name
