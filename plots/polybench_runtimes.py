import matplotlib.pyplot as plt
import numpy as np
import os

def parse_runtimes(file_path):
    results = {}
        
    with open(file_path, 'r') as f:
        for line in f:
            # skip table header lines
            if 'Program' in line or '─' in line or not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 3:
                prog = parts[0]
                base_val = float(parts[1].replace('s', ''))
                opt_val = float(parts[2].replace('s', ''))
                results[prog] = (base_val, opt_val)
    return results

def plot_polybench_dual_stacked(o0_path, o2_path, output_png):
    # Load data from your specific paths
    data_o0 = parse_runtimes(o0_path)
    data_o2 = parse_runtimes(o2_path)

    #plot benchmarks that exist in both files
    programs = sorted(list(set(data_o0.keys()) & set(data_o2.keys())))

    # get O2 values 
    base_o2 = np.array([data_o2[p][0] for p in programs])
    opt_o2 = np.array([data_o2[p][1] for p in programs])

    # get O0 values 
    base_o0 = np.array([data_o0[p][0] for p in programs])
    opt_o0 = np.array([data_o0[p][1] for p in programs])

    # get O0-O2 difference and add to stacked bar 
    base_diff = np.maximum(0, base_o0 - base_o2)
    opt_diff = np.maximum(0, opt_o0 - opt_o2)

    # plot
    x = np.arange(len(programs))
    width = 0.35 

    plt.figure(figsize=(16, 8))

    # plot base
    plt.bar(x - width/2, base_o2, width, label='Base (O2)', color='#ff7bac')
    plt.bar(x - width/2, base_diff, width, bottom=base_o2, label='Base (O0)', color='#ff7bac', alpha=0.4)

    # plot opt
    plt.bar(x + width/2, opt_o2, width, label='Opt (O2)', color='#52a5ce')
    plt.bar(x + width/2, opt_diff, width, bottom=opt_o2, label='Opt (O0)', color='#52a5ce', alpha=0.4)

    # plot formatting
    plt.ylabel('Execution Time (seconds)', fontweight='bold')
    plt.xlabel('Benchmarks', fontweight='bold')
    plt.title('Polybenched Runtimes across Sanitizers', fontsize=14, fontweight='bold')
    plt.xticks(x, programs, rotation=30, ha='right')
    
    plt.legend(loc='upper right', ncol=2)
    plt.grid(axis='y', linestyle='--', alpha=0.3)

    plt.tight_layout()
    
    # save plot
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)

if __name__ == "__main__":
    O0_PATH = "results/polybench_O0/polybench_summary_table.txt"
    O2_PATH = "results/polybench_O2/polybench_summary_table.txt"
    OUTPUT = "plots/polybench_runtimes.png"
    
    plot_polybench_dual_stacked(O0_PATH, O2_PATH, OUTPUT)