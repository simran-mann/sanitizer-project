#include "RedundantCheckPass.h"
#include "Counters.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Analysis/DominanceFrontierImpl.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace sanitizer;

static bool isCheckCall(const Instruction *I) {
    if (const auto *CI = dyn_cast<CallInst>(I)){
        if (const Function *Fn = CI->getCalledFunction()){
            return Fn->getName() == "check_access";
        }
    }
    return false;
}

//returns the pointer argment of a check_access call or null if na 
static Value *checkedPointer(const CallInst *CI) {
    return CI->arg_size() > 0 ? CI->getArgOperand(0) : nullptr;
}



PreservedAnalyses sanitizer::RedundantCheckPass::run(Function &F,FunctionAnalysisManager &AM) {
    // dominator treeto get the depeendency graphs of each check call
    auto &DT = AM.getResult<DominatorTreeAnalysis>(F);

    // collect all check calls in program order
    SmallVector<CallInst *, 64> checks;
    for (BasicBlock &BB : F){
        for (Instruction &I : BB){
            if (isCheckCall(&I)){
                checks.push_back(cast<CallInst>(&I));
            }
        }
    }
//only check if there are more than 1 load/store instrs, or else there is no redudnadncy if theres just one check 
    if (checks.size() < 2){
        return PreservedAnalyses::all();  
    }

    //find redundant calls 
    SmallPtrSet<Instruction *, 32> toRemove;

    for (size_t i = 0; i < checks.size(); i++) {
        Value *pA = checkedPointer(checks[i]);
        if (!pA){ 
            continue;
        }

        for (size_t j = i + 1; j < checks.size(); j++) {
            //if it is alreayd set to be removed, skip
            if (toRemove.count(checks[j])){ 
                continue;
            }
            Value *pB = checkedPointer(checks[j]);
            if (!pB){
                continue;
            }

            //if they have the same SSA value AND A dominates B , then B is redundant.
            //NOTE: currently this will not work if there was a free or realloc between the two calls, because the SSA form will be the same, but the memory is invalid
            if (pA == pB && DT.dominates(checks[i], checks[j])){
                toRemove.insert(checks[j]);
            }
        }
    }

    //remove the redundant calls 
    int removed = 0;
    for (Instruction *I : toRemove) {
        I->eraseFromParent();
        removed++;
    }

    gChecksRemoved += removed;


    errs() << "Removing rudundant calls in function " << F.getName()<< ", removed " << removed << checks.size() << " check(s)\n";

    return removed > 0 ? PreservedAnalyses::none() : PreservedAnalyses::all();
}
