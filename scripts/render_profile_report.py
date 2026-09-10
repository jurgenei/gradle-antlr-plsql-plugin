#!/usr/bin/env python3
from __future__ import annotations

import csv
import math
import re
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List

SUCCESS_RE = re.compile(r"\[SUCCESS\]\s+(?P<path>.+?)\s+(?P<sec>\d+)s\s+(?P<lines>\d+):(?P<bytes>\d+)\s+parsed")
FAILURE_RE = re.compile(r"\[FAILURE\]\s+(?P<message>.+)")
PROFILE_DECISION_RE = re.compile(
    r"\[PROFILE\]\s+decision=(?P<decision>\d+)\s+rule=(?P<rule>\S+)\s+"
    r"timeMs=(?P<time_ms>[0-9]+(?:\.[0-9]+)?)\s+invocations=(?P<invocations>\d+)\s+"
    r"SLL=(?P<sll>\d+)\s+LL=(?P<ll>\d+)\s+ambiguities=(?P<ambiguities>\d+)\s+"
    r"contextSensitivities=(?P<context>\d+)\s+predicateEvals=(?P<predicates>\d+)"
)


@dataclass
class FilePerf:
    path: str
    seconds: int
    lines: int
    bytes_: int


@dataclass
class DecisionPerf:
    decision: int
    rule: str
    time_ms: float
    invocations: int
    sll_total_look: int
    ll_total_look: int
    ambiguities: int
    context_sensitivities: int
    predicate_evals: int


@dataclass
class RunMetrics:
    case_name: str
    execution_model: str
    parallelism: int
    compression: bool
    aggressive_gc: bool
    duration_seconds: float
    exit_code: int
    log_file: Path
    jfr_file: Path
    files: List[FilePerf]
    failures: List[str]
    decisions: List[DecisionPerf]

    @property
    def parsed_files(self) -> int:
        return len(self.files)

    @property
    def total_lines(self) -> int:
        return sum(f.lines for f in self.files)

    @property
    def total_bytes(self) -> int:
        return sum(f.bytes_ for f in self.files)

    @property
    def files_per_second(self) -> float:
        if self.duration_seconds <= 0:
            return 0.0
        return self.parsed_files / self.duration_seconds

    @property
    def lines_per_second(self) -> float:
        if self.duration_seconds <= 0:
            return 0.0
        return self.total_lines / self.duration_seconds



def read_run_metrics(csv_path: Path) -> List[RunMetrics]:
    runs: List[RunMetrics] = []
    with csv_path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            log_file = Path(row["log_file"])
            files, failures, decisions = parse_log(log_file)
            runs.append(
                RunMetrics(
                    case_name=row["case_name"],
                    execution_model=row["execution_model"],
                    parallelism=int(row["parallelism"]),
                    compression=row["compression"].lower() == "true",
                    aggressive_gc=row["aggressive_gc"].lower() == "true",
                    duration_seconds=float(row["duration_seconds"]),
                    exit_code=int(row["exit_code"]),
                    log_file=log_file,
                    jfr_file=Path(row["jfr_file"]),
                    files=files,
                    failures=failures,
                    decisions=decisions,
                )
            )
    return runs



def parse_log(log_path: Path) -> tuple[List[FilePerf], List[str], List[DecisionPerf]]:
    files: List[FilePerf] = []
    failures: List[str] = []
    decisions: List[DecisionPerf] = []
    if not log_path.exists():
        return files, failures, decisions

    for line in log_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = SUCCESS_RE.search(line)
        if m:
            files.append(
                FilePerf(
                    path=m.group("path"),
                    seconds=int(m.group("sec")),
                    lines=int(m.group("lines")),
                    bytes_=int(m.group("bytes")),
                )
            )
            continue
        f = FAILURE_RE.search(line)
        if f:
            failures.append(f.group("message"))
            continue
        d = PROFILE_DECISION_RE.search(line)
        if d:
            decisions.append(
                DecisionPerf(
                    decision=int(d.group("decision")),
                    rule=d.group("rule"),
                    time_ms=float(d.group("time_ms")),
                    invocations=int(d.group("invocations")),
                    sll_total_look=int(d.group("sll")),
                    ll_total_look=int(d.group("ll")),
                    ambiguities=int(d.group("ambiguities")),
                    context_sensitivities=int(d.group("context")),
                    predicate_evals=int(d.group("predicates")),
                )
            )
    return files, failures, decisions



def percentile(values: List[float], p: float) -> float:
    if not values:
        return 0.0
    if len(values) == 1:
        return values[0]
    ordered = sorted(values)
    rank = (len(ordered) - 1) * p
    low = math.floor(rank)
    high = math.ceil(rank)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (rank - low)



def top_slowest(files: List[FilePerf], n: int = 10) -> List[FilePerf]:
    return sorted(files, key=lambda f: (f.seconds, f.lines, f.bytes_), reverse=True)[:n]


def top_decisions(decisions: List[DecisionPerf], n: int = 10) -> List[DecisionPerf]:
    return sorted(decisions, key=lambda d: (d.time_ms, d.invocations), reverse=True)[:n]



def estimate_backtracking_risk(files: List[FilePerf]) -> List[str]:
    insights: List[str] = []
    if not files:
        return insights

    by_line_density = []
    for f in files:
        if f.lines > 0:
            by_line_density.append((f.seconds / f.lines, f))

    if by_line_density:
        high = sorted(by_line_density, key=lambda t: t[0], reverse=True)[:5]
        insights.append("Slow-per-line candidates (possible grammar ambiguity/backtracking hotspots):")
        for ratio, f in high:
            insights.append(
                f"- `{f.path}`: {f.seconds}s for {f.lines} lines ({ratio:.4f} s/line)"
            )

    durations = [f.seconds for f in files]
    p95 = percentile(durations, 0.95)
    med = statistics.median(durations)
    if med > 0 and p95 >= med * 3:
        insights.append(
            f"Heavy tail detected: p95 {p95:.2f}s vs median {med:.2f}s. Few files dominate runtime."
        )
    return insights



def recommend_optimizations(runs: List[RunMetrics]) -> List[str]:
    recs: List[str] = []
    successful = [r for r in runs if r.exit_code == 0 and r.parsed_files > 0]
    if not successful:
        return ["- No successful runs. Fix runtime failures first."]

    fastest = min(successful, key=lambda r: r.duration_seconds)
    recs.append(
        f"- Baseline fastest mode now: `{fastest.case_name}` ({fastest.duration_seconds:.2f}s)."
    )

    seq = next((r for r in successful if r.execution_model == "SEQUENTIAL"), None)
    if seq:
        speedup = seq.duration_seconds / fastest.duration_seconds if fastest.duration_seconds > 0 else 1.0
        recs.append(f"- Parallel speedup vs sequential: {speedup:.2f}x.")

    has_compression = [r for r in successful if r.compression]
    no_compression = [r for r in successful if not r.compression]
    if has_compression and no_compression:
        best_c = min(has_compression, key=lambda r: r.duration_seconds)
        best_n = min(no_compression, key=lambda r: r.duration_seconds)
        delta = (best_c.duration_seconds - best_n.duration_seconds) / best_n.duration_seconds * 100.0
        if delta > 5:
            recs.append("- Disable `compression` for first-pass parsing throughput. Run compression in post-step only if needed.")
        else:
            recs.append("- Compression cost small on this dataset. Keep enabled if downstream size reduction valuable.")

    recs.extend([
        "- Focus optimization in `DynamicAntlrXmlAstConverter.parseToXml` and parse-tree traversal paths; they dominate per-file cost.",
        "- Remove per-file second pass over source (`countLines`) or gate behind debug flag to cut I/O overhead.",
        "- Cache reflection artifacts (`lexerCtor`, `parserCtor`, `entryPoint`) per binding, avoid repeated lookup per file.",
        "- For grammar-level backtracking hotspots, inspect top slow files and run ANTLR decision profiling on those files first.",
    ])

    runs_with_decisions = [r for r in successful if r.decisions]
    if runs_with_decisions:
        best_with_decisions = min(runs_with_decisions, key=lambda r: r.duration_seconds)
        top = top_decisions(best_with_decisions.decisions, n=1)
        if top:
            hottest = top[0]
            recs.append(
                f"- Highest parser decision hotspot observed: decision {hottest.decision} (rule `{hottest.rule}`) at {hottest.time_ms:.3f}ms; prioritize grammar refactor there."
            )
    else:
        recs.append("- Decision profiler not enabled in these runs. Enable `enableDecisionProfiling=true` to rank grammar hotspots directly.")
    return recs



def write_report(report_file: Path, source_dir: Path, runs: List[RunMetrics]) -> None:
    lines: List[str] = []
    lines.append("# XML AST Profiling Report")
    lines.append("")
    lines.append(f"- Source dataset: `{source_dir}`")
    lines.append(f"- Runs: {len(runs)}")
    lines.append("")

    lines.append("## Run Matrix")
    lines.append("")
    lines.append("| case | model | p | compression | aggressiveGc | wall(s) | parsed files | files/s | lines/s | failures |")
    lines.append("|---|---|---:|---|---|---:|---:|---:|---:|---:|")
    for r in runs:
        lines.append(
            "| {case} | {model} | {p} | {comp} | {gc} | {wall:.3f} | {files} | {fps:.3f} | {lps:.1f} | {fails} |".format(
                case=r.case_name,
                model=r.execution_model,
                p=r.parallelism,
                comp=str(r.compression).lower(),
                gc=str(r.aggressive_gc).lower(),
                wall=r.duration_seconds,
                files=r.parsed_files,
                fps=r.files_per_second,
                lps=r.lines_per_second,
                fails=len(r.failures),
            )
        )

    lines.append("")
    lines.append("## Slowest Files (Fastest Successful Run)")
    lines.append("")
    successful = [r for r in runs if r.exit_code == 0 and r.parsed_files > 0]
    if successful:
        fastest = min(successful, key=lambda r: r.duration_seconds)
        lines.append(f"- Fastest run: `{fastest.case_name}`")
        lines.append("")
        lines.append("| file | seconds | lines | bytes | sec/line |")
        lines.append("|---|---:|---:|---:|---:|")
        for f in top_slowest(fastest.files):
            sec_per_line = (f.seconds / f.lines) if f.lines else 0.0
            lines.append(f"| `{f.path}` | {f.seconds} | {f.lines} | {f.bytes_} | {sec_per_line:.4f} |")

        lines.append("")
        lines.append("## Backtracking Risk Signals")
        lines.append("")
        for insight in estimate_backtracking_risk(fastest.files):
            lines.append(insight)

        lines.append("")
        lines.append("## Grammar Decision Hotspots")
        lines.append("")
        if fastest.decisions:
            lines.append("| decision | rule | timeMs | invocations | SLL | LL | ambiguities | contextSensitivities | predicateEvals |")
            lines.append("|---:|---|---:|---:|---:|---:|---:|---:|---:|")
            for d in top_decisions(fastest.decisions, n=15):
                lines.append(
                    f"| {d.decision} | `{d.rule}` | {d.time_ms:.3f} | {d.invocations} | {d.sll_total_look} | {d.ll_total_look} | {d.ambiguities} | {d.context_sensitivities} | {d.predicate_evals} |"
                )
        else:
            lines.append("- No `[PROFILE]` decision lines detected for fastest run. Set `DECISION_PROFILING=true`." )
    else:
        lines.append("- No successful runs.")

    lines.append("")
    lines.append("## Optimization Priorities")
    lines.append("")
    for rec in recommend_optimizations(runs):
        lines.append(rec)

    lines.append("")
    lines.append("## Artifacts")
    lines.append("")
    for r in runs:
        lines.append(f"- `{r.case_name}` log: `{r.log_file}`")
        lines.append(f"- `{r.case_name}` JFR: `{r.jfr_file}`")

    report_file.write_text("\n".join(lines) + "\n", encoding="utf-8")



def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: render_profile_report.py <profile-runs.csv> <report-root> <source-dir>")
        return 2

    csv_file = Path(sys.argv[1])
    report_root = Path(sys.argv[2])
    source_dir = Path(sys.argv[3])
    report_root.mkdir(parents=True, exist_ok=True)

    runs = read_run_metrics(csv_file)
    report_file = report_root / "report.md"
    write_report(report_file, source_dir, runs)
    print(f"[profile] wrote report: {report_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

