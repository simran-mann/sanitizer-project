## Instructions for running the tool


First you will need to initialize the course environment if you are working on CSIL. Otherwise you will need to ensure you have LLVM 21.1.8  and CMake installed in your environment. 

```bash
source  /usr/shared/CMPT/faculty/wsumner/base/env745/bin/activate
```
### If you wish to run the the local benchmark suite you must:
Ensure you are in the project root directory: `sanitizer-project` and run the following:

```
mkdir build && cd build
cmake .. -DLLVM_DIR=$(llvm-config --cmakedir)
cd ..
./scripts/build_and_run.sh 
```
This will run the local benchmarks with clang optimization level O0, if you wish to run with a different optimization level it can be included as a command line argument
```
./scripts/build_and_run.sh O2
```

The results will be saved to the `results` folder:
- `results/local_bench/<opt_level>/check_access_summary.txt`- check access summary (static and dynamic checks)
- `results/local_bench/<opt_level>/runtime_summary.txt`     - runtimes for each benchmark plus some calculated stats

The executables for each benchmark will be saved to the `build` folder:
- `build/local_bench/<opt_level>/<benchmark>_{baseline,asan,tool_base,tool_opt}`

The instrumented IRs for each benchmark will also be saved to the `results` folder:
- `results/local_bench/<opt_level>/<benchmark>/<benchmark>_{baseline,too_base,tool_opt}.ll`

### If you wish to run the the polyhedral benchmark suite you must:
- download the benchmark suite 
```
wget https://www.cs.colostate.edu/~pouchet/software/polybench/download/polybench-3.1.tar.gz
```
- extract the compressed benchmarks
```
tar -xvf polybench-3.1.tar.gz
```
- take note of the relative path to the 'polybench-3.1' directory with respect to the project root directory
- ensure you are in the project root directory: `sanitizer-project` and run the following 
```
mkdir build && cd build
cmake .. -DLLVM_DIR=$(llvm-config --cmakedir)
cd ..

# examples of command line arguments to run the script:
./scripts/build_and_run.sh --polybench 'relative/path/to/polybench-3.1'
./scripts/build_and_run.sh --polybench 'relative/path/to/polybench-3.1' O2
```

The results will be saved to the `results` folder:
- `results/poly_bench/<opt_level>/check_access_summary.txt`- check access summary (static and dynamic checks)
- `results/poly_bench/<opt_level>/runtime_summary.txt`     - runtimes for each benchmark plus some calculated stats

The executables for each benchmark will be saved to the `build` folder:
- `build/poly_bench/<opt_level>/<benchmark>_{baseline,asan,tool_base,tool_opt}`

The instrumented IRs for each benchmark will also be saved to the `results` folder:
- `results/poly_bench/<opt_level>/<benchmark>/<benchmark>_{baseline,too_base,tool_opt}.ll`

To see more information about the benchmark suite visit:
```
https://www.cs.colostate.edu/~pouchet/software/polybench/
```

### If you wish to generate plots *(done after running the sanitizers)*
```
# initial setup 
pip install pandas matplotlib

pwd
```
```
# Plot Sanitizer Overhead across Local Benchmarks
python plots/local_overhead.py

# Plot Sanitizer Runtimes across Local Benchmarks
plots/local_runtimes.py

# Plot Check Reductions across Local Benchmarks
plots/local_stat_vs_dyn_checks.py

# Plot Average Sanitizer Runtimes across PolyBench Domains
plots/polybench_avg_runtimes.py 

# Plot Average Check Reductions across PolyBench Domains
plots/polybench_stat_vs_dyn_checks.py
```
