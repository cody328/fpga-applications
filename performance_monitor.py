#!/usr/bin/env python3
"""
Advanced performance monitoring and analysis for Xilinx designs
"""

import re
import json
import matplotlib.pyplot as plt
import pandas as pd
from pathlib import Path
import argparse
from datetime import datetime

class XilinxPerformanceAnalyzer:
    def __init__(self, reports_dir):
        self.reports_dir = Path(reports_dir)
        self.metrics = {}
        
    def parse_timing_report(self, report_file):
        """Parse timing summary report"""
        timing_data = {
            'wns': None,  # Worst Negative Slack
            'tns': None,  # Total Negative Slack
            'whs': None,  # Worst Hold Slack
            'ths': None,  # Total Hold Slack
            'failing_endpoints': 0
        }
        
        with open(report_file, 'r') as f:
            content = f.read()
            
        # Extract WNS
        wns_match = re.search(r'WNS\(ns\):\s*([-\d.]+)', content)
        if wns_match:
            timing_data['wns'] = float(wns_match.group(1))
            
        # Extract TNS
        tns_match = re.search(r'TNS\(ns\):\s*([-\d.]+)', content)
        if tns_match:
            timing_data['tns'] = float(tns_match.group(1))
            
        # Extract WHS
        whs_match = re.search(r'WHS\(ns\):\s*([-\d.]+)', content)
        if whs_match:
            timing_data['whs'] = float(whs_match.group(1))
            
        # Extract failing endpoints
        endpoints_match = re.search(r'Failing Endpoints:\s*(\d+)', content)
        if endpoints_match:
            timing_data['failing_endpoints'] = int(endpoints_match.group(1))
            
        return timing_data
    
    def parse_utilization_report(self, report_file):
        """Parse utilization report"""
        util_data = {
            'lut': {'used': 0, 'available': 0, 'utilization': 0},
            'ff': {'used': 0, 'available': 0, 'utilization': 0},
            'bram': {'used': 0, 'available': 0, 'utilization': 0},
            'dsp': {'used': 0, 'available': 0, 'utilization': 0}
        }
        
        with open(report_file, 'r') as f:
            content = f.read()
            
        # Parse LUT utilization
        lut_match = re.search(r'CLB LUTs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)', content)
        if lut_match:
            util_data['lut']['used'] = int(lut_match.group(1))
            util_data['lut']['available'] = int(lut_match.group(2))
            util_data['lut']['utilization'] = float(lut_match.group(3))
            
        # Parse FF utilization
        ff_match = re.search(r'CLB Registers\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)', content)
        if ff_match:
            util_data['ff']['used'] = int(ff_match.group(1))
            util_data['ff']['available'] = int(ff_match.group(2))
            util_data['ff']['utilization'] = float(ff_match.group(3))
            
        # Parse BRAM utilization
        bram_match = re.search(r'Block RAM Tile\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)', content)
        if bram_match:
            util_data['bram']['used'] = int(bram_match.group(1))
            util_data['bram']['available'] = int(bram_match.group(2))
            util_data['bram']['utilization'] = float(bram_match.group(3))
            
        # Parse DSP utilization
        dsp_match = re.search(r'DSPs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)', content)
        if dsp_match:
            util_data['dsp']['used'] = int(dsp_match.group(1))
            util_data['dsp']['available'] = int(dsp_match.group(2))
            util_data['dsp']['utilization'] = float(dsp_match.group(3))
            
        return util_data
    
    def parse_power_report(self, report_file):
        """Parse power analysis report"""
        power_data = {
            'total_power': 0,
            'dynamic_power': 0,
            'static_power': 0,
            'confidence': 'Low'
        }
        
        with open(report_file, 'r') as f:
            content = f.read()
            
        # Extract total power
        total_match = re.search(r'Total On-Chip Power \(W\)\s*\|\s*([\d.]+)', content)
        if total_match:
            power_data['total_power'] = float(total_match.group(1))
            
        # Extract dynamic power
        dynamic_match = re.search(r'Dynamic \(W\)\s*\|\s*([\d.]+)', content)
        if dynamic_match:
            power_data['dynamic_power'] = float(dynamic_match.group(1))
            
        # Extract static power
        static_match = re.search(r'Device Static \(W\)\s*\|\s*([\d.]+)', content)
        if static_match:
            power_data['static_power'] = float(static_match.group(1))
            
        return power_data
    
    def analyze_all_reports(self):
        """Analyze all available reports"""
        results = {
            'timestamp': datetime.now().isoformat(),
            'timing': {},
            'utilization': {},
            'power': {}
        }
        
        # Find and parse timing reports
        timing_files = list(self.reports_dir.glob('*timing*.rpt'))
        for timing_file in timing_files:
            results['timing'][timing_file.stem] = self.parse_timing_report(timing_file)
            
        # Find and parse utilization reports
        util_files = list(self.reports_dir.glob('*utilization*.rpt'))
        for util_file in util_files:
            results['utilization'][util_file.stem] = self.parse_utilization_report(util_file)
            
        # Find and parse power reports
        power_files = list(self.reports_dir.glob('*power*.rpt'))
        for power_file in power_files:
            results['power'][power_file.stem] = self.parse_power_report(power_file)
            
        return results
    
    def generate_performance_dashboard(self, results, output_dir):
        """Generate performance dashboard with plots"""
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)
        
        # Create timing analysis plot
        self._plot_timing_analysis(results['timing'], output_path)
        
        # Create utilization plot
        self._plot_utilization(results['utilization'], output_path)
        
        # Create power analysis plot
        self._plot_power_analysis(results['power'], output_path)
        
        # Generate HTML dashboard
        self._generate_html_dashboard(results, output_path)
        
    def _plot_timing_analysis(self, timing_data, output_path):
        """Create timing analysis plots"""
        if not timing_data:
            return
            
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle('Timing Analysis Dashboard', fontsize=16)
        
        # WNS across different reports
        reports = list(timing_data.keys())
        wns_values = [timing_data[r].get('wns', 0) for r in reports]
        
        ax1.bar(reports, wns_values, color=['red' if w < 0 else 'green' for w in wns_values])
        ax1.set_title('Worst Negative Slack (WNS)')
        ax1.set_ylabel('Slack (ns)')
        ax1.tick_params(axis='x', rotation=45)
        ax1.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        
        # TNS across different reports
        tns_values = [timing_data[r].get('tns', 0) for r in reports]
        ax2.bar(reports, tns_values, color=['red' if t < 0 else 'green' for t in tns_values])
        ax2.set_title('Total Negative Slack (TNS)')
        ax2.set_ylabel('Slack (ns)')
        ax2.tick_params(axis='x', rotation=45)
        ax2.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        
        # Hold timing
        whs_values = [timing_data[r].get('whs', 0) for r in reports]
        ax3.bar(reports, whs_values, color=['red' if w < 0 else 'green' for w in whs_values])
        ax3.set_title('Worst Hold Slack (WHS)')
        ax3.set_ylabel('Slack (ns)')
        ax3.tick_params(axis='x', rotation=45)
        ax3.axhline(y=0, color='black', linestyle='--', alpha=0.5)
        
        # Failing endpoints
        failing_eps = [timing_data[r].get('failing_endpoints', 0) for r in reports]
        ax4.bar(reports, failing_eps, color=['red' if f > 0 else 'green' for f in failing_eps])
        ax4.set_title('Failing Endpoints')
        ax4.set_ylabel('Count')
        ax4.tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        plt.savefig(output_path / 'timing_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()
        
    def _plot_utilization(self, util_data, output_path):
        """Create utilization plots"""
        if not util_data:
            return
            
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle('Resource Utilization Dashboard', fontsize=16)
        
        # Get the latest utilization data
        latest_report = list(util_data.keys())[-1] if util_data else None
        if not latest_report:
            return
            
        util = util_data[latest_report]
        
        # LUT utilization pie chart
        lut_used = util['lut']['used']
        lut_available = util['lut']['available'] - lut_used
        ax1.pie([lut_used, lut_available], labels=['Used', 'Available'], 
                autopct='%1.1f%%', startangle=90)
        ax1.set_title(f'LUT Utilization\n({util["lut"]["utilization"]:.1f}%)')
        
        # FF utilization pie chart
        ff_used = util['ff']['used']
        ff_available = util['ff']['available'] - ff_used
        ax2.pie([ff_used, ff_available], labels=['Used', 'Available'], 
                autopct='%1.1f%%', startangle=90)
        ax2.set_title(f'FF Utilization\n({util["ff"]["utilization"]:.1f}%)')
        
        # BRAM utilization pie chart
        bram_used = util['bram']['used']
        bram_available = util['bram']['available'] - bram_used
        ax3.pie([bram_used, bram_available], labels=['Used', 'Available'], 
                autopct='%1.1f%%', startangle=90)
        ax3.set_title(f'BRAM Utilization\n({util["bram"]["utilization"]:.1f}%)')
        
        # DSP utilization pie chart
        dsp_used = util['dsp']['used']
        dsp_available = util['dsp']['available'] - dsp_used
        ax4.pie([dsp_used, dsp_available], labels=['Used', 'Available'], 
                autopct='%1.1f%%', startangle=90)
        ax4.set_title(f'DSP Utilization\n({util["dsp"]["utilization"]:.1f}%)')
        
        plt.tight_layout()
        plt.savefig(output_path / 'utilization.png', dpi=300, bbox_inches='tight')
        plt.close()
        
    def _plot_power_analysis(self, power_data, output_path):
        """Create power analysis plots"""
        if not power_data:
            return
            
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
        fig.suptitle('Power Analysis Dashboard', fontsize=16)
        
        # Get the latest power data
        latest_report = list(power_data.keys())[-1] if power_data else None
        if not latest_report:
            return
            
        power = power_data[latest_report]
        
        # Power breakdown pie chart
        dynamic = power['dynamic_power']
        static = power['static_power']
        ax1.pie([dynamic, static], labels=['Dynamic', 'Static'], 
                autopct='%1.2f W', startangle=90)
        ax1.set_title(f'Power Breakdown\nTotal: {power["total_power"]:.2f} W')
        
        # Power trend (if multiple reports available)
        reports = list(power_data.keys())
        total_powers = [power_data[r]['total_power'] for r in reports]
        dynamic_powers = [power_data[r]['dynamic_power'] for r in reports]
        static_powers = [power_data[r]['static_power'] for r in reports]
        
        x_pos = range(len(reports))
        ax2.plot(x_pos, total_powers, 'o-', label='Total Power', linewidth=2)
        ax2.plot(x_pos, dynamic_powers, 's-', label='Dynamic Power', linewidth=2)
        ax2.plot(x_pos, static_powers, '^-', label='Static Power', linewidth=2)
        ax2.set_xlabel('Report')
        ax2.set_ylabel('Power (W)')
        ax2.set_title('Power Trend')
        ax2.legend()
        ax2.set_xticks(x_pos)
        ax2.set_xticklabels(reports, rotation=45)
        
        plt.tight_layout()
        plt.savefig(output_path / 'power_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()
        
    def _generate_html_dashboard(self, results, output_path):
        """Generate HTML dashboard"""
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Xilinx Design Performance Dashboard</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
        .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
        .metrics {{ display: flex; justify-content: space-around; flex-wrap: wrap; }}
        .metric {{ text-align: center; margin: 10px; padding: 15px; background-color: #f9f9f9; border-radius: 5px; }}
        .metric-value {{ font-size: 24px; font-weight: bold; }}
        .metric-label {{ font-size: 14px; color: #666; }}
        .pass {{ color: green; }}
        .fail {{ color: red; }}
        .warning {{ color: orange; }}
        img {{ max-width: 100%; height: auto; margin: 10px 0; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Xilinx Design Performance Dashboard</h1>
        <p>Generated on: {results['timestamp']}</p>
    </div>
    
    <div class="section">
        <h2>Timing Summary</h2>
        <div class="metrics">
"""
        
        # Add timing metrics
        if results['timing']:
            latest_timing = list(results['timing'].values())[-1]
            wns = latest_timing.get('wns', 0)
            tns = latest_timing.get('tns', 0)
            failing_eps = latest_timing.get('failing_endpoints', 0)
            
            wns_class = 'pass' if wns >= 0 else 'fail'
            tns_class = 'pass' if tns >= 0 else 'fail'
            eps_class = 'pass' if failing_eps == 0 else 'fail'
            
            html_content += f"""
            <div class="metric">
                <div class="metric-value {wns_class}">{wns:.3f} ns</div>
                <div class="metric-label">Worst Negative Slack</div>
            </div>
            <div class="metric">
                <div class="metric-value {tns_class}">{tns:.3f} ns</div>
                <div class="metric-label">Total Negative Slack</div>
            </div>
            <div class="metric">
                <div class="metric-value {eps_class}">{failing_eps}</div>
                <div class="metric-label">Failing Endpoints</div>
            </div>
"""
        
        html_content += """
        </div>
        <img src="timing_analysis.png" alt="Timing Analysis">
    </div>
    
    <div class="section">
        <h2>Resource Utilization</h2>
        <div class="metrics">
"""
        
        # Add utilization metrics
        if results['utilization']:
            latest_util = list(results['utilization'].values())[-1]
            
            for resource in ['lut', 'ff', 'bram', 'dsp']:
                if resource in latest_util:
                    util_pct = latest_util[resource]['utilization']
                    util_class = 'pass' if util_pct < 80 else 'warning' if util_pct < 95 else 'fail'
                    
                    html_content += f"""
            <div class="metric">
                <div class="metric-value {util_class}">{util_pct:.1f}%</div>
                <div class="metric-label">{resource.upper()} Utilization</div>
            </div>
"""
        
        html_content += """
        </div>
        <img src="utilization.png" alt="Resource Utilization">
    </div>
    
    <div class="section">
        <h2>Power Analysis</h2>
        <div class="metrics">
"""
        
        # Add power metrics
        if results['power']:
            latest_power = list(results['power'].values())[-1]
            total_power = latest_power.get('total_power', 0)
            dynamic_power = latest_power.get('dynamic_power', 0)
            static_power = latest_power.get('static_power', 0)
            
            html_content += f"""
            <div class="metric">
                <div class="metric-value">{total_power:.2f} W</div>
                <div class="metric-label">Total Power</div>
            </div>
            <div class="metric">
                <div class="metric-value">{dynamic_power:.2f} W</div>
                <div class="metric-label">Dynamic Power</div>
            </div>
            <div class="metric">
                <div class="metric-value">{static_power:.2f} W</div>
                <div class="metric-label">Static Power</div>
            </div>
"""
        
        html_content += """
        </div>
        <img src="power_analysis.png" alt="Power Analysis">
    </div>
    
</body>
</html>
"""
        
        with open(output_path / 'dashboard.html', 'w') as f:
            f.write(html_content)
            
    def save_results_json(self, results, output_file):
        """Save results to JSON file"""
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)

def main():
    parser = argparse.ArgumentParser(description='Xilinx Performance Analyzer')
    parser.add_argument('--reports-dir', required=True, help='Directory containing report files')
    parser.add_argument('--output-dir', default='dashboard', help='Output directory for dashboard')
    parser.add_argument('--json-output', help='JSON output file for results')
    
    args = parser.parse_args()
    
    analyzer = XilinxPerformanceAnalyzer(args.reports_dir)
    results = analyzer.analyze_all_reports()
    
    # Generate dashboard
    analyzer.generate_performance_dashboard(results, args.output_dir)
    
    # Save JSON results if requested
    if args.json_output:
        analyzer.save_results_json(results, args.json_output)
    
    print(f"Dashboard generated in: {args.output_dir}")
    print(f"Open {args.output_dir}/dashboard.html in your browser")

if __name__ == '__main__':
    main()
