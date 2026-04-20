import matplotlib.pyplot as plt
import numpy as np
import os

def parse_checks(file_path):
    results = {}
    if not os.path.exists(file_path):
        print(f"Warning: File not found: {file_path}")
        return results
        
    with open(file_path, 'r') as f:
        for line in f:
            if 'Program' in line or '─' in line or not line.strip():
                continue
            parts = line.split()
            # Index 0: Program, Index 4: Total Checks, Index 5: Final Checks
            if len(parts) >= 6:
                prog = parts[0]
                total_checks = float(parts[4])
                final_checks = float(parts[5])
                results[prog] = (total_checks, final_checks)
    return results

def plot_clustered_stacked_checks(o0_file, o2_file, output_png):
    # Load data
    data_o0 = parse_checks(o0_file)
    data_o2 = parse_checks(o2_path)

    # Sync programs
    programs = sorted(list(set(data_o0.keys()) & set(data_o2.keys())))

    # --- O2 Data ---
    # Base of bar: Final checks remaining
    # Top of bar: Checks removed (Total - Final)
    o2_final = np.array([data_o2[p][1] for p in programs])
    o2_removed = np.array([data_o2[p][0] for p in programs]) - o2_final

    # --- O0 Data ---
    o0_final = np.array([data_o0[p][1] for p in programs])
    o0_removed = np.array([data_o0[p][0] for p in programs]) - o0_final

    x = np.arange(len(programs))
    width = 0.35 

    plt.figure(figsize=(16, 8))

    # Plot O0 Cluster (Left)
    plt.bar(x - width/2, o0_final, width, label='O0: Final Checks', color='#ff7bac')
    plt.bar(x - width/2, o0_removed, width, bottom=o0_final, label='O0: Removed Checks', color='#ff7bac', alpha=0.4)

    # Plot O2 Cluster (Right)
    plt.bar(x + width/2, o2_final, width, label='O2: Final Checks', color='#52a5ce')
    plt.bar(x + width/2, o2_removed, width, bottom=o2_final, label='O2: Removed Checks', color='#52a5ce', alpha=0.4)

    # Formatting
    plt.ylabel('Number of Checks', fontweight='bold')
    plt.xlabel('Benchmarks', fontweight='bold')
    plt.title('Sanitizer Check Reduction: O0 vs O2', fontsize=14, fontweight='bold')
    plt.xticks(x, programs, rotation=30, ha='right')
    
    plt.legend(loc='upper left', ncol=2)
    plt.grid(axis='y', linestyle='--', alpha=0.3)

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.savefig(output_png, dpi=300)
    print(f"Checks plot saved to: {output_png}")

if __name__ == "__main__":
    o0_path = "results/polybench_O0/polybench_summary_table.txt"
    o2_path = "results/polybench_O2/polybench_summary_table.txt"
    output = "plots/polybench_checks_reduction.png"
    
    plot_clustered_stacked_checks(o0_path, o2_path, output)