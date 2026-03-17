#pragma once
#include "llvm/IR/PassManager.h"

namespace sanitizer {

struct RedundantCheckPass
    : public llvm::PassInfoMixin<RedundantCheckPass> {
    llvm::PreservedAnalyses run(llvm::Function &F,
                                llvm::FunctionAnalysisManager &AM);
};

}
