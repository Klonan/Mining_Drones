#!/usr/bin/env bash
# Runs the Mining Drones self test scenario headlessly and reports the result.
#
#   scripts/run-self-test.sh [path/to/factorio.exe]
#
# The scenario is first converted into a map, which runs on_init and then saves, so the whole test
# also exercises a save/load round trip of the mod's storage. The map is then benchmarked, which
# runs the game headless for a fixed number of ticks and exits on its own.

set -u

FACTORIO="${1:-c:/Factorio/bin/fetched/factorio.exe}"
SCENARIO="Mining_Drones/mining-drones-self-test"
TICKS="${TICKS:-45000}"

if [ ! -x "$FACTORIO" ]; then
  echo "Factorio executable not found: $FACTORIO" >&2
  echo "Usage: $0 [path/to/factorio]" >&2
  exit 2
fi

FACTORIO_DIR="$(cd "$(dirname "$FACTORIO")/../.." && pwd)"
SAVE="$FACTORIO_DIR/saves/Mining_Drones/mining-drones-self-test.zip"

echo "== building test map from scenario =="
if ! "$FACTORIO" --scenario2map "$SCENARIO" --disable-audio > /tmp/md-self-test-build.log 2>&1; then
  echo "scenario2map failed:" >&2
  tail -40 /tmp/md-self-test-build.log >&2
  exit 1
fi
grep -E "^ *[0-9.]+ (Error|Warning)" /tmp/md-self-test-build.log

echo "== running $TICKS ticks =="
"$FACTORIO" --benchmark "$SAVE" --benchmark-ticks "$TICKS" --disable-audio 2>&1 | tee /tmp/md-self-test-run.log \
  | grep -E "SELFTEST|Error|error while running|stack traceback" \
  | sed -E 's/^.*SELFTEST \| //'

echo
if grep -q "SELFTEST | RESULT PASS" /tmp/md-self-test-run.log; then
  echo "SELF TEST PASSED"
  exit 0
fi

if grep -q "SELFTEST | RESULT FAIL" /tmp/md-self-test-run.log; then
  echo "SELF TEST FAILED - see the FAIL lines above"
  exit 1
fi

echo "SELF TEST DID NOT FINISH - the run either crashed or needs more than $TICKS ticks"
echo "full log: /tmp/md-self-test-run.log"
exit 1
