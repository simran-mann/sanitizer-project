import matplotlib.pyplot as plt
import numpy as np
import os
from matplotlib.patches import Patch

def parse_runtimes(file_path, is_sanrazor=False):
    results = {}
    if not os.path.exists(file_path):
        return results
    with open(file_path, 'r') as f:
        for line in f:
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
                    results[prog] = {
                        'Base':     float(parts[1].replace('s', '')),
                        'ASan':     float(parts[2].replace('s', '')),
                        'ToolBase': float(parts[3].replace('s', '')),
                        'ToolOpt':  float(parts[4].replace('s', ''))
                    }
            except (ValueError, IndexError):
                continue
    return results

def plot_all_tools(tool_file_o2, tool_file_o0, sz_file_o2, sz_file_o0, output_png):
    t_o2 = parse_runtimes(tool_file_o2)
    t_o0 = parse_runtimes(tool_file_o0)
    s_o2 = parse_runtimes(sz_file_o2, is_sanrazor=True)
    s_o0 = parse_runtimes(sz_file_o0, is_sanrazor=True)

    stats = sorted(list(set(t_o2.keys()) & set(s_o2.keys())))

    def get_val(data, bench, key):
        return data.get(bench, {}).get(key, 0)

    # values for O2 bars
    asans_o2     = [get_val(t_o2, s, 'ASan') for s in stats]
    tool_opts_o2 = [get_val(t_o2, s, 'ToolOpt') for s in stats]
    sz_opts_o2   = [get_val(s_o2, s, 'SanRz') for s in stats]

    # calculate the O0 part (the total O0 height is O2 + Diff)
    diff_asan    = [max(0, get_val(t_o0, s, 'ASan') - get_val(t_o2, s, 'ASan')) for s in stats]
    diff_topt    = [max(0, get_val(t_o0, s, 'ToolOpt') - get_val(t_o2, s, 'ToolOpt')) for s in stats]
    diff_szopt   = [max(0, get_val(s_o0, s, 'SanRz') - get_val(s_o2, s, 'SanRz')) for s in stats]

    x = np.arange(len(stats))
    width = 0.25 

    plt.figure(figsize=(14, 8))

    # plotting
    configs = [
        (asans_o2,     diff_asan,  -1, '#e4568b'),
        (tool_opts_o2, diff_topt,   0, '#24e5d2'),
        (sz_opts_o2,   diff_szopt,  1, '#2584a7')
    ]

    for o2_v, diff_v, offset, clr in configs:
        pos = x + offset * width
        plt.bar(pos, o2_v, width, color=clr)
        plt.bar(pos, diff_v, width, bottom=o2_v, color=clr, alpha=0.3)

    # create entries for each tool with both O2 and O0 indicators
    legend_elements = [
        Patch(facecolor='#e4568b', label='ASan O2'),
        Patch(facecolor='#e4568b', alpha=0.3, label='ASan O0'),
        Patch(facecolor='#24e5d2', label='ToolOpt O2'),
        Patch(facecolor='#24e5d2', alpha=0.3, label='ToolOpt O0'),
        Patch(facecolor='#2584a7', label='SanRazor O2'),
        Patch(facecolor='#2584a7', alpha=0.3, label='SanRazor O0'),
    ]

    plt.ylabel('Execution Time (s)', fontsize=20, fontweight='bold')
    plt.xlabel('Benchmarks', fontsize=20, fontweight='bold')
    plt.title('Sanitizer Runtimes: $O0$ vs. $O2$ Compiler Optimization Flags', fontsize=25, fontweight='bold')
    plt.xticks(x, stats, rotation=30, ha='right', fontsize=20, fontweight='bold')
    plt.yticks(fontsize=20)
    plt.ylim(0, 0.35)
    
    # columns to keep it tidy
    plt.legend(handles=legend_elements, ncol=3, fontsize=15, frameon=False, loc='upper left')
    
    plt.grid(axis='y', linestyle='--', alpha=0.2)
    plt.tight_layout()

    plt.savefig(output_png, dpi=300)
    plt.savefig("plots/imgs/local_O0_O2_runtimes_plot.pdf", bbox_inches="tight")

    # execute
plot_all_tools(
    "results/local_bench/O2/runtime_summary.txt", 
    "results/local_bench/O0/runtime_summary.txt", 
    "sanrazor-results/L2/results/table.txt", 
    "sanrazor-results/L0/results/table.txt", 
    "plots/imgs/local_O0_O2_runtimes_plot.png"
)
