#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="${1:-$PROJECT_DIR/src/test/resources/benchmark}"
REPORT_ROOT="${2:-$PROJECT_DIR/build/reports/xmlast-profile}"

mkdir -p "$REPORT_ROOT/logs" "$REPORT_ROOT/jfr" "$REPORT_ROOT/summary"
REPORT_ROOT="$(cd "$REPORT_ROOT" && pwd)"

PARALLEL_DEFAULT="${PARALLEL_DEFAULT:-4}"
JVM_HEAP="${JVM_HEAP:-6g}"
PROFILE_CASES="${PROFILE_CASES:-all}"
LINECOUNT_METRICS="${LINECOUNT_METRICS:-false}"
DECISION_PROFILING="${DECISION_PROFILING:-false}"
DECISION_PROFILE_TOP_N="${DECISION_PROFILE_TOP_N:-15}"

CSV_FILE="$REPORT_ROOT/profile-runs.csv"

run_case() {
  local case_name="$1"
  local execution_model="$2"
  local parallelism="$3"
  local compression="$4"
  local aggressive_gc="$5"

  local output_dir="$REPORT_ROOT/output/$case_name"
  local log_file="$REPORT_ROOT/logs/$case_name.log"
  local jfr_file="$REPORT_ROOT/jfr/$case_name.jfr"
  local jfr_summary="$REPORT_ROOT/summary/$case_name.jfr.summary.txt"

  mkdir -p "$REPORT_ROOT/logs" "$REPORT_ROOT/jfr" "$REPORT_ROOT/summary" "$REPORT_ROOT/output"
  rm -rf "$output_dir"
  mkdir -p "$output_dir"

  local start_ns end_ns duration_ns duration_s exit_code
  start_ns="$(python3 - <<'PY'
import time
print(time.time_ns())
PY
)"

  set +e
  (
    cd "$PROJECT_DIR"
    ./gradlew --no-daemon xml-ast-profile \
      -Pxmlast.profile.sourceDir="$SOURCE_DIR" \
      -Pxmlast.profile.outputDir="$output_dir" \
      -Pxmlast.profile.executionModel="$execution_model" \
      -Pxmlast.profile.parallelism="$parallelism" \
      -Pxmlast.profile.compression="$compression" \
      -Pxmlast.profile.enableLineCountMetrics="$LINECOUNT_METRICS" \
      -Pxmlast.profile.enableDecisionProfiling="$DECISION_PROFILING" \
      -Pxmlast.profile.decisionProfileTopN="$DECISION_PROFILE_TOP_N" \
      -Pxmlast.profile.force=true \
      -Pxmlast.profile.aggressiveGc="$aggressive_gc" \
      -Dorg.gradle.jvmargs="-Xms2g -Xmx$JVM_HEAP -XX:StartFlightRecording=filename=$jfr_file,settings=profile,dumponexit=true" \
      --stacktrace
  ) >"$log_file" 2>&1
  exit_code=$?
  set -e

  end_ns="$(python3 - <<'PY'
import time
print(time.time_ns())
PY
)"

  duration_ns=$((end_ns - start_ns))
  duration_s="$(python3 - <<PY
print(round($duration_ns / 1_000_000_000, 3))
PY
)"

  if [[ -f "$jfr_file" ]]; then
    jfr summary "$jfr_file" > "$jfr_summary" 2>&1 || true
  else
    : > "$jfr_summary"
  fi

  echo "$case_name,$execution_model,$parallelism,$compression,$aggressive_gc,$duration_s,$exit_code,$log_file,$jfr_file,$jfr_summary,$output_dir" >> "$CSV_FILE"
  echo "[profile] $case_name done: ${duration_s}s (exit=$exit_code)"
}

should_run_case() {
  local case_name="$1"
  if [[ "$PROFILE_CASES" == "all" ]]; then
    return 0
  fi
  IFS=',' read -r -a requested <<< "$PROFILE_CASES"
  for item in "${requested[@]}"; do
    if [[ "$(echo "$item" | xargs)" == "$case_name" ]]; then
      return 0
    fi
  done
  return 1
}

(
  cd "$PROJECT_DIR"
  ./gradlew --no-daemon clean > "$REPORT_ROOT/logs/pre-clean.log" 2>&1
)

mkdir -p "$REPORT_ROOT/logs" "$REPORT_ROOT/jfr" "$REPORT_ROOT/summary" "$REPORT_ROOT/output"

cat > "$CSV_FILE" <<'CSV'
case_name,execution_model,parallelism,compression,aggressive_gc,duration_seconds,exit_code,log_file,jfr_file,jfr_summary_file,output_dir
CSV

case1="seq_p1_no_compression"
case2="platform_p${PARALLEL_DEFAULT}_no_compression"
case3="virtual_p${PARALLEL_DEFAULT}_no_compression"
case4="virtual_p${PARALLEL_DEFAULT}_compression"
case5="virtual_p${PARALLEL_DEFAULT}_compression_gc"

should_run_case "$case1" && run_case "$case1" "SEQUENTIAL" "1" "false" "false"
should_run_case "$case2" && run_case "$case2" "PLATFORM_THREADS" "$PARALLEL_DEFAULT" "false" "false"
should_run_case "$case3" && run_case "$case3" "VIRTUAL_THREADS" "$PARALLEL_DEFAULT" "false" "false"
should_run_case "$case4" && run_case "$case4" "VIRTUAL_THREADS" "$PARALLEL_DEFAULT" "true" "false"
should_run_case "$case5" && run_case "$case5" "VIRTUAL_THREADS" "$PARALLEL_DEFAULT" "true" "true"

python3 "$SCRIPT_DIR/render_profile_report.py" "$CSV_FILE" "$REPORT_ROOT" "$SOURCE_DIR"

echo "[profile] report: $REPORT_ROOT/report.md"

