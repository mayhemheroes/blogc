#!/usr/bin/env bash
#
# mayhem/build.sh — build blogc's fuzz target, its standalone reproducer, and the full
# upstream test suite.
#
#   build/fuzz_source             sanitized + libFuzzer -> Mayhem target `blogc` (in-process
#                                 harness over blogc_source_parse, the same code path the
#                                 original `blogc @@` CLI target exercised per source file:
#                                 front-matter config parsing + the markdown content parser)
#   build/fuzz_source-standalone  sanitized, run-once reproducer (no libFuzzer runtime)
#   build-tests/                  upstream's ENTIRE cmake/ctest suite (cmocka unit tests +
#                                 shell functional tests, all components enabled, normal
#                                 flags) — mayhem/test.sh only RUNS it.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# Upstream derives BLOGC_VERSION from `git describe`; provide a fixed version so the build is
# deterministic and independent of tag availability in the checkout.
echo 'set(BLOGC_VERSION 0.0.0)' > version.cmake

# 1) Sanitized project build (static libs libblogc + libblogc_common are what the harness links),
#    so the FUZZED code itself is instrumented and carries DWARF-3 symbols.
cmake -B build -S . \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_C_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS" \
    -DCMAKE_BUILD_TYPE=None
cmake --build build -j"$MAYHEM_JOBS" --target libblogc libblogc_common

LIBS="build/src/blogc/liblibblogc.a build/src/common/liblibblogc_common.a"

# 2) Harness, twice: libFuzzer target + standalone run-once reproducer.
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    mayhem/fuzz_source.c $LIBS -lm -o build/fuzz_source
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS "$STANDALONE_FUZZ_MAIN" \
    mayhem/fuzz_source.c $LIBS -lm -o build/fuzz_source-standalone

# 3) Upstream test suite — a clean, independent build with the project's NORMAL flags and every
#    component enabled, exactly like upstream CI (BUILD_MANPAGES stays off: it only builds docs
#    and needs ronn-ng). mayhem/test.sh RUNS `ctest` against this tree; it never compiles.
(
    env -u CFLAGS -u LDFLAGS \
    cmake -B build-tests -S . \
        -DCMAKE_C_COMPILER="$CC" \
        -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" \
        -DBUILD_TESTING=ON \
        -DBUILD_BLOGC_MAKE=ON \
        -DBUILD_BLOGC_RUNSERVER=ON \
        -DBUILD_BLOGC_GIT_RECEIVER=ON
)
cmake --build build-tests -j"$MAYHEM_JOBS"

echo "build.sh: built build/fuzz_source (+standalone) and build-tests/ (full upstream suite)"
