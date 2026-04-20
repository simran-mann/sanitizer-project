import matplotlib.pyplot as plt
import numpy as np
import os

def parse_data(tool_path, sz_path):
    tool_results = {}
    with open(tool_path, 'r', encoding='utf-8') as f:
        for line in f:
            if any(x in line for x in ['Benchmark', '─', 'Program']) or not line.strip():
                continue
            parts = line.split()
            if len(parts) < 5: continue
            prog = parts[0]
            try:
                tool_results[prog] = {
                    'base': float(parts[1].replace('s', '')),
                    'asan': float(parts[2].replace('s', '')),
                    'opt':  float(parts[4].replace('s', ''))
                }
            except ValueError: continue

    sz_results = {}
    with open(sz_path, 'r', encoding='utf-8') as f:
        for line in f:
            if any(x in line for x in ['Program', '─', 'Benchmark']) or not line.strip():
                continue
            parts = line.split()
            if len(parts) < 3: continue
            prog = parts[0]
            try:
                sz_results[prog] = {
                    'base': float(parts[1].replace('s', '')),
                    'sr':   float(parts[2].replace('s', ''))
                }
            except ValueError: continue
            
    return tool_results, sz_results

def plot_overheads(tool_path, sz_path, output_png):
    t_data, sz_data = parse_data(tool_path, sz_path)
    
    programs = sorted(list(set(t_data.keys()) & set(sz_data.keys())))
    
    if not programs:
        print("Error: No matching benchmark names found between the two files.")
        return

    # get overheads 
    asan_oh = [t_data[p]['asan'] / t_data[p]['base'] for p in programs]
    tool_oh = [t_data[p]['opt'] / t_data[p]['base'] for p in programs]
    
    # compute sanrazor overhead
    sz_oh = [sz_data[p]['sr'] / sz_data[p]['base'] for p in programs]

    # plot
    x = np.arange(len(programs))
    width = 0.25
    plt.figure(figsize=(12, 7))

    # plot the overhead bars 
    plt.bar(x - width, asan_oh, width, label='ASan', color='#e4568b')
    plt.bar(x, tool_oh, width, label='ToolOpt', color='#24e5d2')
    plt.bar(x + width, sz_oh, width, label='SanRazor', color='#2584a7')

    # Baseline reference line
    plt.axhline(y=1.0, color='black', linestyle='--', alpha=0.8, label='Base (No Tool)')

    # Labels and Titles
    plt.title('Sanitizer Overhead across Local Benchmarks', fontweight='bold', fontsize=14)
    plt.ylabel('Slowdown Factor (x)', fontweight='bold')
    plt.xlabel('Local Benchmarks', fontweight='bold')
    plt.xticks(x, programs, rotation=25)
    plt.legend()
    plt.grid(axis='y', linestyle=':', alpha=0.7)

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)
    print(f"Unified overhead graph saved as: {output_png}")

plot_overheads(
    "results/local_bench/O2/runtime_summary.txt", 
    "sanrazor-results/L2/results/table.txt", 
    "plots/imgs/local_overhead_plot.png"
)