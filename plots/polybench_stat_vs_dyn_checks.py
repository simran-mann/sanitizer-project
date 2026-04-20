import matplotlib.pyplot as plt
import numpy as np
import os

# define the polybench groups for averaging
GROUPS = {
    'Datamining': ['correlation', 'covariance'],
    'LA Kernels (BLAS)': ['2mm', '3mm', 'atax', 'bicg', 'doitgen', 'gemm', 'gemver', 
                          'gesummv', 'mvt', 'symm', 'syr2k', 'syrk', 'trisolv', 'trmm'],
    'LA Solvers': ['cholesky', 'durbin', 'gramschmidt', 'lu', 'ludcmp'],
    'Medley': ['floyd-warshall', 'reg_detect', 'dynprog'],
    'Stencils': ['adi', 'fdtd-2d', 'fdtd-apml', 'jacobi-1d-imper', 'jacobi-2d-imper', 'seidel-2d']
}

def parse_reduction_data(check_path):

    raw_results = {}
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
                    
                    raw_results[prog] = {
                        'static_red': s_red,
                        'dynamic_red': d_red
                    }
                except ValueError: continue
    else:
        print(f"Warning: Check summary path not found: {check_path}")
        return {}

    # average the data by group
    group_results = {}
    for group_name, members in GROUPS.items():
        s_list = [raw_results[m]['static_red'] for m in members if m in raw_results]
        d_list = [raw_results[m]['dynamic_red'] for m in members if m in raw_results]
        
        if s_list:
            group_results[group_name] = {
                'static_red': np.mean(s_list),
                'dynamic_red': np.mean(d_list)
            }
            
    return group_results

def plot_reduction(check_path, output_png):
    data = parse_reduction_data(check_path)
    # get the category names
    stats = list(data.keys())

    # get static and dynamic averaged values 
    s_vals = [data[s]['static_red'] for s in stats]
    d_vals = [data[s]['dynamic_red'] for s in stats]

    # plot figure size 
    x = np.arange(len(stats))
    width = 0.35
    plt.figure(figsize=(12, 7))

    # plot bars 
    stat = plt.bar(x - width/2, s_vals, width, label='Static', color='#a1a1f7')
    dyn = plt.bar(x + width/2, d_vals, width, label='Dynamic', color='#f7b557')

    # formatting
    plt.title('Average Check Reductions across PolyBench Domains', fontweight='bold', fontsize=15, pad=20)
    plt.ylabel('Average Reduction (%)', fontweight='bold')
    plt.xlabel('PolyBench Domains', fontweight='bold')
    plt.xticks(x, stats, rotation=15)
    plt.ylim(0, 40) 
    plt.legend()
    plt.grid(axis='y', linestyle=':', alpha=0.7)

    # add text labels on top of bars
    def autolabel(rects):
        for rect in rects:
            height = rect.get_height()
            plt.annotate(f'{height:.1f}%',
                        xy=(rect.get_x() + rect.get_width() / 2, height),
                        xytext=(0, 3), 
                        textcoords="offset points",
                        ha='center', va='bottom', fontsize=9, fontweight='bold')

    autolabel(stat)
    autolabel(dyn)

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)
    print(f"Grouped average graph saved to: {output_png}")

# call to plot averaged static and dynamic reductions 
plot_reduction(
    "results/polybench/O2/check_access_summary.txt", 
    "plots/imgs/poly_stat_dyn_checks_avg.png"
)