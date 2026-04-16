CC ?= clang
SR_CC ?= SanRazor-clang
CFLAGS ?= -O2
LDFLAGS ?= -lm


BUILD_DIR := sanrazor-results/build
RESULTS_DIR := sanrazor-results/results
STATE_DIR ?= /home/project/sanrazor_state

BENCHMARKS := matrix_mult array_sum quicksort binary_search convolution knapsack

BASE_TARGETS := $(addprefix $(BUILD_DIR)/,$(addsuffix _base,$(BENCHMARKS)))
SR_PROFILE_TARGETS := $(addprefix $(BUILD_DIR)/,$(addsuffix _sr_profile,$(BENCHMARKS)))
SR_FINAL_TARGETS := $(addprefix $(BUILD_DIR)/,$(addsuffix _sr,$(BENCHMARKS)))

# SanRazor stores bitcode intermediates here
SR_BC_TARGETS := $(addprefix $(STATE_DIR)/objects/,$(addsuffix .orig.bc,$(BENCHMARKS)))
.SECONDARY: $(SR_BC_TARGETS)

all: baseline

baseline: $(BASE_TARGETS)

# First SanRazor build used for profiling
sanrazor-profile-build: sr-init $(SR_PROFILE_TARGETS)

# Second SanRazor build after -SR-opt
sanrazor-final-build: $(SR_FINAL_TARGETS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)

$(STATE_DIR):
	mkdir -p $(STATE_DIR)

# ---------- Baseline ----------
$(BUILD_DIR)/%_base: benchmarks/%.c | $(BUILD_DIR)
	clang $(CFLAGS) $< -o $@ $(LDFLAGS)

# ---------- SanRazor setup ----------
sr-init: | $(STATE_DIR)
	@if [ -z "$$SR_WORK_PATH" ]; then \
		echo "ERROR: SR_WORK_PATH is not set"; \
		exit 1; \
	fi
	SR_STATE_PATH="$(STATE_DIR)" SR_WORK_PATH="$$SR_WORK_PATH" $(SR_CC) -SR-init

sr-opt:
	SR_STATE_PATH="$(STATE_DIR)" SR_WORK_PATH="$$SR_WORK_PATH" $(SR_CC) -SR-opt -san-level=L2 -use-asap=1.0

# Compile benchmark source through SanRazor into state-dir bitcode.
# We call -c inside benchmarks/ so the produced name is stable: %.orig.bc
$(STATE_DIR)/objects/%.orig.bc: benchmarks/%.c | $(STATE_DIR)
	cd benchmarks && \
	SR_STATE_PATH="$(STATE_DIR)" SR_WORK_PATH="$$SR_WORK_PATH" $(SR_CC) $(CFLAGS) -c $*.c
	@test -f "$@" || (echo "ERROR: expected $@ was not created" && exit 1)

# ---------- First build: profile binaries ----------
$(STATE_DIR)/objects/%.orig.bc: benchmarks/%.c | $(STATE_DIR)
	cd benchmarks && \
	SR_STATE_PATH="$(STATE_DIR)" SR_WORK_PATH="$$SR_WORK_PATH" $(SR_CC) $(CFLAGS) -c $*.c
	@test -f "$@" || (echo "ERROR: expected $@ was not created" && exit 1)

$(BUILD_DIR)/%_sr_profile: $(STATE_DIR)/objects/%.orig.bc | $(BUILD_DIR)
	clang $(CFLAGS) $< -o $@ $(LDFLAGS)


# ---------- Second build: final binaries ----------
$(BUILD_DIR)/%_sr: $(STATE_DIR)/objects/%.orig.bc | $(BUILD_DIR)
	clang $(CFLAGS) $< -o $@ $(LDFLAGS)

# Clean build outputs but keep SanRazor state for the profile->opt->rebuild flow
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(RESULTS_DIR)

# Remove everything, including SanRazor state
distclean:
	rm -rf $(BUILD_DIR)
	rm -rf $(RESULTS_DIR)
	rm -rf $(STATE_DIR)

.PHONY: all baseline sanrazor-profile-build sanrazor-final-build sr-init sr-opt clean distclean