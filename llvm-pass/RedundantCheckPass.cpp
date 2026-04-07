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


//checks if any instruction between A and B (exclusive) could have invaldated  the pointer being check
//we could either strilcyt look for free or realloc calls, but this does not cover the case where you call a random function which thne frees the memory 
//if this function returns true-> dont remove the second access
static bool isInvalidatedBetween(Instruction *A, Instruction *B,Value *Ptr, DominatorTree &DT) {
    //go through each instruction, in order and for evry basic block btwn the two instructions, check if any instruction may invalidate the pointer, and if so the second check is needed 

    Function *F = A->getFunction();
    
    for (BasicBlock &BB : *F) {
        for (Instruction &I : BB) {
            if (&I == A || &I == B) continue;
            if (!DT.dominates(A, &I)) continue;  //instructions after A
            if (!DT.dominates(&I, B)) continue;  //instructions before B 


            if (auto *CI = dyn_cast<CallInst>(&I)) {
                //need to consider the case where tje function call is the custom inserted function, or esle there is a  bug where you will never remove hte secnod check
                if (Function *Fn = CI->getCalledFunction()){
                    if (Fn->getName() == "check_access"){
                        continue;
                    }
                }

                //if it passes the ptr as an argument, then assume it modifies the memory and so the second check is actually needed 

                /**
                 * a[i] = 4;
                 * check_access(a[i]);
                 * free(unrelated_ptr);
                 * check_access(a[i]);
                 * x=a[i];
                 * 
                 * with this example, if youre checking for just free or realloc calls,
                 *  it would not remove the second check, but the ptr that is being checked was never changed 
                 */
                for (auto &Arg : CI->args()){
                    if (Arg.get() == Ptr){//this way is better than explicilty checking if the function name was 'free' or 'realloc', because you could have a snippet like the one above
                         return true;
                    }
                }

            }
        }
    }
    return false;
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
            if (pA == pB && DT.dominates(checks[i], checks[j]) && !isInvalidatedBetween(checks[i], checks[j], pA, DT)){
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
