// check_access.c  –  runtime companion for the sanitizer pass
//
// Every instrumented load/store calls check_access(ptr) at runtime.
// This implementation:
//   1. Counts total runtime checks (to verify our static reduction).
//   2. Aborts on NULL dereference (minimal safety check).
//
// Link this file alongside any instrumented binary:
//   clang instrumented.ll check_access.c -o my_program

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

//made tghis volatile so the compiler doesnt optimize anything 
static volatile uint64_t g_check_count = 0;

void check_access(void *addr) {
    g_check_count++;

    if (addr == NULL) {
        fprintf(stderr,"check access: NULL pointer dereference detected ""(check #%llu)\n",(unsigned long long)g_check_count);
        abort();//abort if the ptr is null
    }
}

//reports how many checks ran, this is needed for the anlaysis , using stderr to keep logging seperate from normal program output
void print_check_stats(void) {
    fprintf(stderr, "[check_access] Runtime checks executed: %llu\n",(unsigned long long)g_check_count);
}

//the goal is to always call this function when the program terminates, if yuo dont want this behaviour ou can turn it off at compile time ( compile with -DCHECK_ACCESS_NO_ATEXIT)
//you need the function to be registered so it is set to be called when main is finished running
#ifndef CHECK_ACCESS_NO_ATEXIT
__attribute__((constructor))
static void register_exit_handler(void) {
    atexit(print_check_stats);
}
#endif
