# Advanced optimization script
proc optimize_for_performance {project_name} {
    open_project build/${project_name}/${project_name}.xpr
    
    # Set aggressive optimization strategies
    set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs synth_1]
    set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]
    
    # Enable all physical optimization steps
    set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
    
    # Set directive for aggressive optimization
    set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE PerformanceOptimized [get_runs synth_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraTimingOpt [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    
    # Run optimization
    reset_run synth_1
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    
    reset_run impl_1
    launch_runs impl_1 -jobs 8
    wait_on_run impl_1
    
    # Generate detailed reports
    open_run impl_1
    report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file reports/timing_summary_optimized.rpt
    report_utilization -file reports/utilization_optimized.rpt
    report_power -file reports/power_optimized.rpt
    
    close_project
}

proc optimize_for_area {project_name} {
    open_project build/${project_name}/${project_name}.xpr
    
    # Set area optimization strategies
    set_property strategy Flow_AreaOptimized_high [get_runs synth_1]
    set_property strategy Area_Explore [get_runs impl_1]
    
    # Area-focused directives
    set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high [get_runs synth_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE AltSpreadLogic_high [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AlternateCLBRouting [get_runs impl_1]
    
    # Enable resource sharing
    set_property STEPS.SYNTH_DESIGN.ARGS.RESOURCE_SHARING on [get_runs synth_1]
    set_property STEPS.SYNTH_DESIGN.ARGS.SHREG_MIN_SIZE 5 [get_runs synth_1]
    
    # Run area optimization
    reset_run synth_1
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    
    reset_run impl_1
    launch_runs impl_1 -jobs 8
    wait_on_run impl_1
    
    close_project
}

proc optimize_for_power {project_name} {
    open_project build/${project_name}/${project_name}.xpr
    
    # Power optimization strategies
    set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
    set_property strategy Power_DefaultOpt [get_runs impl_1]
    
    # Enable power optimization
    set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
    set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs synth_1]
    
    # Clock gating and power-aware placement
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
    set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
    
    reset_run synth_1
    launch_runs synth_1 -jobs 8
    wait_on_run synth_1
    
    reset_run impl_1
    launch_runs impl_1 -jobs 8
    wait_on_run impl_1
    
    # Generate power report
    open_run impl_1
    report_power -file reports/power_detailed.rpt
    
    close_project
}

# Main optimization flow
set project_name [lindex $argv 0]
set optimization_target [lindex $argv 1]

switch $optimization_target {
    "performance" {
        optimize_for_performance $project_name
    }
    "area" {
        optimize_for_area $project_name
    }
    "power" {
        optimize_for_power $project_name
    }
    default {
        optimize_for_performance $project_name
    }
}
