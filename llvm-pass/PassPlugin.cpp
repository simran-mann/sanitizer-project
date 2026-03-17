#include "InstrumentationPass.h"
#include "RedundantCheckPass.h"
#include "Counters.h"

#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

// ── Define the shared counters (declared in Counters.h) ───────────────────────
namespace sanitizer {
std::atomic<int> gTotalAccesses{0};
std::atomic<int> gChecksInserted{0};
std::atomic<int> gChecksRemoved{0};
} // namespace sanitizer

using namespace sanitizer;

// //passinfomixin: uses static polumorphism to allow the base calss to access members of the derived class 
// //automatically provides standard pass info methods, like name, run, etc. 

// //EXMAPLE, using passinfomixin:

// struct MyHelloWorldPass : public PassInfoMixin<MyHelloWorldPass> {
//   PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
//     errs() << "Hello world from function: " << F.getName() << "\n";
//     return PreservedAnalyses::all();//nothing was changed
//   }
// };


struct SanitizerStatsPass : public PassInfoMixin<SanitizerStatsPass> {
    PreservedAnalyses run(Module & , ModuleAnalysisManager & ) {
        //read in the atomic vars
        int total    = gTotalAccesses.load();
        int inserted = gChecksInserted.load();
        int removed  = gChecksRemoved.load();
        int final_   = inserted - removed;

        errs() << "\n"
               << "========================================\n"
               << "           Statistics           \n"
               << "========================================\n"
               << "  Total memory accesses : " << total    << "\n"
               << "  Checks inserted       : " << inserted << "\n"
               << "  Checks removed        : " << removed  << "\n"
               << "  Final checks          : " << final_   << "\n";
        if (inserted > 0) {
            int percent_reduced = (100 * removed) / inserted;
            errs() << "  Reduction             : " << percent_reduced << "%\n";
        }

        //resetting for any subsequent runs of the same module..
        gTotalAccesses.store(0);
        gChecksInserted.store(0);
        gChecksRemoved.store(0);

        return PreservedAnalyses::all();
    }
};

//this allows opt to look for the symbol llvmGetPassPluginInfo and call it when it loads the object file
//PassPluginLibraryInfo struct stores LLVM_PLUGIN_API_VERSION(compile time directive), "SnaitzerPlugin"(name of the opt instr), "1.0"(arbitrary version string, not needed for our purposes..?), last instr is the in place function it calls
extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo llvmGetPassPluginInfo() {
    return {
        LLVM_PLUGIN_API_VERSION, "SanitizerPlugin", "1.0", //first three feilds of the struct,
        [](PassBuilder &PB) {//in place lambda function , which will call two other lambda functions 

            //when opt sees "instrument" in the pipieline string, it checks the built in passes and notices its not there, so it calls this lambda, 
            //this lambda will then call its own lambda wchih will recognize instructment and add the apss 
            PB.registerPipelineParsingCallback(
                [](StringRef name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) -> bool {
                    errs() << "DEBUG PRINT::: lambda callback called with: " << name << "\n";
                    if (name == "instrument") {
                        FPM.addPass(InstrumentationPass());
                        return true;
                    }
                    if (name == "remove-redundant") {
                        FPM.addPass(RedundantCheckPass());
                        return true;
                    }
                    return false;
                }
            );

            PB.registerPipelineParsingCallback(
                [](StringRef name, ModulePassManager &MPM,
                   ArrayRef<PassBuilder::PipelineElement>) -> bool {
                    if (name == "sanitizer-stats") {
                        MPM.addPass(SanitizerStatsPass());
                        return true;
                    }
                    return false;
                }
            );
        }
    };
}
