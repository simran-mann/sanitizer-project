import matplotlib.pyplot as plt
import numpy as np
import os

def parse_reduction_data(check_path):
    """
    Parses the check_access_summary.txt table.
    Format: Benchmark S-Base S-Opt S-Rem S-Red% D-Base D-Opt D-Rem D-Red%
    """
    results = {}
    if os.path.exists(check_path):
        with open(check_path, 'r', encoding='utf-8') as f:
            for line in f:
                # Skip headers and separators
                if any(x in line for x in ['Benchmark', '─', 'S-Base']) or not line.strip():
                    continue
                
                parts = line.split()
                if len(parts) < 9: continue
                
                prog = parts[0]
                try:
                    # clean the % sign and convert to float
                    s_red = float(parts[4].replace('%', ''))
                    d_red = float(parts[8].replace('%', ''))
                    
                    results[prog] = {
                        'static_red': s_red,
                        'dynamic_red': d_red
                    }
                except ValueError: continue
    else:
        print(f"Warning: Check summary path not found: {check_path}")
            
    return results

def plot_reduction(check_path, output_png):
    data = parse_reduction_data(check_path)
    stats = sorted(list(data.keys()))

    # get static and dynamic values 
    s_vals = [data[s]['static_red'] for s in stats]
    d_vals = [data[s]['dynamic_red'] for s in stats]

    # plot figure size 
    x = np.arange(len(stats))
    width = 0.35
    plt.figure(figsize=(12, 7))

    # plot bars
    stat = plt.bar(x - width/2, s_vals, width, label='Static', color='#a1a1f7')
    dyn = plt.bar(x + width/2, d_vals, width, label='Dynamic', color='#f7b557')

    # Styling
    plt.title('Tool Optimized Static and Dynamic Check Reductions across Local Benchmarks', fontweight='bold', fontsize=15, pad=20)
    plt.ylabel('Reduction Percentage (%)', fontweight='bold')
    plt.xlabel('Benchmarks', fontweight='bold')
    plt.xticks(x, stats, rotation=25)
    plt.ylim(0, max(max(s_vals), max(d_vals)) + 10)
    plt.legend()
    plt.grid(axis='y', linestyle=':', alpha=0.7)

    # add text labels on top of bars
    def autolabel(rects):
        for rect in rects:
            height = rect.get_height()
            plt.annotate(f'{int(height)}%',
                        xy=(rect.get_x() + rect.get_width() / 2, height),
                        xytext=(0, 3), 
                        textcoords="offset points",
                        ha='center', va='bottom', fontsize=9, fontweight='bold')

    autolabel(stat)
    autolabel(dyn)

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)

# call to plot static and dynamic reductions 
plot_reduction(
    "results/local_bench/O2/check_access_summary.txt", 
    "plots/imgs/local_stat_dyn_checks.png"
)