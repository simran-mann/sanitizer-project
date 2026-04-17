## Instructions for running the tool


First you will need to initialize the course environment if you are working on CSIL. Otherwise you will need to ensure you have LLVM{still need to check which versions will be compatible, fill in later} and CMake installed in your environment. 

```bash
source  /usr/shared/CMPT/faculty/wsumner/base/env745/bin/activate
```

Ensure you are in the project root directory: `sanitizer-project` and run the following:

```
mkdir build && cd build
cmake .. -DLLVM_DIR=$(llvm-config --cmakedir)
cd ..
./scripts/build_and_run.sh
```

The reuslts will be saved to the `results` folder:

- `results/table.txt` - summary table
- `results/<bench>_summary.txt` - breakdown for each benchmark
- `results/<bench>_baseline.ll` - instrumented IR for each benchmakr 
- `results/<bench>_opt.ll` — optimized IR for each benchmak

### If you wish to run the the Polyhedral Benchmark suite you must:
- download the benchmark suite 
```
wget https://www.cs.colostate.edu/~pouchet/software/polybench/download/polybench-3.1.tar.gz
```
- extract the compressed benchmarks
```
tar -xvf polybench-3.1.tar.gz
```
- take note of the relative path to the 'polybench-3.1' directory with respect to the project root directory
- ensure you are in the project root directory: `sanitizer-project` and run the following (several options are given below):
    - when running the script you must include the relative path to the polybench-3.1 directory as an argument
    - optional arguments:
        - clang optimization levels, acceptable input: O0, O1, O2 or O3
            - default value: O0
        - summary table file name: "polybench_summary_table.txt"
            - default value: "summary_table.txt"
```
./scripts/build_and_run_polybench.sh 'relative-path-to-polybench-3.1'
./scripts/build_and_run_polybench.sh 'relative-path-to-polybench-3.1' 02
./scripts/build_and_run_polybench.sh 'relative-path-to-polybench-3.1' 02 "polybench_summary_table.txt."
```