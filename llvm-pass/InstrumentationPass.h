#pragma once
#include "llvm/IR/PassManager.h"

namespace sanitizer {

struct InstrumentationPass
    : public llvm::PassInfoMixin<InstrumentationPass> {
    llvm::PreservedAnalyses run(llvm::Function &F,
                                llvm::FunctionAnalysisManager &AM);
};

} 
