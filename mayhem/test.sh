#!/usr/bin/env bash
#
# mayhem/test.sh — RUN blogc's ENTIRE upstream test suite (cmocka unit tests + shell
# functional tests, all components enabled) via ctest against the build-tests/ tree that
# mayhem/build.sh compiled with the project's normal flags. The suite asserts values and
# golden outputs (cmocka assert_string_equal etc. + diff-based shell tests), so a
# neutered/exit(0) build FAILS here. Emits a CTRF summary. Never compiles.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

if [ ! -f build-tests/CTestTestfile.cmake ]; then
  echo "test.sh: build-tests/ missing — mayhem/build.sh must build the suite (not rebuilding here)" >&2
  emit_ctrf cmake-ctest 0 1
  exit 1
fi

LOG=/tmp/blogc-ctest.log
(cd build-tests && ctest --output-on-failure -j"$MAYHEM_JOBS") | tee "$LOG"

# ctest summary: "100% tests passed, 0 tests failed out of 42"
total=$(sed -n 's/.*tests failed out of \([0-9]\+\).*/\1/p' "$LOG" | tail -1)
failed=$(sed -n 's/.*, \([0-9]\+\) tests failed out of.*/\1/p' "$LOG" | tail -1)
if [ -z "${total:-}" ] || [ -z "${failed:-}" ]; then
  echo "test.sh: could not parse ctest summary" >&2
  emit_ctrf cmake-ctest 0 1
  exit 1
fi
passed=$(( total - failed ))

emit_ctrf cmake-ctest "$passed" "$failed"
