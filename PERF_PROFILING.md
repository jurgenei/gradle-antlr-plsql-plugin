# XML AST Benchmark and Profiling

This module now provides reproducible benchmark + profiling flow for PL/SQL XML AST conversion.

## What It Runs

Script `scripts/profile-xmlast.sh` runs matrix:

- `SEQUENTIAL` / `parallelism=1`
- `PLATFORM_THREADS` / `parallelism=$PARALLEL_DEFAULT`
- `VIRTUAL_THREADS` / `parallelism=$PARALLEL_DEFAULT`
- `VIRTUAL_THREADS` with `compression=true`
- `VIRTUAL_THREADS` with `compression=true` and `aggressiveGc=true`

Each run collects:

- wall-clock duration
- Gradle task logs
- JFR recording (`.jfr`)
- JFR summary text
- generated XML output directory

Then it generates report:

- `build/reports/xmlast-profile/report.md`
- `build/reports/xmlast-profile/profile-runs.csv`

## Profiling Task

Task: `xml-ast-profile`

Configurable with `-P` properties:

- `xmlast.profile.sourceDir`
- `xmlast.profile.outputDir`
- `xmlast.profile.executionModel` (`SEQUENTIAL|PLATFORM_THREADS|VIRTUAL_THREADS`)
- `xmlast.profile.parallelism`
- `xmlast.profile.compression`
- `xmlast.profile.force`
- `xmlast.profile.aggressiveGc`
- `xmlast.profile.enableDFAMonitoring`
- `xmlast.profile.enableLineCountMetrics`
- `xmlast.profile.enableDecisionProfiling`
- `xmlast.profile.decisionProfileTopN`
- `xmlast.profile.gcEveryFiles`
- `xmlast.profile.gcHeapThresholdPercent`

Default profiling mode sets `enableLineCountMetrics=false` to avoid extra post-parse file reread.

## Quick Start

```bash
cd /Users/cs79en/Developer/GitHub/gradle/gradle-antlr-plsql-plugin
chmod +x scripts/profile-xmlast.sh scripts/render_profile_report.py
./scripts/profile-xmlast.sh
```

Custom source dataset and report output:

```bash
cd /Users/cs79en/Developer/GitHub/gradle/gradle-antlr-plsql-plugin
PARALLEL_DEFAULT=8 JVM_HEAP=10g ./scripts/profile-xmlast.sh \
  /absolute/path/to/plsql/repository \
  /absolute/path/to/profile-output
```

Compare line-count metrics overhead on same case:

```bash
LINECOUNT_METRICS=false PROFILE_CASES=platform_p8_no_compression PARALLEL_DEFAULT=8 ./scripts/profile-xmlast.sh
LINECOUNT_METRICS=true PROFILE_CASES=platform_p8_no_compression PARALLEL_DEFAULT=8 ./scripts/profile-xmlast.sh
```

Enable grammar decision hotspot ranking in report:

```bash
DECISION_PROFILING=true DECISION_PROFILE_TOP_N=20 PROFILE_CASES=platform_p8_no_compression PARALLEL_DEFAULT=8 ./scripts/profile-xmlast.sh
```

## JFR Deep Dive

Show high-level JFR summary:

```bash
jfr summary /absolute/path/to/run.jfr
```

Print execution samples:

```bash
jfr print --events jdk.ExecutionSample /absolute/path/to/run.jfr
```

## Notes

- For very large corpora, run with `--no-daemon` (already used by script) for cleaner per-run JVM isolation.
- Use same source snapshot across runs for fair comparison.
- Keep `force=true` in profiling runs to avoid up-to-date skips.
