#!/usr/bin/env python3
"""scripts/carried_suites.py -- the `suites` check of .heimdall/repo-checks.json: every suite and fixture that came with the history, each run once and recorded as pass, skip or fail.

    python3 scripts/carried_suites.py [text]       every suite, or only those whose path contains the text

What runs: test/*.test.sh and conformance/statusline/*.fixture.sh. Each finds its files from its own location (the parent of test/, or of conformance/), so it runs in place, in this
repository, with python3 and system tools only: no heimdall file beside the renderer, which is what a clone of this repository gives it.

The suites that name a heimdall file (HOST_NEEDS below, HOST-CONTRACT.md section 8) run in a host view when a host is found: a scratch tree holding a COPY of heimdall's bin, hooks,
sentinels and settings.json with this repository laid over it, so heimdall's own scripts sit beside this repository's renderer at the same relative paths (HOST-CONTRACT.md section 1)
and neither real tree is written. The host is HMD_HOST_DIR when set (it must hold an executable bin/heimdall, else exit 2), else a heimdall checkout next to this repository
(../heimdall). With none, those suites are SKIPPED, each with the file it needs.

  HMD_REQUIRE_HOST=1      every skip is a failure (no host, a missing tool, a fixture that skipped its host half): set it in CI, a skipped suite must not read as a passing one
  HMD_NO_HOST=1           ignore any host, the way a lone clone does: what a machine with no heimdall sees
  HMD_SUITE_TIMEOUT_S=N   the wall-clock cap of one suite, default 900; a suite over it is killed and fails
  HMD_TEST_NO_PY_PIN=1    leave python3 on PATH as it is (default: pinned to the real interpreter, as heimdall's own sweep does, so a pyenv shim does not charge every render its start-up)

A suite runs with a new HOME and TMPDIR, none of the caller's HEIMDALL_ / HMD_ / CLAUDE_PLUGIN_ variables, and stdin closed; its process group is killed when it ends.
Results: one line per suite as it ends, the totals last, and the same record as JSON in .heimdall/receipts/carried-suites.json (ignored build output).
Exit 0: no suite failed. 1: a suite failed or timed out, or was skipped under HMD_REQUIRE_HOST=1. 2: bad setup.
Python 3.8+, standard library only.
"""
import contextlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RECEIPT = REPO / ".heimdall" / "receipts" / "carried-suites.json"
GLOBS = ("test/*.test.sh", "conformance/statusline/*.fixture.sh")
SCRUBBED_PREFIXES = ("HEIMDALL_", "HMD_", "CLAUDE_PLUGIN_")
VIEW_FROM_HOST = ("bin", "hooks", "sentinels", "settings.json")
VIEW_FROM_REPO = ("bin", "hooks", "sentinels", "conformance", "test")
TAIL_LINES = 30

# suite -> the heimdall files it runs or reads that this repository does not carry (HOST-CONTRACT.md section 8). A path under bin/ must be executable there.
HOST_NEEDS = {
    "test/heimdall-sigil-heroes.test.sh": ["bin/heimdall"],
    "test/heimdall-sigil-render.test.sh": ["bin/heimdall"],
    "test/heimdall-statusline-agent-tiers.test.sh": ["bin/heimdall-tier"],
    "test/heimdall-statusline-agents-cache.test.sh": ["bin/heimdall-agents"],
    "test/heimdall-statusline-cursor-payload.test.sh": ["bin/heimdall-ctx-meter"],
    "test/heimdall-statusline-parity.test.sh": ["bin/heimdall-ctx-meter"],
    "test/heimdall-statusline-portability.test.sh": ["hooks/hooks.json"],
    "conformance/statusline/prefix-and-elements.fixture.sh": ["settings.json"],
    "conformance/statusline/viral-gate-anim.fixture.sh": ["sentinels/hmd-gate-anim.sh"],
}
# suites that run without a host but check more with one: they get the host view when there is a host, and a fixture that skipped its host half says so (a partial pass)
HOST_OPTIONAL = {
    "conformance/statusline/viral-statusline.fixture.sh": ["bin/heimdall-identity", "bin/heimdall-presence"],
}
TOOL_NEEDS = {
    "test/heimdall-statusline-portability.test.sh": ["jq"],
    "conformance/statusline/prefix-and-elements.fixture.sh": ["jq"],
}

COUNTS = re.compile(r"(\d+) passed, (\d+) failed")
SKIP_LINE = re.compile(r"^\s*SKIP(?:PED)?\b.*$", re.M)
PARTIAL_LINE = re.compile(r"^NOTE .*skipping.*$", re.M)


def die(code, message):
    print("carried-suites: %s" % message, file=sys.stderr)
    sys.exit(code)


def timeout_seconds():
    raw = os.environ.get("HMD_SUITE_TIMEOUT_S", "900")
    if not raw.isdigit() or int(raw) < 1:
        die(2, "HMD_SUITE_TIMEOUT_S=%r is not a positive whole number of seconds" % raw)
    return int(raw)


def discover():
    found = sorted(str(p.relative_to(REPO)) for pattern in GLOBS for p in REPO.glob(pattern))
    stale = sorted((set(HOST_NEEDS) | set(HOST_OPTIONAL) | set(TOOL_NEEDS)) - set(found))
    if stale:
        die(2, "the tables in scripts/carried_suites.py name suites that are not here: %s" % ", ".join(stale))
    return found


def find_host():
    """(heimdall checkout or None, how it was found). A HMD_HOST_DIR that is not a heimdall checkout is a bad setup, never a quiet fall back to something else."""
    if os.environ.get("HMD_NO_HOST") == "1":
        return None, "HMD_NO_HOST=1"
    given = os.environ.get("HMD_HOST_DIR", "")
    if given:
        if not os.access(os.path.join(given, "bin", "heimdall"), os.X_OK):
            die(2, "HMD_HOST_DIR=%s is not a heimdall checkout (no executable bin/heimdall)" % given)
        return Path(given).resolve(), "HMD_HOST_DIR"
    sibling = REPO.parent / "heimdall"
    if os.access(sibling / "bin" / "heimdall", os.X_OK):
        return sibling.resolve(), "../heimdall"
    return None, "no heimdall checkout in HMD_HOST_DIR or at ../heimdall"


def host_has(host, rel):
    path = host / rel
    return os.access(path, os.X_OK) if rel.startswith("bin/") else path.exists()


def build_host_view(host, scratch):
    """A copy of the host files the suites reach with this repository over them. Copies, never links: a heimdall script finds its root from its own real path, so a link would send it back
    into heimdall, and a write through a link would land there."""
    view = scratch / "host-view"
    view.mkdir()
    skip_bytecode = shutil.ignore_patterns("__pycache__", "*.pyc")
    for name in VIEW_FROM_HOST:
        src = host / name
        if src.is_dir():
            shutil.copytree(src, view / name, symlinks=True, ignore=skip_bytecode)
        elif src.is_file():
            shutil.copy2(src, view / name)
    for name in VIEW_FROM_REPO:
        for src in sorted((REPO / name).rglob("*")):
            if not src.is_file() or "__pycache__" in src.parts or src.suffix == ".pyc":
                continue
            dst = view / src.relative_to(REPO)
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.is_symlink() or dst.exists():
                dst.unlink()
            shutil.copy2(src, dst)
    return view


def pinned_path(scratch):
    """(PATH for the suites, one line saying what was done). python3 is pinned to the real interpreter when it resolves to a shim, as heimdall's test/lib/py-pin.sh does: with a pyenv
    shim every python3 call pays a bash and version lookup first, and the perf-budget suite measures renders against a CPU budget."""
    path = os.environ.get("PATH", "")
    if os.environ.get("HMD_TEST_NO_PY_PIN") == "1":
        return path, "python3 pin off (HMD_TEST_NO_PY_PIN=1)"
    current = shutil.which("python3")
    real = sys.executable
    if not current or not real:
        return path, "python3 pin off (no interpreter to pin)"
    if os.path.samefile(current, real):
        return path, "python3 is already the interpreter (%s)" % real
    pin = scratch / "pin"
    pin.mkdir()
    wrapper = pin / "python3"
    wrapper.write_text('#!/bin/sh\nexec %s "$@"\n' % shlex.quote(real))
    wrapper.chmod(0o755)
    return "%s%s%s" % (pin, os.pathsep, path), "python3 pinned to %s (it resolved to %s)" % (real, current)


def suite_env(path, run_dir):
    env = {k: v for k, v in os.environ.items() if not k.startswith(SCRUBBED_PREFIXES)}
    home, tmp = run_dir / "home", run_dir / "tmp"
    home.mkdir(parents=True)
    tmp.mkdir()
    env.update(HOME=str(home), TMPDIR=str(tmp), PATH=path)
    return env


def kill_group(proc):
    with contextlib.suppress(ProcessLookupError, PermissionError):
        os.killpg(proc.pid, signal.SIGKILL)


def run_suite(root, rel, env, log, limit):
    """(exit code, or None when it timed out; seconds). The suite leads its own process group, killed when it ends: a sleeper it left behind must not outlive the gate."""
    started = time.monotonic()
    with open(log, "wb") as out:
        proc = subprocess.Popen(["bash", str(root / rel)], cwd=str(root), stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, env=env, start_new_session=True)
        try:
            code = proc.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            code = None
        finally:
            kill_group(proc)
        if code is None:
            proc.wait()
    return code, time.monotonic() - started


def count(rel, text):
    if rel.endswith(".fixture.sh"):
        return len(re.findall(r"^OK ", text, re.M)), len(re.findall(r"^BAD ", text, re.M))
    found = COUNTS.findall(text)
    if not found:
        return None, None
    return int(found[-1][0]), int(found[-1][1])


def judge(rel, code, text):
    """(result, passed, failed, detail) of one finished run."""
    passed, failed = count(rel, text)
    if code is None:
        return "fail", passed, failed, "timed out"
    if code != 0:
        return "fail", passed, failed, "exit %d" % code
    if failed:
        return "fail", passed, failed, "%d failed though it exited 0" % failed
    skipped = SKIP_LINE.search(text)
    if skipped and not passed:
        return "skip", passed, failed, skipped.group(0).strip()
    if passed == 0 and failed == 0:
        return "fail", passed, failed, "it ran no assertion"
    partial = PARTIAL_LINE.search(text)
    return "pass", passed, failed, ("partial: %s" % partial.group(0).strip() if partial else "")


def show(entry):
    label = {"pass": "ok  ", "skip": "SKIP", "fail": "FAIL"}[entry["result"]]
    counts = "" if entry["passed"] is None else "%d passed, %d failed" % (entry["passed"], entry["failed"])
    said = "; ".join(part for part in (counts, entry["detail"]) if part)
    took = "  (%.1f s)" % entry["seconds"] if entry["seconds"] else ""
    print("%s  %s%s%s" % (label, entry["suite"], "  " + said if said else "", took), flush=True)
    for line in entry.get("tail", []):
        print("        %s" % line, flush=True)


def write_record(record):
    RECEIPT.parent.mkdir(parents=True, exist_ok=True)
    staging = RECEIPT.with_name(RECEIPT.name + ".tmp")
    staging.write_text(json.dumps(record, indent=1) + "\n")
    os.replace(staging, RECEIPT)


def run_all(suites, host, limit, strict, scratch):
    path, pin_note = pinned_path(scratch)
    print("python3: %s" % pin_note, flush=True)
    entries = []
    view = None
    for index, rel in enumerate(suites):
        entry = {"suite": rel, "where": "repo", "result": "skip", "passed": None, "failed": None, "seconds": 0.0, "detail": ""}
        wanted = HOST_NEEDS.get(rel, [])
        missing_tools = [t for t in TOOL_NEEDS.get(rel, []) if not shutil.which(t)]
        lacking = [f for f in wanted if host and not host_has(host, f)]
        if missing_tools:
            entry["detail"] = "needs %s on PATH" % ", ".join(missing_tools)
        elif wanted and not host:
            entry["detail"] = "needs the heimdall host (%s): set HMD_HOST_DIR to a heimdall checkout, or put one next to this repository as ../heimdall" % ", ".join(wanted)
        elif lacking:
            entry.update(result="fail", detail="the host at %s has no %s, which HOST-CONTRACT.md section 8 says this suite needs" % (host, ", ".join(lacking)))
        else:
            in_view = bool(host) and (rel in HOST_NEEDS or rel in HOST_OPTIONAL)
            if in_view and view is None:
                view = build_host_view(host, scratch)
            run_dir = scratch / "run" / str(index)
            log = scratch / ("run-%d.log" % index)
            code, entry["seconds"] = run_suite(view if in_view else REPO, rel, suite_env(path, run_dir), log, limit)
            shutil.rmtree(run_dir, ignore_errors=True)
            text = log.read_text(encoding="utf-8", errors="replace")
            entry["where"] = "host-view" if in_view else "repo"
            entry["result"], entry["passed"], entry["failed"], entry["detail"] = judge(rel, code, text)
            if entry["result"] == "fail":
                entry["tail"] = text.rstrip("\n").splitlines()[-TAIL_LINES:]
        if strict and (entry["result"] == "skip" or entry["detail"].startswith("partial:")):
            entry.update(result="fail", detail="skipped under HMD_REQUIRE_HOST=1: %s" % entry["detail"])
        entries.append(entry)
        show(entry)
    return entries


def main(argv):
    only = argv[1] if len(argv) > 1 else ""
    limit = timeout_seconds()
    strict = os.environ.get("HMD_REQUIRE_HOST") == "1"
    suites = [s for s in discover() if only in s]
    if not suites:
        die(2, "no suite is named like %r" % only)
    host, how = find_host()
    print("carried suites: %d to run; host: %s" % (len(suites), "%s (%s)" % (host, how) if host else "none (%s)" % how), flush=True)

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    scratch = Path(tempfile.mkdtemp(prefix="hmd-carried-suites."))
    try:
        entries = run_all(suites, host, limit, strict, scratch)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)

    totals = {r: sum(1 for e in entries if e["result"] == r) for r in ("pass", "skip", "fail")}
    partial = sum(1 for e in entries if e["result"] == "pass" and e["detail"].startswith("partial:"))
    print("\ncarried suites: %d suites, %d passed (%d partial), %d skipped, %d failed" % (len(entries), totals["pass"], partial, totals["skip"], totals["fail"]), flush=True)
    for e in entries:
        if e["result"] == "skip":
            print("  skipped %s: %s" % (e["suite"], e["detail"]))
        e.pop("tail", None)
    write_record({
        "schema": 1,
        "finished": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "filter": only,
        "host": str(host) if host else None,
        "host_found_by": how,
        "require_host": strict,
        "totals": {"suites": len(entries), "passed": totals["pass"], "partial": partial, "skipped": totals["skip"], "failed": totals["fail"]},
        "suites": entries,
    })
    print("record: %s" % RECEIPT.relative_to(REPO), flush=True)
    return 1 if totals["fail"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
