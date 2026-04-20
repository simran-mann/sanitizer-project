import matplotlib.pyplot as plt
import numpy as np
import os

def parse_data(tool_path):
    results = {}

    with open(tool_path, 'r', encoding='utf-8') as f:
        for line in f:
            # skip headers, decorators, and empty lines
            if any(x in line for x in ['Benchmark', '─', 'Program']) or not line.strip():
                continue
            
            parts = line.split()
            if len(parts) < 5: 
                continue
                
            prog = parts[0]
            try:
                results[prog] = {
                    'base': float(parts[1].replace('s', '')),
                    'asan': float(parts[2].replace('s', '')),
                    'opt':  float(parts[4].replace('s', ''))
                }
            except ValueError: 
                continue
                
    return results

def plot_local_overheads(tool_path, output_png):
    data = parse_data(tool_path)
    
    programs = sorted(data.keys())
    
    if not programs:
        print("No data found to plot.")
        return

    # compute overheads (runtime / base)
    asan_oh = [data[p]['asan'] / data[p]['base'] for p in programs]
    tool_oh = [data[p]['opt'] / data[p]['base'] for p in programs]
    
    # plot setip
    x = np.arange(len(programs))
    width = 0.35
    plt.figure(figsize=(12, 7))

    # Plot the overhead bars
    plt.bar(x - width/2, asan_oh, width, label='ASan Overhead', color='#e4568b')
    plt.bar(x + width/2, tool_oh, width, label='ToolOpt Overhead', color='#24e5d2')

    # base reference set at 1.0
    plt.axhline(y=1.0, color='black', linestyle='--', alpha=0.8, label='Base (No Tool)')

    # Labels and Titles
    plt.title('Sanitizer Overhead across PolyBench Domains', fontweight='bold', fontsize=14)
    plt.ylabel('Slowdown Factor (x)', fontweight='bold')
    plt.xlabel('PolyBench Domains', fontweight='bold')
    plt.xticks(x, programs, rotation=25)
    plt.legend()
    plt.grid(axis='y', linestyle=':', alpha=0.7)

    plt.tight_layout()
    
    # save the plot
    output_dir = os.path.dirname(output_png)
    plt.savefig(output_png, dpi=300)

# call function to plot overhead
plot_local_overheads(
    "results/local_bench/O2/runtime_summary.txt", 
    "plots/imgs/poly_overhead_plot.png"
)