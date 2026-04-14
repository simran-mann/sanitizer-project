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