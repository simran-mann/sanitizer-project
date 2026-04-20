import matplotlib.pyplot as plt
import numpy as np
import os

def parse_runtimes(file_path, is_sanrazor=False):
    results = {}
    with open(file_path, 'r') as f:
        for line in f:
            # skip headers and separators
            if any(x in line for x in ['Benchmark', 'Program', '─', '───']) or not line.strip():
                continue
            
            parts = line.split()
            try:
                prog = parts[0]
                if is_sanrazor:
                    results[prog] = {
                        'Base':  float(parts[1].replace('s', '')),
                        'SanRz': float(parts[2].replace('s', ''))
                    }
                else:
                    # [Benchmark, Baseline, ASan, ToolBase, ToolOpt]
                    results[prog] = {
                        'Base':     float(parts[1].replace('s', '')),
                        'ASan':     float(parts[2].replace('s', '')),
                        'ToolBase': float(parts[3].replace('s', '')),
                        'ToolOpt':  float(parts[4].replace('s', ''))
                    }
            except (ValueError, IndexError):
                continue
    return results

def plot_all_tools(tool_file, sz_file, output_png):
    # parse data
    tool_data = parse_runtimes(tool_file, is_sanrazor=False)
    sz_data = parse_runtimes(sz_file, is_sanrazor=True)

    # get stats 
    stats = sorted(list(set(tool_data.keys()) & set(sz_data.keys())))

    # get runtime values 
    baselines   = [tool_data[s]['Base'] for s in stats]
    asans       = [tool_data[s]['ASan'] for s in stats]
    tool_bases  = [tool_data[s]['ToolBase'] for s in stats]
    tool_opts   = [tool_data[s]['ToolOpt'] for s in stats]
    sz_bases    = [sz_data[s]['Base'] for s in stats]
    sz_opts     = [sz_data[s]['SanRz'] for s in stats]

    x = np.arange(len(stats))
    width = 0.13  

    plt.figure(figsize=(14, 7))

    # plot bars
    plt.bar(x - 2.5*width, baselines,  width, label='Base',         color='#95a5a6') 
    plt.bar(x - 1.5*width, asans,      width, label='ASan',         color='#e4568b') 
    plt.bar(x - 0.5*width, tool_bases, width, label='ToolBase',     color='#ffcb77') 
    plt.bar(x + 0.5*width, tool_opts,  width, label='ToolOpt',      color='#24e5d2') 
    plt.bar(x + 1.5*width, sz_bases,   width, label='SanRazor Base',color='#c06226') 
    plt.bar(x + 2.5*width, sz_opts,    width, label='SanRazor Opt', color='#2584a7') 

    # formatting
    plt.ylabel('Execution Time (seconds)', fontweight='bold')
    plt.xlabel('Local Benchmarks', fontweight='bold')
    plt.title('Sanitizer Runtimes across Local Benchmarks', fontsize=14, fontweight='bold')
    plt.xticks(x, stats, rotation=25, ha='right')
    
    # format legend 
    plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
    plt.grid(axis='y', linestyle='--', alpha=0.3)
    plt.tight_layout()

    # save plot
    output_dir = os.path.dirname(output_png)
    plt.savefig(output_png, dpi=300)

# execute the plotting function
plot_all_tools(
    "results/local_bench/O2/runtime_summary.txt", 
    "sanrazor-results/L2/results/table.txt", 
    "plots/imgs/local_runtimes_plot.png"
)