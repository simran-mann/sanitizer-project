#pragma once
//these stats are shared among all passes, and since llvm could run them in paralelle if its safe, they need to be made atomic
#include <atomic>

namespace sanitizer {
extern std::atomic<int> gTotalAccesses;   //how many load/store instructions seen
extern std::atomic<int> gChecksInserted;  //how many check_access calls added
extern std::atomic<int> gChecksRemoved;   //how many redundant calls removed
}
