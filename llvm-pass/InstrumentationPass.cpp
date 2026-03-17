#include "InstrumentationPass.h"
#include "Counters.h"

#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace sanitizer;

PreservedAnalyses sanitizer::InstrumentationPass::run(Function &F,FunctionAnalysisManager &) {
    //skip declarations and the runtime check function itself
    errs() << "debug print: visiting functoin " << F.getName() << "with # bbs=" << F.size() << "\n";
    
    if (F.isDeclaration() || F.getName() == "check_access" ||F.getName() == "print_check_stats"){
        return PreservedAnalyses::all();
    }

    Module &M   = *F.getParent();
    LLVMContext &Ctx = M.getContext();

    //declaring check access function 
    FunctionCallee CheckFn = M.getOrInsertFunction("check_access",FunctionType::get(Type::getVoidTy(Ctx),{PointerType::getUnqual(Ctx)}, false));

    SmallVector<Instruction *, 64> toInstrument;//64 instrs typically stoed on the stack before being allocated on the heap 
    for (BasicBlock &BB : F){
        for (Instruction &I : BB){
            if (isa<LoadInst>(I) || isa<StoreInst>(I)){
                toInstrument.push_back(&I);
            }
        }
    }


    for (Instruction *I : toInstrument) {
        Value *Ptr = isa<LoadInst>(I)? cast<LoadInst>(I)->getPointerOperand(): cast<StoreInst>(I)->getPointerOperand();

        IRBuilder<> Builder(I);          //insertion point is before I
        Builder.CreateCall(CheckFn, {Ptr});
    }

    int n = static_cast<int>(toInstrument.size());
    gTotalAccesses  += n;
    gChecksInserted += n;


 errs() << "Instrumenting function: " << F.getName() << ",  " << n << " checks inserted\n";
    
    return n > 0 ? PreservedAnalyses::none() : PreservedAnalyses::all();//if no isntrumentation occured, then there is no point in redonig any prior anlayses 
}
