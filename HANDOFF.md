# House Ledger — Handoff

A family household-chores PWA. Single-file `index.html` served from GitHub Pages, with localStorage + Firebase Realtime Database for persistence. Built around an existing paper-spreadsheet chore tracker (`Chores.pdf`) used by the Gale family at 17 Melody Drive, Sileby.

**Live app:** https://bengalebg23.github.io/Chores/
**Repo:** https://github.com/bengalebg23/Chores
**Current version:** v1.7 (2026-05-09)
**Branch:** `main` (no dev/staging split — push straight to live)

---

## Architecture

Single-file PWA. `index.html` contains everything:
- React 18 + Babel standalone (compile-in-browser, no build step)
- Tailwind via CDN
- Firebase compat SDK v10.7.1 (app + database modules)
- Inline service worker registration

Companion files:
- `sw.js` — service worker, network-first for navigation. **Bump `CACHE_VERSION` on every release** to force clients to fetch fresh code.
- `patches/` — every release patch archived here for audit/replay. Convention: `vX.Y_description.sh`.
- `HANDOFF.md` — this file. Always reflects the latest version.

**No build step, no node_modules, no bundler.** Everything ships as-is.

### Storage model

- `localStorage` key: `house-ledger-v1` — JSON `{ history, tasks }`. Read first on load (fast).
- Firebase Realtime Database:
  - `/history` — task completion log, source of truth
  - `/customTasks` — user-added chores (custom additions, not defaults), synced across devices
- Theme preference: `localStorage["house-ledger-theme"]` = `"dark"` or `"light"`.

Tasks layering on load: `DEFAULT_TASKS` (hardcoded) + saved-local-custom (from localStorage) + Firebase customTasks, deduped by ID. This means I can ship new default groups in future versions without wiping user-added customs.

Last write wins.

### Firebase config

Project: `house-ledger-26622` (separate from meal planner project)
DB URL: `https://house-ledger-26622-default-rtdb.europe-west1.firebasedatabase.app/`
Rules: writes restricted to `/history` and `/customTasks` paths; reads/writes open without auth. Family-scale, not internet-public.

---

## Workflow

### Environment

- **Termux on Pixel**, with git authenticated to push to `bengalebg23/Chores`
- Repo at `~/Chores/`
- Shell aliases in `.bashrc`:

```bash
c() {                       # quick push, no tag
  cd ~/Chores && git add -A && git commit -m "${1:-update}" && git push
}

ct() {                      # tagged release push
  if [ -z "$1" ]; then echo "Usage: ct <version>"; return 1; fi
  cd ~/Chores && git add -A && git commit -m "v$1" && git tag "v$1" -m "v$1" && git push && git push --tags
}
```

### Patch style

Patches are **Python heredocs wrapped in bash**, applied to `~/Chores/index.html` in place. They `assert` against expected pre-state — failing loudly if the file isn't in the version they were authored for.

**NEVER deliver downloaded HTML files for Ben to `cp` into the repo.** That path has gone wrong multiple times (wrong files from cluttered Downloads, Pages cache confusion). Patches only.

All files delivered to Ben should be **version-stamped in the filename** — e.g. `v1.7_add_chore_modal.sh`, `HANDOFF_v1.7.md`. Ben's Downloads folder is a graveyard of unnamed files from many projects; ambiguous names get lost.

Standard delivery: I generate `vX.Y_description.sh`, Ben downloads, runs:

```bash
cp ~/storage/downloads/vX.Y_description.sh ~/Chores/patches/vX.Y_description.sh
cd ~/Chores
bash patches/vX.Y_description.sh
sed -i "s/const CACHE_VERSION = .*/const CACHE_VERSION = 'vX.Y';/" sw.js
ct X.Y
```

Pages takes 1–2 min to rebuild. Service worker auto-reloads clients once new SW takes control.

### Cache invalidation

Every patch **must** bump:
1. `VERSION` constant in `index.html` (e.g. `const VERSION = '1.8'`)
2. `VERSION_DATE` constant in `index.html`
3. `CACHE_VERSION` in `sw.js` (e.g. `'v1.8'`)

The SW change is what forces installed PWAs to reload. Skipping it means clients keep serving the old cached version.

---

## Version history

- **v1.0** — Initial release. Bed Change, Hoover, Dusting, Grooming, Misc groups. List + calendar views. localStorage only.
- **v1.1** — Bathrooms group added. Version stamp in footer.
- **v1.2** — Split into `index.html` + `sw.js`. Proper cache invalidation via `CACHE_VERSION`.
- **v1.3** — *Tag botched* (pushed wrong file). Skip.
- **v1.4** — Recovered. Added "merge defaults with saved tasks" loading logic so new groups appear for existing users.
- **v1.5** — Dark mode (manual toggle, designed palette).
- **v1.6** — Firebase Realtime Database sync for `/history`. localStorage stays as fast local buffer.
- **v1.7** — Version display moved up to masthead (was footer-only). Add-chore button + modal. Custom chores sync via Firebase `/customTasks`. Custom chores get a delete button.

---

## Known gotchas

### Pages cache lag (real, frequent)
GitHub Pages CDN cache is slower than git. After a push, `raw.githubusercontent.com` might show fresh content while `bengalebg23.github.io/Chores/` still serves stale. Use `?bust=randomstring` query strings on the live URL to verify, or push an empty commit:

```bash
git commit --allow-empty -m "trigger pages rebuild" && git push
```

### Downloads folder collisions (the original sin)
Ben's `~/storage/downloads/` accumulates many `index.html` files from different Claude projects. Old workflows used `cp ~/storage/downloads/index.html` which silently grabbed wrong files. **All Claude-delivered files now version-stamped.**

### Pages once served a totally different app
At one point the live URL served a dark-themed generic "Chore Tracker" instead of our House Ledger. Source: probably an old artifact-export from a different chat. Recovery: real-file push + `git commit --allow-empty`.

### Firebase rules are wide open
No auth. For real lockdown we'd need Firebase Auth setup — flagged for a future session.

### Default tasks vs custom tasks
DEFAULT_TASKS is hardcoded in the file. Custom tasks (added via Add chore button) get `custom: true` flag, ID prefix `custom-{timestamp}-{random}`, and live in Firebase `/customTasks`. Don't conflate them — defaults can change between versions; customs are user-owned.

### Data loss on Apr 25–May 9 (resolved)
The early localStorage-only versions lost data more than once. Cause: Chrome on Android evicts site storage under pressure for non-installed sites. v1.6 + Firebase makes this impossible to repeat. Pre-v1.6 entries are gone permanently.

---

## Design philosophy

- **Tactile paper aesthetic, not tech-dashboard.** Cream paper background with subtle ruled-line texture, Fraunces serif for display, JetBrains Mono for technical metadata. Warm sepia accents. Inspired by bullet journals and old library ledgers — see "No. 001 · Est. [year]" masthead framing.
- **Dark mode is warm too** — deep ink-brown, not black. Candlelight on dark wood, not VSCode.
- **Status colours stay vivid in both modes.** Stat cards (Overdue/Due/Fresh) deliberately keep saturated palette — they're meant to grab the eye.
- **Bullets in interface, never in chat output.** Ben dislikes report-style structured chat responses. Keep mobile-friendly: brief paragraphs, lead with the answer.
- **Honest mistakes get owned.** Ben values diagnostic transparency over recovery theatre. When something breaks, dig and explain, don't paper over.

---

## Open threads

1. **Multi-user attribution** — currently single-user. Add `loggedBy` field to each Firebase entry (Ben/Emily/Reuben/Vivien), with a first-load name prompt (cf. meal planner).
2. **Firebase Auth** — replace open rules with proper auth-based read/write rules.
3. **PWA install** — Ben wants this installed to home screen for protected-storage status. Install option hasn't been appearing reliably; might need engagement heuristic time or explicit "Add to home screen" via Chrome menu.
4. **Historical data import** — Ben has the original `Chores.pdf` with last-done dates for several tasks (mid-late April). Could be entered manually or batch-imported via a one-off Firebase write.

---

## To resume in a new chat

```
I'm continuing work on House Ledger, a household chores PWA.
Please fetch:
- https://raw.githubusercontent.com/bengalebg23/Chores/main/HANDOFF.md
- https://raw.githubusercontent.com/bengalebg23/Chores/main/index.html

Current version: v1.7
Workflow: patches via Python heredoc, applied in Termux, pushed via `ct X.Y` alias.
NEVER deliver downloaded HTML files — always patches.
All files version-stamped in filename.

[What I want to change today: ...]
```
