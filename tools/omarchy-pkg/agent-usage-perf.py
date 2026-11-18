#!/usr/bin/env python3
"""Make Omarchy's agent usage collectors cheap to start.

Applies two changes to an Omarchy tree (the git checkout or an unpacked package,
anything with bin/ and shell/plugins/agents/):

1. Each bin/omarchy-agent-usage-<name> collector (a Python script) moves to
   shell/plugins/agents/usage/<name>.py and the command becomes a launcher that
   imports it. Python never caches bytecode for a script run as __main__, so every
   refresh recompiled all 23 collectors; as modules they load from __pycache__.
2. bin/omarchy-agent-usage-update lowers its own CPU and I/O priority, which every
   collector it starts inherits, so a refresh never competes with the desktop.

Idempotent: a tree that already has the changes is left as it is.

Usage: agent-usage-perf.py TREE [--bin DIR]
  TREE  the Omarchy tree (has shell/plugins/agents/)
  --bin where the real bin scripts are: TREE/bin in the git tree (default), usr/bin in
        the package, whose usr/share/omarchy/bin/* are absolute symlinks to /usr/bin.
"""
import re
import sys
from pathlib import Path

LAUNCHER = '''#!/usr/bin/python3
# Launcher: the collector lives in shell/plugins/agents/usage/{name}.py so Python can
# cache its bytecode; a script run directly is recompiled on every call.
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.environ["OMARCHY_PATH"], "shell", "plugins", "agents"))

from usage.{module} import main

if __name__ == "__main__":
    {call}
'''

PRIORITY = '''# Usage refreshes are background work: run them, and every collector they start, at
# low CPU and I/O priority so they never compete with the desktop.
renice -n 15 -p $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true
'''

GUARD = re.compile(r'\nif __name__ == "__main__":[ \t]*\n[ \t]+(?P<call>\S[^\n]*?)[ \t]*\s*\Z')


def regular_file(path: Path) -> Path:
    # Never follow a symlink: in a package tree they point at the live system.
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f"{path}: not a regular file; pass --bin to the real scripts")
    return path


def convert_collector(script: Path, usage_dir: Path) -> bool:
    text = regular_file(script).read_text()
    name = script.name.removeprefix("omarchy-agent-usage-")
    if "from usage." in text:
        return False
    if not text.startswith("#!/usr/bin/python3"):
        raise SystemExit(f"{script}: not a python collector")
    match = GUARD.search(text)
    if not match:
        raise SystemExit(f"{script}: no __main__ guard at the end")
    module = name.replace("-", "_")
    body = text.split("\n", 1)[1]
    (usage_dir / f"{module}.py").write_text(body)
    script.write_text(LAUNCHER.format(name=module, module=module, call=match.group("call")))
    return True


HARNESS_OLD = '''def harness(name):
  path = os.path.join(os.environ["OMARCHY_PATH"], "bin", f"omarchy-agent-usage-{name}")
  loader = importlib.machinery.SourceFileLoader(f"omarchy_agent_usage_{name}", path)
  module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
  loader.exec_module(module)
  return module
'''

HARNESS_NEW = '''def harness(name):
  # The harness collectors are modules beside this one (usage/<name>.py).
  return importlib.import_module(f"usage.{name}")
'''


def fix_harness_loader(local: Path) -> bool:
    """local loaded its sibling collectors from bin/ by path; they are modules now."""
    text = regular_file(local).read_text()
    if HARNESS_NEW in text:
        return False
    if HARNESS_OLD not in text:
        raise SystemExit(f"{local}: harness() loader changed upstream; update this tool")
    local.write_text(text.replace(HARNESS_OLD, HARNESS_NEW))
    return True


def add_priority(update: Path) -> bool:
    text = regular_file(update).read_text()
    if "renice -n 15" in text:
        return False
    marker = 'USAGE_DIR="'
    if marker not in text:
        raise SystemExit(f"{update}: anchor {marker!r} not found")
    update.write_text(text.replace(marker, PRIORITY + "\n" + marker, 1))
    return True


def main() -> None:
    args = sys.argv[1:]
    tree = Path(args[0])
    bin_dir = Path(args[args.index("--bin") + 1]) if "--bin" in args else tree / "bin"
    usage_dir = tree / "shell/plugins/agents/usage"
    usage_dir.mkdir(exist_ok=True)
    init = usage_dir / "__init__.py"
    if not init.exists():
        init.write_text('"""Agent usage collectors, one module per agent (see bin/omarchy-agent-usage-*)."""\n')
    converted = 0
    for script in sorted(bin_dir.glob("omarchy-agent-usage-*")):
        if script.name == "omarchy-agent-usage-update":
            continue
        converted += convert_collector(script, usage_dir)
    harness_fixed = fix_harness_loader(usage_dir / "local.py")
    prioritised = add_priority(bin_dir / "omarchy-agent-usage-update")
    print(f"collectors converted: {converted}; harness loader fixed: {harness_fixed}; "
          f"update priority added: {prioritised}")


if __name__ == "__main__":
    main()
