#!/usr/bin/env python3
"""peek.py -- read what a use-case run produced, the way a person (or the tool that consumes it) reads it. Helper of tests/use_cases.

  peek.py plain  FILE        the bar's text with the colour codes removed
  peek.py row    FILE N      row N (1-based) of the bar, colour codes removed, trailing blanks trimmed
  peek.py rawrow FILE N      row N exactly as emitted, colour codes included
  peek.py rows   FILE        how many rows the bar has (blank lines do not count)
  peek.py widths FILE        the distinct widths, in terminal cells, of the bar's rows, comma separated
  peek.py tasks  FILE        the subagent rows: one `id<TAB>content` line per JSON line of the file
  peek.py get    FILE PATH   the JSON value at PATH (dot separated keys) in a JSON file; a string prints bare, anything else as JSON

The width of a row is counted here, on purpose, and not with the renderer's own function: a test that measured the bar with the code it tests
would agree with it by construction. Wide glyphs (CJK, the emoji lightning bolt) take two cells.

Exit: 0 printed what was asked, 1 nothing there (a missing row, key or file), 2 usage. Standard library only.
"""
import json
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
WIDE = ((0x1100, 0x115F), (0x2E80, 0x303E), (0x3041, 0x33FF), (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xAC00, 0xD7A3), (0x1F000, 0x1FAFF))
ZERO_WIDTH = (0x200B, 0x200D, 0xFE0F)
BOLT = 0x26A1


def cells(text):
    """The width of a row in terminal cells, colour codes not counted."""
    n = 0
    for ch in ANSI.sub("", text):
        o = ord(ch)
        if o in ZERO_WIDTH or 0x0300 <= o <= 0x036F:
            continue
        n += 2 if o == BOLT or any(lo <= o <= hi for lo, hi in WIDE) else 1
    return n


def read_text(path):
    with open(path, "rb") as fh:
        return fh.read().decode("utf-8", "replace")


def bar_rows(path):
    return [line for line in read_text(path).split("\n") if line != ""]


def nth_row(path, n):
    rows = bar_rows(path)
    if 1 <= n <= len(rows):
        return rows[n - 1]
    return None


def json_value(path, dotted):
    with open(path, encoding="utf-8") as fh:
        node = json.load(fh)
    for key in dotted.split("."):
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node


def say(text):
    sys.stdout.write(text + "\n")
    return 0


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    cmd, path, rest = argv[1], argv[2], argv[3:]
    try:
        if cmd == "plain" and not rest:
            return say(ANSI.sub("", read_text(path)).rstrip("\n"))
        if cmd in ("row", "rawrow") and len(rest) == 1:
            row = nth_row(path, int(rest[0]))
            if row is None:
                return 1
            return say(row if cmd == "rawrow" else ANSI.sub("", row).rstrip())
        if cmd == "rows" and not rest:
            return say(str(len(bar_rows(path))))
        if cmd == "widths" and not rest:
            return say(",".join(str(w) for w in sorted({cells(r) for r in bar_rows(path)})))
        if cmd == "tasks" and not rest:
            for line in bar_rows(path):
                task = json.loads(line)
                say("%s\t%s" % (task["id"], task["content"]))
            return 0
        if cmd == "get" and len(rest) == 1:
            value = json_value(path, rest[0])
            if value is None:
                return 1
            return say(value if isinstance(value, str) else json.dumps(value, sort_keys=True))
    except (OSError, ValueError, KeyError) as exc:
        sys.stderr.write("peek: %s\n" % exc)
        return 1
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
