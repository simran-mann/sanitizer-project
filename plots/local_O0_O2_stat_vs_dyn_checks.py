import matplotlib.pyplot as plt
import numpy as np
import os
from matplotlib.patches import Patch

def parse_reduction_data(check_path):
    results = {}
    if not os.path.exists(check_path):
        return results
    
    with open(check_path, 'r', encoding='utf-8') as f:
        for line in f:
            if any(x in line for x in ['Benchmark', '─', 'S-Base']) or not line.strip():
                continue
            
            parts = line.split()
            if len(parts) < 9: continue
            
            prog = parts[0]
            try:
                # Extract static and dynamic reduction percentages
                s_red = float(parts[4].replace('%', ''))
                d_red = float(parts[8].replace('%', ''))
                results[prog] = {'static': s_red, 'dynamic': d_red}
            except ValueError: continue
    return results

def plot_reduction_comparison(path_o2, path_o0, output_png):
    data_o2 = parse_reduction_data(path_o2)
    data_o0 = parse_reduction_data(path_o0)
    
    # Only plot benchmarks present in both sets
    stats = sorted(list(set(data_o2.keys()) & set(data_o0.keys())))

    # Helper to get values safely
    s_o2 = [data_o2[s]['static'] for s in stats]
    d_o2 = [data_o2[s]['dynamic'] for s in stats]
    
    # Calculate difference (O0 usually has different reduction stats)
    diff_s = [max(0, data_o0[s]['static'] - data_o2[s]['static']) for s in stats]
    diff_d = [max(0, data_o0[s]['dynamic'] - data_o2[s]['dynamic']) for s in stats]

    x = np.arange(len(stats))
    width = 0.35 
    plt.figure(figsize=(14, 8))

    # --- Plotting Static Reductions ---
    # O2 Base (Solid)
    plt.bar(x - width/2, s_o2, width, color='#a1a1f7', label='Static O2')
    # O0 Difference (Transparent)
    plt.bar(x - width/2, diff_s, width, bottom=s_o2, color='#a1a1f7', alpha=0.3, label='Static O0')

    # --- Plotting Dynamic Reductions ---
    # O2 Base (Solid)
    plt.bar(x + width/2, d_o2, width, color='#f7b557', label='Dynamic O2')
    # O0 Difference (Transparent)
    plt.bar(x + width/2, diff_d, width, bottom=d_o2, color='#f7b557', alpha=0.3, label='Dynamic O0')

    # Custom Legend
    legend_elements = [
        Patch(facecolor='#a1a1f7', label='Static O2'),
        Patch(facecolor='#a1a1f7', alpha=0.3, label='Static O0'),
        Patch(facecolor='#f7b557', label='Dynamic O2'),
        Patch(facecolor='#f7b557', alpha=0.3, label='Dynamic O0'),
    ]

    # Formatting
    plt.title('Check Reduction (%): $O0$ vs. $O2$ Compilation Flags', fontweight='bold', fontsize=25, pad=20)
    plt.ylabel('Reduction (%)', fontsize=20, fontweight='bold')
    plt.xlabel('Benchmarks', fontsize=20, fontweight='bold')
    plt.xticks(x, stats, fontsize=20, fontweight='bold', rotation=30, ha='right')
    plt.yticks(fontsize=18)
    plt.ylim(0, 110) 
    
    plt.legend(handles=legend_elements, ncol=2, fontsize=15, frameon=False, loc='upper left')
    plt.grid(axis='y', linestyle='--', alpha=0.3)
    
    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)
    plt.savefig("plots/imgs/local_O0_O2_stat_vs_dyn_checks.pdf", bbox_inches="tight")

# Execute
plot_reduction_comparison(
    "results/local_bench/O2/check_access_summary.txt", 
    "results/local_bench/O0/check_access_summary.txt", 
    "plots/imgs/local_O0_O2_stat_vs_dyn_checks.png"
)