#!/usr/bin/env bash
# v1.11 — Remove the Misc group and its default "Miscellaneous" chore.
# Run from ~/Chores. Asserts against v1.10 pre-state.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import re, pathlib
p = pathlib.Path('index.html')
s = p.read_text(encoding='utf-8')

def rep(old, new, count=1):
    global s
    n = s.count(old)
    assert n == count, f"expected {count}x of {old[:60]!r}, found {n}"
    s = s.replace(old, new)

# 1. Drop the default Misc chore
rep("\n  { id: 'mi-misc',       group: 'Misc', label: 'Miscellaneous', cadence: 14 },\n", "\n")

# 2. Drop Misc from group order + meta
rep("const GROUP_ORDER = ['Bed Change', 'Hoover', 'Dusting', 'Bathrooms', 'Grooming', 'Misc'];",
    "const GROUP_ORDER = ['Bed Change', 'Hoover', 'Dusting', 'Bathrooms', 'Grooming'];\n"
    "// Default task IDs removed in later versions — stripped from saved localStorage tasks on load.\n"
    "const RETIRED_TASK_IDS = new Set(['mi-misc']);")
rep("  'Misc':       { tag: '06', sub: 'other',          color: '#6b6b6b' },\n", "")

# 3. Strip retired defaults from saved local tasks (localStorage holds defaults too)
rep("          const savedIds = new Set(parsed.tasks.map((t) => t.id));\n"
    "          const merged = [...parsed.tasks, ...DEFAULT_TASKS.filter((t) => !savedIds.has(t.id))];",
    "          const savedTasks = parsed.tasks.filter((t) => !RETIRED_TASK_IDS.has(t.id));\n"
    "          const savedIds = new Set(savedTasks.map((t) => t.id));\n"
    "          const merged = [...savedTasks, ...DEFAULT_TASKS.filter((t) => !savedIds.has(t.id))];")

# 4. Add-chore modal defaulted to Misc — default to first group instead
rep("  const [group, setGroup] = useState('Misc');", "  const [group, setGroup] = useState(GROUP_ORDER[0]);")

# 5. Safety net: any custom chore still in a group not in GROUP_ORDER (e.g. an old custom 'Misc'
#    chore) still renders at the bottom rather than vanishing silently.
rep("            {!loading && GROUP_ORDER.map((groupName) => {\n"
    "              const items = grouped[groupName];\n"
    "              if (!items || items.length === 0) return null;\n"
    "              const meta = GROUP_META[groupName];",
    "            {!loading && [...GROUP_ORDER, ...Object.keys(grouped).filter((g) => !GROUP_ORDER.includes(g))].map((groupName) => {\n"
    "              const items = grouped[groupName];\n"
    "              if (!items || items.length === 0) return null;\n"
    "              const meta = GROUP_META[groupName] || { tag: '··', sub: 'other', color: '#6b6b6b' };")

# 6. Version bump
rep("const VERSION = '1.9';", "const VERSION = '1.11';")
s = re.sub(r"const VERSION_DATE = '[0-9-]+';", "const VERSION_DATE = '2026-10-04';", s, count=1)

p.write_text(s, encoding='utf-8')
print("v1.11 applied: Misc group + Miscellaneous chore removed.")
PY
