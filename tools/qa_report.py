#!/usr/bin/env python3
"""QA report: one HTML page from the JSON the test run leaves in a folder.

    python3 tools/qa_report.py build/qa        # writes build/qa/index.html

Reads unit.json (tests/run_tests.gd --json), scenario_*.json (one per QA
scenario, tests/qa/qa_runner.gd) and walkthrough.json (--walkthrough --qa-out).
Whatever is missing is shown as not run. Failures and engine errors come first;
then the slowest tests and walkthrough steps, so a run that got slower shows.
No third-party packages: the page is plain HTML with its styles inline and
opens from the CI artifact as is. Exit code 0 always: the run's own exit code
says pass or fail, the report only shows why.
"""

import glob
import html
import json
import os
import sys
from datetime import datetime, timezone


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def esc(s):
    return html.escape(str(s))


def ms(v):
    v = float(v or 0)
    return f"{v / 1000:.1f} s" if v >= 1000 else f"{v:.0f} ms"


def badge(status):
    ok = status == "ok"
    return f'<span class="badge {"ok" if ok else "fail"}">{"PASS" if ok else "FAIL"}</span>'


def errors_table(errors, show_context=True):
    if not errors:
        return ""
    rows = []
    for e in errors:
        ctx = f"<td>{esc(e.get('context', ''))}</td>" if show_context else ""
        rows.append(
            f"<tr class='{esc(e.get('type', ''))}'>{ctx}<td>{esc(e.get('type', ''))}</td>"
            f"<td>{esc(e.get('message', ''))}</td><td class='mono'>{esc(e.get('where', ''))}</td></tr>"
        )
    head = "<th>context</th>" if show_context else ""
    return f"<table><tr>{head}<th>type</th><th>message</th><th>where</th></tr>{''.join(rows)}</table>"


def section_unit(unit):
    if unit is None:
        return "<section><h2>Unit tests</h2><p class='muted'>not run</p></section>"
    tests = unit.get("tests", [])
    failed = [t for t in tests if t.get("status") != "ok"]
    out = [f"<section><h2>Unit tests {badge('ok' if not failed else 'fail')}</h2>",
           f"<p>{unit.get('total', 0)} tests, {unit.get('failed', 0)} failed, {ms(unit.get('ms'))}</p>"]
    if failed:
        out.append("<h3>Failed</h3>")
        for t in failed:
            out.append(f"<details open><summary><b>{esc(t['file'])}</b> {esc(t['name'])}</summary><ul>")
            out += [f"<li>{esc(m)}</li>" for m in t.get("failures", [])]
            out.append("</ul></details>")
    slow = sorted(tests, key=lambda t: -float(t.get("ms", 0)))[:15]
    top = max([float(t.get("ms", 0)) for t in slow] or [1]) or 1
    out.append("<h3>Slowest</h3><table><tr><th>test</th><th class='num'>time</th><th></th><th class='num'>objects left</th></tr>")
    for t in slow:
        w = 100 * float(t.get("ms", 0)) / top
        out.append(f"<tr><td>{esc(t['file'])} <span class='muted'>{esc(t['name'])}</span></td>"
                   f"<td class='num'>{ms(t.get('ms'))}</td><td class='barcell'><div class='bar' style='width:{w:.1f}%'></div></td>"
                   f"<td class='num'>{max(0, int(t.get('objects', 0)))}</td></tr>")
    out.append("</table>")
    leaky = [t for t in tests if int(t.get("objects", 0)) > 200]
    if leaky:
        out.append("<h3>Left objects behind (&gt; 200)</h3><ul>")
        out += [f"<li>{esc(t['file'])} {esc(t['name'])}: {t['objects']}</li>" for t in leaky]
        out.append("</ul>")
    errs = [e | {"context": f"{t['file']}::{t['name']}"} for t in tests for e in t.get("errors", [])]
    if errs:
        out.append(f"<h3>Engine errors during tests ({len(errs)})</h3>")
        out.append(errors_table(errs))
    out.append("</section>")
    return "\n".join(out)


def section_scenarios(scenarios, root):
    out = ["<section><h2>Scenarios</h2>"]
    if not scenarios:
        out.append("<p class='muted'>not run</p></section>")
        return "\n".join(out)
    out.append("<table><tr><th>scenario</th><th></th><th class='num'>time</th><th class='num'>failures</th><th class='num'>errors</th></tr>")
    for s in scenarios:
        out.append(f"<tr><td><a href='#sc-{esc(s['name'])}'>{esc(s['name'])}</a></td><td>{badge(s.get('status'))}</td>"
                   f"<td class='num'>{ms(s.get('ms'))}</td><td class='num'>{len(s.get('failures', []))}</td>"
                   f"<td class='num'>{len(s.get('errors', []))}</td></tr>")
    out.append("</table>")
    for s in scenarios:
        out.append(f"<details id='sc-{esc(s['name'])}' {'open' if s.get('status') != 'ok' else ''}>"
                   f"<summary>{badge(s.get('status'))} <b>{esc(s['name'])}</b> "
                   f"<span class='muted'>{ms(s.get('ms'))}, finds {s.get('found', '?')}/{s.get('total', '?')}</span></summary>")
        out.append("<table><tr><th>step</th><th class='num'>time</th><th>failures</th></tr>")
        for st in s.get("steps", []):
            fails = "".join(f"<div class='failtext'>{esc(f)}</div>" for f in st.get("failures", []))
            out.append(f"<tr><td>{esc(st.get('label'))}</td><td class='num'>{ms(st.get('ms'))}</td><td>{fails}</td></tr>")
        out.append("</table>")
        extra = [f for f in s.get("failures", []) if f.startswith("SCRIPT ERROR")]
        if extra:
            out.append("<ul>" + "".join(f"<li class='failtext'>{esc(f)}</li>" for f in extra) + "</ul>")
        out.append(errors_table(s.get("errors", []), show_context=False))
        shots = [p for p in s.get("shots", []) if os.path.exists(os.path.join(root, p))]
        if shots:
            out.append("<div class='shots'>" + "".join(
                f"<a href='{esc(p)}'><img src='{esc(p)}' alt='{esc(p)}' loading='lazy'></a>" for p in shots) + "</div>")
        out.append("</details>")
    out.append("</section>")
    return "\n".join(out)


def section_walkthrough(w):
    if w is None:
        return "<section><h2>Walkthrough</h2><p class='muted'>not run</p></section>"
    out = [f"<section><h2>Walkthrough {badge(w.get('status'))}</h2>",
           f"<p>{ms(w.get('ms'))} · finds {w.get('found')}/{w.get('total')} · lamps {w.get('lamps')}/{w.get('lamps_total')}"
           f" · {len(w.get('steps', []))} route steps</p>"]
    if w.get("failures"):
        out.append("<ul>" + "".join(f"<li class='failtext'>{esc(f)}</li>" for f in w["failures"]) + "</ul>")
    steps = w.get("steps", [])
    slow = sorted(steps, key=lambda s: -float(s.get("ms", 0)))[:12]
    top = max([float(s.get("ms", 0)) for s in slow] or [1]) or 1
    out.append("<h3>Slowest route steps</h3><table><tr><th>step</th><th class='num'>time</th><th></th></tr>")
    for st in slow:
        w_ = 100 * float(st.get("ms", 0)) / top
        out.append(f"<tr><td class='mono'>{esc(st.get('step'))}</td><td class='num'>{ms(st.get('ms'))}</td>"
                   f"<td class='barcell'><div class='bar' style='width:{w_:.1f}%'></div></td></tr>")
    out.append("</table>")
    if w.get("errors"):
        out.append(f"<h3>Engine errors ({len(w['errors'])})</h3>" + errors_table(w["errors"], show_context=False))
    out.append("</section>")
    return "\n".join(out)


CSS = """
:root { --bg:#f6f3ee; --fg:#231f1a; --muted:#7a7066; --card:#fffdf9; --line:#e2d9cc;
  --ok:#2f7d4f; --fail:#b3362b; --bar:#c08a3e; --warn:#a46a00; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg:#17140f; --fg:#ece4d8; --muted:#a3988a; --card:#211c16; --line:#3a3128;
  --ok:#5fbf84; --fail:#e0675b; --bar:#d39b4c; --warn:#e0a640; } }
body { background:var(--bg); color:var(--fg); font:15px/1.5 system-ui, sans-serif; margin:0; padding:24px 16px; }
main { max-width:1100px; margin:0 auto; }
h1 { margin:0 0 4px; font-size:24px; } h2 { margin:0 0 8px; font-size:19px; } h3 { font-size:15px; margin:16px 0 6px; }
section { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:16px; margin:16px 0; overflow-x:auto; }
.cards { display:grid; grid-template-columns:repeat(auto-fit, minmax(160px, 1fr)); gap:12px; margin-top:16px; }
.card { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:12px; }
.card .v { font-size:26px; font-weight:600; } .card .k { color:var(--muted); font-size:13px; }
table { border-collapse:collapse; width:100%; font-size:14px; }
th, td { text-align:left; padding:4px 8px; border-bottom:1px solid var(--line); vertical-align:top; }
th { color:var(--muted); font-weight:500; }
.num { text-align:right; white-space:nowrap; font-variant-numeric:tabular-nums; }
.mono { font-family:ui-monospace, monospace; font-size:13px; word-break:break-all; }
a { color:var(--bar); } .muted { color:var(--muted); }
th.num { text-align:right; } .failtext { color:var(--fail); }
.badge { font-size:12px; font-weight:700; padding:1px 6px; border-radius:4px; color:#fff; vertical-align:middle; }
.badge.ok { background:var(--ok); } .badge.fail { background:var(--fail); }
.barcell { width:30%; } .bar { height:10px; background:var(--bar); border-radius:2px; min-width:1px; }
tr.script td, tr.error td { color:var(--fail); } tr.warning td { color:var(--warn); }
details { border-top:1px solid var(--line); padding:8px 0; } summary { cursor:pointer; }
.shots { display:grid; grid-template-columns:repeat(auto-fill, minmax(240px, 1fr)); gap:8px; margin-top:8px; }
.shots img { width:100%; border-radius:4px; border:1px solid var(--line); }
"""


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "build/qa"
    unit = load(os.path.join(root, "unit.json"))
    walk = load(os.path.join(root, "walkthrough.json"))
    scenarios = [s for s in (load(p) for p in sorted(glob.glob(os.path.join(root, "scenario_*.json")))) if s]
    sc_fail = sum(1 for s in scenarios if s.get("status") != "ok")
    errors = sum(len(t.get("errors", [])) for t in (unit or {}).get("tests", [])) \
        + sum(len(s.get("errors", [])) for s in scenarios) + len((walk or {}).get("errors", []))
    all_ok = unit is not None and unit.get("failed", 1) == 0 and sc_fail == 0 and (walk or {}).get("status") == "ok"
    commit = os.environ.get("GITHUB_SHA", "")[:7]
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    cards = [
        ("Unit tests", f"{(unit or {}).get('total', 0) - (unit or {}).get('failed', 0)}/{(unit or {}).get('total', 0)}" if unit else "—"),
        ("Scenarios", f"{len(scenarios) - sc_fail}/{len(scenarios)}" if scenarios else "—"),
        ("Walkthrough", ("PASS" if walk.get("status") == "ok" else "FAIL") if walk else "—"),
        ("Engine errors", str(errors)),
    ]
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>QA Report</title><style>{CSS}</style></head>
<body><main><h1>QA report {badge('ok' if all_ok else 'fail')}</h1>
<div class="muted">{esc(stamp)}{' · ' + esc(commit) if commit else ''}</div>
<div class="cards">{''.join(f"<div class='card'><div class='v'>{esc(v)}</div><div class='k'>{esc(k)}</div></div>" for k, v in cards)}</div>
{section_scenarios(scenarios, root)}
{section_walkthrough(walk)}
{section_unit(unit)}
</main></body></html>"""
    out = os.path.join(root, "index.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print(f"qa report: {out} ({'PASS' if all_ok else 'FAIL'})")


if __name__ == "__main__":
    main()
