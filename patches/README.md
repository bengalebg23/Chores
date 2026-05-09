# Patches

Each `vX.Y_<description>.sh` file is the exact patch that produced a tagged version of the app. Patches are run once at release time and committed alongside the changes they made.

## Convention

- Filename: `vX.Y_short_description.sh` — e.g. `v1.5_dark_mode.sh`
- Each patch is a self-contained bash script, typically wrapping a Python heredoc that edits `index.html` in place plus `sed` calls for `sw.js`
- Patches `assert` against the expected pre-state of the file, so they fail loudly if run against the wrong version
- Patches are **historical record**, not "replay anytime" tools — they only work against the exact file state they were authored for

## Why we keep them

1. **Audit trail** — paired with git log, makes every release self-documenting
2. **Recovery** — if the repo gets out of sync, patches can be replayed against an earlier tag
3. **Onboarding** — a fresh Claude chat can read recent patches from the raw URL and understand what's been changing without needing the full conversation history

## Workflow

Patches are typically delivered as a downloaded `.sh` file from Claude. To apply:

```bash
mkdir -p ~/Chores/patches
cp ~/storage/downloads/<patch>.sh ~/Chores/patches/vX.Y_description.sh
cd ~/Chores
bash patches/vX.Y_description.sh
sed -i "s/const CACHE_VERSION = .*/const CACHE_VERSION = 'vX.Y';/" sw.js
ct X.Y
```

The `ct` alias commits everything, tags, and pushes.
