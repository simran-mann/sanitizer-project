import matplotlib.pyplot as plt
import numpy as np
import os

def parse_runtimes(file_path, is_sanrazor=False):
    results = {}
    if not os.path.exists(file_path):
        print(f"Warning: {file_path} not found.")
        return results

    with open(file_path, 'r') as f:
        for line in f:
            # Skip headers and separators
            if any(x in line for x in ['Benchmark', 'Program', '─', '───']) or not line.strip():
                continue
            
            parts = line.split()
            try:
                prog = parts[0]
                if is_sanrazor:
                    # SanRazor Table format: [Program, Base, SanRz, Speedup, Checks]
                    # We only care about the SanRazor time (Index 2)
                    results[prog] = float(parts[2].replace('s', ''))
                else:
                    # [Benchmark, Baseline, ASan, ToolBase, ToolOpt]
                    results[prog] = {
                        'Base': float(parts[1].replace('s', '')),
                        'ASan':     float(parts[2].replace('s', '')),
                        'ToolBase': float(parts[3].replace('s', '')),
                        'ToolOpt':  float(parts[4].replace('s', ''))
                    }
            except (ValueError, IndexError):
                continue
    return results

def plot_all_tools(tool_file, sz_file, output_png):
    # Parse data
    tool_data = parse_runtimes(tool_file, is_sanrazor=False)
    sz_data = parse_runtimes(sz_file, is_sanrazor=True)

    # plot stats that exist in BOTH files
    stats = sorted(list(set(tool_data.keys()) & set(sz_data.keys())))


    # Extract values for plotting
    baselines = [tool_data[s]['Base'] for s in stats]
    asans     = [tool_data[s]['ASan'] for s in stats]
    tool_bases = [tool_data[s]['ToolBase'] for s in stats]
    tool_opts  = [tool_data[s]['ToolOpt'] for s in stats]
    sz_vals    = [sz_data[s] for s in stats]

    x = np.arange(len(stats))
    width = 0.15  # Smaller width to fit 5 bars

    plt.figure(figsize=(14, 7))

    # Plot the 5 bars per benchmark
    plt.bar(x - 2*width, baselines,  width, label='Base', color='#95a5a6') 
    plt.bar(x - width,   asans,      width, label='ASan',     color='#e4568b') 
    plt.bar(x,           tool_bases, width, label='ToolBase', color='#ffcb77') 
    plt.bar(x + width,   tool_opts,  width, label='ToolOpt',  color='#24e5d2') 
    plt.bar(x + 2*width, sz_vals,    width, label='SanRazor', color='#2584a7') 

    # Formatting
    plt.ylabel('Execution Time (seconds)', fontweight='bold')
    plt.xlabel('Local Benchmarks', fontweight='bold')
    plt.title('Local Benchmarked Runtimes across Sanitizers', fontsize=14, fontweight='bold')
    plt.xticks(x, stats, rotation=25, ha='right')
    
    plt.legend()
    plt.grid(axis='y', linestyle='--', alpha=0.3)
    plt.tight_layout()

    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)
    print(f"Plot saved to {output_png}")

# Change these paths to point to your actual O0 or O2 results
plot_all_tools(
    "results/local_bench/O2/runtime_summary.txt", 
    "sanrazor-results/L2/results/table.txt", 
    "plots/local_runtimes_plot.png"
)