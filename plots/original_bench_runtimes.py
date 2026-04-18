import matplotlib.pyplot as plt
import numpy as np
import os

def parse_runtimes(file_path):
    results = {}
   
    with open(file_path, 'r') as f:
        for line in f:
            if 'Program' in line or '─' in line or not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 3:
                prog = parts[0]
                # Index 1: Base/L0, Index 2: Opt/L2
                base_val = float(parts[1].replace('s', ''))
                opt_val = float(parts[2].replace('s', ''))
                results[prog] = (base_val, opt_val)
    return results

def plot_clustered_stacked(o0_file, o2_file, sz_l0_path, sz_l2_path, output_png):
    data_o0 = parse_runtimes(f"results/{o0_file}")
    data_o2 = parse_runtimes(f"results/{o2_file}")
    
    # Load SanRazor results from the specific paths provided
    sz_o0 = parse_runtimes(sz_l0_path)
    sz_o2 = parse_runtimes(sz_l2_path)

    # plot benchmarks that exist in all files
    programs = sorted(list(set(data_o0.keys()) & set(data_o2.keys()) & set(sz_o0.keys())))

    # O2 values 
    base_o2 = np.array([data_o2[p][0] for p in programs])
    opt_o2 = np.array([data_o2[p][1] for p in programs])
    sz_o2_vals = np.array([sz_o2[p][1] for p in programs]) # Use their Opt column

    # O0 values 
    base_o0 = np.array([data_o0[p][0] for p in programs])
    opt_o0 = np.array([data_o0[p][1] for p in programs])
    sz_o0_vals = np.array([sz_o0[p][1] for p in programs])

    # get the difference between the flags 
    base_diff = base_o0 - base_o2
    opt_diff = opt_o0 - opt_o2
    sz_diff = sz_o0_vals - sz_o2_vals

    x = np.arange(len(programs))
    width = 0.25 

    plt.figure(figsize=(16, 8))

    # plot baseline 
    plt.bar(x - width, base_o2, width, label='Base (O2)', color='#ff7bac')
    plt.bar(x - width, base_diff, width, bottom=base_o2, label='Base (O0)', color='#ff7bac', alpha=0.4)

    # plot optimized 
    plt.bar(x, opt_o2, width, label='Opt (O2)', color='#52a5ce')
    plt.bar(x, opt_diff, width, bottom=opt_o2, label='Opt (O0)', color='#52a5ce', alpha=0.4)

    # plot Sanrazor
    plt.bar(x + width, sz_o2_vals, width, label='SanRazor (O2)', color='#7ed6a5')
    plt.bar(x + width, sz_diff, width, bottom=sz_o2_vals, label='SanRazor (O0)', color='#7ed6a5', alpha=0.4)


    # formatting
    plt.ylabel('Execution Time (seconds)', fontweight='bold')
    plt.xlabel('Benchmarks', fontweight='bold')
    plt.title('Original Benchmarked Runtimes across Sanitizers', fontsize=14, fontweight='bold')
    plt.xticks(x, programs, rotation=30, ha='right')
    
    plt.legend(loc='upper left', ncol=3) # 3 columns for 3 tools
    plt.grid(axis='y', linestyle='--', alpha=0.3)

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)

# call with sanitizer paths
plot_clustered_stacked(
    "table_O0.txt", 
    "table_O2.txt", 
    "sanrazor-results/L0/results/table.txt", 
    "sanrazor-results/L2/results/table.txt", 
    "plots/runtimes_plot.png"
)