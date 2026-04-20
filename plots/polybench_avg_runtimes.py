import matplotlib.pyplot as plt
import numpy as np
import os

# define the PolyBench groups for averaging
GROUPS = {
    'Datamining': ['correlation', 'covariance'],
    'LA Kernels (BLAS)': ['2mm', '3mm', 'atax', 'bicg', 'doitgen', 'gemm', 'gemver', 
                          'gesummv', 'mvt', 'symm', 'syr2k', 'syrk', 'trisolv', 'trmm'],
    'LA Solvers': ['cholesky', 'durbin', 'gramschmidt', 'lu', 'ludcmp'],
    'Medley': ['floyd-warshall', 'reg_detect', 'dynprog'],
    'Stencils': ['adi', 'fdtd-2d', 'fdtd-apml', 'jacobi-1d-imper', 'jacobi-2d-imper', 'seidel-2d']
}

def parse_runtimes(file_path):
    results = {}
    if not os.path.exists(file_path):
        print(f"Warning: {file_path} not found.")
        return results

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            # skip headers, decorators, and empty lines
            if any(x in line for x in ['Benchmark', 'Program', '─', '───']) or not line.strip():
                continue
            
            parts = line.split()
            if len(parts) < 5:
                continue

            prog = parts[0]
            results[prog] = {
                'Base':     float(parts[1].replace('s', '')),
                'ASan':     float(parts[2].replace('s', '')),
                'ToolBase': float(parts[3].replace('s', '')),
                'ToolOpt':  float(parts[4].replace('s', ''))
            }
    
    return results

def plot_all_tools_avg(tool_file, output_png):
    # parse the raw data
    tool_raw = parse_runtimes(tool_file)

    # compute average runtimes by group
    group_stats = []
    for group_name, members in GROUPS.items():
        # filter for benchmarks actually present in the file
        valid_benchmarks = [m for m in members if m in tool_raw]
        
        if valid_benchmarks:
            group_stats.append({
                'name': group_name,
                'Base':     np.mean([tool_raw[m]['Base']     for m in valid_benchmarks]),
                'ASan':     np.mean([tool_raw[m]['ASan']     for m in valid_benchmarks]),
                'ToolBase': np.mean([tool_raw[m]['ToolBase'] for m in valid_benchmarks]),
                'ToolOpt':  np.mean([tool_raw[m]['ToolOpt']  for m in valid_benchmarks])
            })

    # setup plot
    names = [s['name'] for s in group_stats]
    x = np.arange(len(names))
    width = 0.18 

    plt.figure(figsize=(14, 8))

    # plot bars
    plt.bar(x - 1.5*width, [s['Base']     for s in group_stats], width, label='Baseline', color='#95a5a6')
    plt.bar(x - 0.5*width, [s['ASan']     for s in group_stats], width, label='ASan',     color='#e4568b')
    plt.bar(x + 0.5*width, [s['ToolBase'] for s in group_stats], width, label='ToolBase', color='#ffcb77')
    plt.bar(x + 1.5*width, [s['ToolOpt']  for s in group_stats], width, label='ToolOpt',  color='#24e5d2')

    # formatting
    plt.title('Average Sanitizer Runtimes across PolyBench Domains', fontweight='bold', fontsize=16, pad=20)
    plt.ylabel('Average Runtime (seconds)', fontweight='bold')
    plt.xlabel('PolyBench Domains', fontweight='bold')
    plt.xticks(x, names, rotation=15)
    plt.legend()
    plt.grid(axis='y', linestyle='--', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_png, dpi=300)

# call function to plot runtimes
plot_all_tools_avg(
    "results/polybench/O2/runtime_summary.txt", 
    "plots/imgs/poly_avg_runtimes.png"
)