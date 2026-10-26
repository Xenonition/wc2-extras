# World Conquest III (repo `wc2-extras`)

Co-op Wesnoth 1.18 campaign forked from World Conquest II, played in multiplayer with LotI Era.
Read before working: [DESIGN.md](DESIGN.md) (systems, numbers, technical notes, known issues,
open items), [CHANGELOG.md](CHANGELOG.md) (what each release changed and why). Shared Wesnoth
paths and the dev loop: `../CLAUDE.md`. Open work: beads board, `bd list` filtered to `wc3`.

## Working rules

- **Edit in a sibling worktree, never on master**: `git worktree add -b <type>/<name> ../wc2-extras-<name> master`.
  The main checkout is symlinked into the game's add-ons folder, so master is what the game
  runs; in-game testing therefore needs a merge.
- **Don't merge or push until William says "merge and ship".** Then:
  1. Bump `version=` in `_server.pbl`: patch for fixes, minor for features.
  2. Turn the CHANGELOG's top section into `## X.Y.Z — <date>`.
  3. Merge to master (`--ff-only` when possible), run lint, `git push origin master`.
  4. Remove the worktree and branch.
  5. `python tools/retag_saves.py X.Y.Z` (backs up first, keeps save dates).
  6. Close the bead with the sha.
- Every change updates the docs it touches: DESIGN.md (how it works), CHANGELOG.md (player-
  facing), README.md (feature list) as relevant.
- Commit by path, never `git add -A`.

## Checks

- `luacheck lua` — compare the warning total with master (currently 65); new code adds none.
- `lint.bat` also runs lua-language-server; its stubs lack many Wesnoth APIs (4-argument
  `evaluate_single`, `synced_state`, `add_chat_message`…), so judge it as a diff against master.
- Verify every engine API, WML key and special against the 1.18 source or wiki before using
  it (`D:/SteamLibrary/steamapps/common/wesnoth/data/` for WML/macros, GitHub branch `1.18`
  for C++). Silent no-ops are common.
- No automated tests exist; say "not tested in game" until William has played it.

## Multiplayer rules (most past bugs were these)

- Random only via `mathx.random`/`mathx.shuffle`, in synced code.
- Anything built from client-local data (loaded unit types, `pairs()` order, locale-dependent
  string sorting) must not feed synced randomness. Roll on one machine and broadcast via
  `wesnoth.sync.evaluate_single` — use `wc2x.unit_pool.sync_ids` / `synced_sample` for unit picks.
- Dialogs that change state run inside `evaluate_single` with an AI fallback; results are flat
  tables of strings/numbers/booleans.
- Lua state is lost on load/rejoin: persist in WML variables and rebuild on `preload`.

## Data that saves depend on

- `config.shrine_buffs`, WC2 artifacts (`resources/data/artifacts.cfg`) and trainers are
  referenced **by index** from saved units: append only, never reorder or delete.
- Save repairs go in `lua/wc2x/migrations.lua` (runs on preload, must be idempotent).

## Debugging from saves

Saves are gzipped WML in `C:/Users/PC/Documents/My Games/Wesnoth1.18/saves/`. Useful parts:
`[replay]` (`[choose]` records dialog picks), `[statistics]`, side `[variables]`. Autosaves rotate,
so ask William for the scenario/turn early. LotI rebuilds human units on every placement
(`UPDATE_STATS`), which can advance them — suspect it when units change unexpectedly.
