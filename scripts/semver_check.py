#!/usr/bin/env python3
"""What version bump does a module change need? Compares a module's interface with its last release.

  python scripts/semver_check.py vpc                      # vs the last vpc/v* tag (first release if none)
  python scripts/semver_check.py vpc --base origin/main   # vs any git ref
  python scripts/semver_check.py vpc --proposed 1.1.0     # exit 1 if 1.1.0 is too small a bump
  python scripts/semver_check.py --base-dir old/ --head-dir new/   # two directories (used by the CI self-test)

The interface comes from `terraform-docs json` (inputs, outputs, requirements, resources), run on the module at
both versions. Rules, from the README's versioning table:

  MAJOR  an input removed, newly required, or with a changed type or default; an output removed; a resource
         removed or renamed without a `moved` block (existing users would have it destroyed and recreated);
         a higher minimum Terraform or provider version
  MINOR  a new optional input, a new output, a new resource
  PATCH  anything else (descriptions, internals with an unchanged interface and resource addresses)

What it can't see: a change inside a resource's arguments that forces replacement (for example a new
`availability_zone`). The plan-level tests and a `terraform plan` against real state cover that.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TFDOCS_IMAGE = "quay.io/terraform-docs/terraform-docs:0.20.0"
LEVELS = ["none", "patch", "minor", "major"]


def interface(module_dir: Path) -> dict:
    """terraform-docs json for a module directory, plus its `moved` blocks."""
    if shutil.which("terraform-docs"):
        cmd = ["terraform-docs", "json", "--sort-by", "name", str(module_dir)]
    else:
        cmd = ["docker", "run", "--rm", "-v", f"{module_dir.resolve()}:/m", TFDOCS_IMAGE,
               "json", "--sort-by", "name", "/m"]
    doc = json.loads(subprocess.check_output(cmd, text=True))
    doc["moved"] = moved_blocks(module_dir)
    return doc


MOVED = re.compile(r'moved\s*\{[^}]*?from\s*=\s*([\w.\[\]"-]+)[^}]*?to\s*=\s*([\w.\[\]"-]+)', re.DOTALL)


def moved_blocks(module_dir: Path) -> dict[str, str]:
    out = {}
    for f in module_dir.glob("*.tf"):
        for a, b in MOVED.findall(f.read_text(encoding="utf-8")):
            out[a] = b
    return out


def _min_version(constraint: str | None) -> tuple[int, ...]:
    """Lower bound of a version constraint such as '>= 1.9', '~> 5.0', '>= 5.40, < 7.0'."""
    m = re.search(r"(?:>=|~>|=)?\s*(\d+(?:\.\d+)*)", constraint or "")
    return tuple(int(x) for x in m.group(1).split(".")) if m else ()


def _resource_addr(r: dict) -> str:
    return f'{r["type"]}.{r["name"]}' if r.get("mode", "managed") == "managed" else f'data.{r["type"]}.{r["name"]}'


def diff(base: dict, head: dict) -> tuple[str, list[tuple[str, str]]]:
    """Return the required bump ("none", "patch", "minor", "major") and the reasons, most severe first."""
    reasons: list[tuple[str, str]] = []
    bi = {i["name"]: i for i in base.get("inputs") or []}
    hi = {i["name"]: i for i in head.get("inputs") or []}
    for name in sorted(bi.keys() - hi.keys()):
        reasons.append(("major", f"input `{name}` removed"))
    for name in sorted(hi.keys() - bi.keys()):
        if hi[name].get("required"):
            reasons.append(("major", f"new required input `{name}`"))
        else:
            reasons.append(("minor", f"new optional input `{name}`"))
    for name in sorted(bi.keys() & hi.keys()):
        a, b = bi[name], hi[name]
        if not a.get("required") and b.get("required"):
            reasons.append(("major", f"input `{name}` is now required"))
        if (a.get("type") or "").replace(" ", "") != (b.get("type") or "").replace(" ", ""):
            reasons.append(("major", f"input `{name}` type changed: {a.get('type')} -> {b.get('type')}"))
        elif not a.get("required") and not b.get("required") and a.get("default") != b.get("default"):
            reasons.append(("major", (f"input `{name}` default changed: {json.dumps(a.get('default'))} -> "
                                     f"{json.dumps(b.get('default'))}")))
        elif (a.get("description") or "") != (b.get("description") or ""):
            reasons.append(("patch", f"input `{name}` description changed"))

    bo = {o["name"] for o in base.get("outputs") or []}
    ho = {o["name"] for o in head.get("outputs") or []}
    reasons += [("major", f"output `{n}` removed") for n in sorted(bo - ho)]
    reasons += [("minor", f"new output `{n}`") for n in sorted(ho - bo)]

    br = {_resource_addr(r) for r in base.get("resources") or [] if r.get("mode", "managed") == "managed"}
    hr = {_resource_addr(r) for r in head.get("resources") or [] if r.get("mode", "managed") == "managed"}
    moved = head.get("moved") or {}
    for addr in sorted(br - hr):
        target = moved.get(addr)
        if target and target in hr:
            reasons.append(("patch", f"resource `{addr}` renamed to `{target}` with a moved block"))
        else:
            reasons.append(("major", (f"resource `{addr}` removed or renamed without a moved block: existing "
                                     f"users would have it destroyed")))
    renamed_to = set(moved.values())
    reasons += [("minor", f"new resource `{a}`") for a in sorted(hr - br - renamed_to)]

    breq = {r["name"]: r.get("version") for r in base.get("requirements") or []}
    hreq = {r["name"]: r.get("version") for r in head.get("requirements") or []}
    for name in sorted(breq.keys() | hreq.keys()):
        if _min_version(hreq.get(name)) > _min_version(breq.get(name)):
            reasons.append(("major", f"minimum `{name}` version raised: {breq.get(name)} -> {hreq.get(name)}"))

    level = max((LEVELS.index(lv) for lv, _ in reasons), default=0)
    reasons.sort(key=lambda r: -LEVELS.index(r[0]))
    return LEVELS[level], reasons


def bump(version: str, level: str) -> str:
    major, minor, patch = (int(x) for x in version.split("."))
    if level == "major":
        return f"{major + 1}.0.0"
    if level == "minor":
        return f"{major}.{minor + 1}.0"
    if level == "patch":
        return f"{major}.{minor}.{patch + 1}"
    return version


def is_enough(last: str, proposed: str, level: str) -> bool:
    """Is `proposed` a big enough step from `last` for a change of `level`? (Before 1.0.0 nothing is promised.)"""
    lv = tuple(int(x) for x in last.split("."))
    pv = tuple(int(x) for x in proposed.split("."))
    if pv <= lv:
        return False
    if lv[0] == 0:
        return True
    need = tuple(int(x) for x in bump(last, level).split("."))
    return pv >= need


def last_tag(module: str) -> str | None:
    tags = subprocess.run(["git", "-C", str(ROOT), "tag", "-l", f"{module}/v*"], capture_output=True, text=True,
                          check=True).stdout.split()
    versions = sorted((t.split("/v", 1)[1] for t in tags), key=lambda v: tuple(int(x) for x in v.split(".")))
    return versions[-1] if versions else None


def module_at(ref: str, module: str, into: Path) -> Path:
    """Export modules/<module> as it was at a git ref into a temporary directory."""
    archive = subprocess.run(["git", "-C", str(ROOT), "archive", ref, f"modules/{module}"], capture_output=True,
                             check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(into)], input=archive, check=True)
    return into / "modules" / module


def report(module: str, base_label: str, level: str, reasons: list[tuple[str, str]]) -> str:
    lines = [f"### {module}: **{level.upper()}** change vs {base_label}", ""]
    lines += [f"- {lv}: {text}" for lv, text in reasons] or ["- no interface or resource address changes"]
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("module", nargs="?")
    ap.add_argument("--base", help="git ref to compare with (default: the module's last tag)")
    ap.add_argument("--proposed", help="version you intend to release; exit 1 if the bump is too small")
    ap.add_argument("--base-dir", type=Path)
    ap.add_argument("--head-dir", type=Path)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    if a.base_dir and a.head_dir:
        level, reasons = diff(interface(a.base_dir), interface(a.head_dir))
        label, last = str(a.base_dir), None
    else:
        if not a.module:
            ap.error("give a module name, or --base-dir and --head-dir")
        last = last_tag(a.module)
        ref = a.base or (f"{a.module}/v{last}" if last else None)
        if ref is None:
            print(f"{a.module}: no previous release, so any version is a first release")
            return 0
        with tempfile.TemporaryDirectory() as tmp:
            base_dir = module_at(ref, a.module, Path(tmp))
            level, reasons = diff(interface(base_dir), interface(ROOT / "modules" / a.module))
        label = ref
    if a.json:
        print(json.dumps({"module": a.module, "base": label, "level": level, "reasons": reasons}))
    else:
        sys.stdout.write(report(a.module or "module", label, level, reasons))
    if a.proposed:
        if last is None:
            return 0
        if not is_enough(last, a.proposed, level):
            print(f"\n{a.proposed} is too small a step from {last} for a {level.upper()} change "
                  f"(at least {bump(last, level)})", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
