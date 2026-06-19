# House Ledger — Handoff

A family household-chores PWA. Single-file `index.html` served from GitHub Pages, with localStorage + Firebase Realtime Database for persistence. Built around an existing paper-spreadsheet chore tracker (`Chores.pdf`) used by the Gale family at 17 Melody Drive, Sileby.

**Live app:** https://bengalebg23.github.io/Chores/
**Repo:** https://github.com/bengalebg23/Chores
**Current version:** v1.9 (2026-06-19)
**Branch:** `main` (no dev/staging split — push straight to live)

---

## Architecture

Single-file PWA. `index.html` contains everything:
- React 18.3.1 + Babel 7 standalone (compile-in-browser, no build step) — **CDN versions pinned, see Gotchas**
- Tailwind 3.4.17 via CDN
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

Tasks layering on load: `DEFAULT_TASKS` (hardcoded) + saved-local-custom (from localStorage) + Firebase customTasks, deduped by ID. This means new default groups can ship without wiping user-added customs.

Last write wins.

### Firebase config

Project: `house-ledger-26622` (separate from meal planner project)
DB URL: `https://house-ledger-26622-default-rtdb.europe-west1.firebasedatabase.app/`
Rules: reads/writes open for `/history` and `/customTasks`, no auth. Family-scale, not internet-public.

```json
{
  "rules": {
    "history":     { ".read": true, ".write": true },
    "customTasks": { ".read": true, ".write": true }
  }
}
```

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

**NEVER deliver downloaded HTML files for Ben to `cp` into the repo.** Patches only.

All files delivered to Ben must be **version-stamped in the filename** — e.g. `v1.9_pin_cdn_versions.sh`, `HANDOFF_v1.9.md`. Ben's Downloads folder has many files from many projects; ambiguous names get lost.

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
1. `VERSION` constant in `index.html`
2. `VERSION_DATE` constant in `index.html`
3. `CACHE_VERSION` in `sw.js`

The SW change is what forces installed PWAs to reload.

---

## Version history

- **v1.0** — Initial release. Bed Change, Hoover, Dusting, Grooming, Misc groups. List + calendar views. localStorage only.
- **v1.1** — Bathrooms group added. Version stamp in footer.
- **v1.2** — Split into `index.html` + `sw.js`. Proper cache invalidation via `CACHE_VERSION`.
- **v1.3** — *Tag botched* (pushed wrong file). Skip.
- **v1.4** — Recovered. Merge defaults with saved tasks so new groups appear for existing users.
- **v1.5** — Dark mode (manual toggle, designed palette).
- **v1.6** — Firebase Realtime Database sync for `/history`. localStorage stays as fast local buffer.
- **v1.7** — Version display moved to masthead. Add-chore button + modal. Custom chores sync via Firebase `/customTasks`. Delete button on custom chores.
- **v1.8** — **Emergency fix**. App blanked because `cdn.tailwindcss.com` and `unpkg.com/@babel/standalone` had been silently using `latest`; Babel released v8 with breaking changes and the unpinned import broke React mount. Pinned Tailwind to 3.4.17 and Babel to v7.
- **v1.9** — Pinned remaining CDN deps (React 18.3.1, ReactDOM 18.3.1; Firebase was already pinned).

---

## Known gotchas

### CDN pinning is mandatory (lesson from v1.8)
Single-file PWAs that load deps from CDN are exposed to **silent supply-chain breakage**. Any unpinned dep (`react@18`, `cdn.tailwindcss.com`, `@babel/standalone`) will eventually be redirected to a new major version with breaking changes, and the app dies overnight with no warning.

**Rule:** every CDN URL in the file must specify an exact version. If adding a new dep, pin it on day one. When bumping a pinned version, treat it like any other code change — patch + test + tag.

Check pin status with:
```bash
grep -E "unpkg.com|cdn\." ~/Chores/index.html
```

Every URL should have an `@version` or `/X.Y.Z` segment.

### Firebase rules expiry (lesson from v1.8 diagnosis)
"Test mode" rules auto-expire after 30 days. v1.8 also revealed that the original v1.6 rules had a buggy `$taskId` validator under `/history` that rejected valid array writes. Current rules (above, in Firebase config section) are correct.

If sync ever stops, check Rules tab first. Open dates are a 30-day timer that quietly kills writes.

### Pages cache lag (real, frequent)
GitHub Pages CDN cache lags git pushes. `raw.githubusercontent.com` might show fresh content while `bengalebg23.github.io/Chores/` serves stale. Use `?bust=randomstring` to force-fetch, or push an empty commit to nudge a rebuild:

```bash
git commit --allow-empty -m "trigger pages rebuild" && git push
```

### Downloads folder collisions (the original sin)
`~/storage/downloads/` accumulates many `index.html` files from different Claude projects. Old workflows used `cp ~/storage/downloads/index.html` which silently grabbed wrong files. **All Claude-delivered files now version-stamped.**

### Pages once served a totally different app
At one point the live URL served a generic dark-themed "Chore Tracker" instead of House Ledger. Source: probably an old artifact-export from a different chat. Recovery: real-file push + `git commit --allow-empty`.

### Default tasks vs custom tasks
DEFAULT_TASKS is hardcoded in the file. Custom tasks (added via Add chore button) get `custom: true` flag, ID prefix `custom-{timestamp}-{random}`, and live in Firebase `/customTasks`. Don't conflate them — defaults can change between versions; customs are user-owned.

### Data loss on Apr 25–May 9 (resolved by v1.6)
Early localStorage-only versions lost data more than once. Cause: Chrome on Android evicts site storage under pressure for non-installed sites. Firebase makes this impossible to repeat. Pre-v1.6 entries are gone permanently.

### Errors during React mount blank the screen
The Firebase init code runs synchronously in a `<script>` block before React. If it throws, React never mounts and the page renders blank (background only). Same applies to Babel parse errors and CDN failures. Worth adding a `try/catch` around the Firebase init in a future patch so a single CDN hiccup can't kill the whole app.

---

## Design philosophy

- **Tactile paper aesthetic, not tech-dashboard.** Cream paper background with subtle ruled-line texture, Fraunces serif for display, JetBrains Mono for technical metadata. Warm sepia accents.
- **Dark mode is warm too** — deep ink-brown, not black. Candlelight on dark wood, not VSCode.
- **Status colours stay vivid in both modes.** Stat cards (Overdue/Due/Fresh) deliberately keep saturated palette.
- **Bullets in interface, never in chat output.** Ben dislikes report-style structured chat responses. Mobile-friendly prose, lead with the answer.
- **Honest mistakes get owned.** Ben values diagnostic transparency over recovery theatre.

---

## Open threads

1. **Multi-user attribution** — currently single-user. Add `loggedBy` field to each Firebase entry (Ben/Emily/Reuben/Vivien), with a first-load name prompt (cf. meal planner).
2. **Firebase Auth** — replace open rules with proper auth-based read/write rules.
3. **PWA install** — Install option hasn't been appearing reliably on Ben's phone. Might need explicit "Add to home screen" via Chrome menu.
4. **Historical data import** — Ben has the original `Chores.pdf` with last-done dates for several tasks (mid-late April). Could be entered manually or via a one-off Firebase write.
5. **Error-boundary at React mount** — wrap Firebase init and the React root in try/catch so a single CDN issue doesn't blank the whole app. v1.8 exposed this gap.

---

## To resume in a new chat

```
I'm continuing work on House Ledger, a household chores PWA.
Please fetch:
- https://raw.githubusercontent.com/bengalebg23/Chores/main/HANDOFF.md
- https://raw.githubusercontent.com/bengalebg23/Chores/main/index.html

Current version: v1.9
Workflow: patches via Python heredoc, applied in Termux, pushed via `ct X.Y` alias.
NEVER deliver downloaded HTML files — always patches.
All files version-stamped in filename.
All CDN URLs must specify exact versions (no @latest, no floating majors).

[What I want to change today: ...]
```
