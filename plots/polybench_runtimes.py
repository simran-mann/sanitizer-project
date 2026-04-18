import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import re

def parse_table(file_path):
    data = []
    # Regex to capture the program name and the first two time columns
    # It strips the 's' from the times (e.g., 11.022s -> 11.022)
    pattern = re.compile(r'^(\S+)\s+([\d.]+)s\s+([\d.]+)s')
    
    with open(file_path, 'r') as f:
        for line in f:
            match = pattern.match(line.strip())
            if match:
                prog, base, opt = match.groups()
                data.append([prog, float(base), float(opt)])
    
    return pd.DataFrame(data, columns=['Program', 'Baseline', 'Optimized'])

def plot_runtimes(df):
    plt.figure(figsize=(12, 6))
    
    bar_width = 0.35
    index = np.arange(len(df))
    
    # Create the bars
    plt.bar(index, df['Baseline'], bar_width, label='Base', color='#ff7bac', alpha=0.8)
    plt.bar(index + bar_width, df['Optimized'], bar_width, label='Opt', color='#52a5ce', alpha=0.8)
    
    # Formatting
    plt.xlabel('Benchmarks', fontweight='bold')
    plt.ylabel('Runtime (seconds)', fontweight='bold')
    plt.title('Polybenched Runtimes across Sanitizers', fontsize=14)
    plt.xticks(index + bar_width / 2, df['Program'], rotation=45, ha='right')
    plt.legend()
    plt.grid(axis='y', linestyle='--', alpha=0.6)
    
    plt.tight_layout()
    plt.savefig('plots/polybench_runtimes.png')

if __name__ == "__main__":
    table_path = 'results/polybench_O0/polybench_summary_table.txt'
    try:
        df = parse_table(table_path)
        plot_runtimes(df)
    except FileNotFoundError:
        print(f"Error: Could not find {table_path}")