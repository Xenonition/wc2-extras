# World Conquest III — Design Document

World Conquest III (WC3) is a standalone fork of World Conquest II (WC2) for Battle for
Wesnoth 1.18. It keeps WC2's five-scenario co-op structure, random maps, era and
training, and adds systems aimed at WC2's replayability problems: the gold-dump-and-turtle
loop, no reason to contest territory, few ways to invest between maps, and an anticlimactic
ending.

Numbers below are the current values in `lua/wc2x/config.lua` unless noted; treat them as
playtest defaults, not final balance.

## Design pillars

1. **Territory matters.** Enemies earn income from villages like a normal MP side, so
   leaving the map to them makes the game harder.
2. **Finish, don't farm.** Finishing a map early is rewarded (shop discount), so sitting on
   the last enemy to farm XP has a real cost.
3. **Every run is different.** Heroes, shop stock, shrine buffs and the final boss are rolled
   from large pools, so no two campaigns play the same.
4. **Decisions over free power.** New items carry real downsides; buffs are rare and random.

## Core changes from WC2

### Enemy economy: income, not a lump sum

WC2 gives enemies a large starting gold pile and pre-places most of their army. WC3 gives
enemies moderate starting gold (`enemy_gold_multiplier` 0.5 of WC2's, ±30% per side,
scaled by difficulty 0.8–1.5×) and a minimum income of 10/turn, and pre-captures 30% of
villages (+10% per scenario, max 80%, never within 4 hexes of a player). The default AI
already contests villages and recruits from income, so territory matters without custom AI.

Enemy strength also scales by scenario:
- **Leaders** spawn at level 2 (S1), 3 (S2–3), 4 (S4) and 5 (S5), walking up their
  advancement tree.
- **Recruit lists** gain level-2 units from S2 and level-3 units from S4.
- **Assassins:** from S2, each enemy recruit has a 12% chance to become an assassin that
  hunts the nearest player leader (Micro AI `assassin`).
- **Personality:** each AI side rolls aggression, caution, village focus, leader
  aggression and recruitment habits from ranges, so enemies behave differently per map.

### AI director

Every AI side runs two tactic slots, reassessed stochastically (35% base chance per turn
once a tactic's minimum duration has passed, adjusted by the side's personality):

| Slot | Tactics |
|---|---|
| Strategic (army posture) | rally strike, village turtle, village grab, castle defense, fighting retreat |
| Opportunistic (small ops) | raid leader, forest ambush, leader bodyguard |

Tactics are implemented with Micro AIs and also tune recruitment saving (e.g. castle
defense spends everything). Slot state is mirrored into side variables so it survives
save/load — the Micro AIs themselves are saved with the side's AI config, so their owning
slots must be too, or a reload would leave orphaned Micro AIs running.

### Points of interest (POIs)

3 POIs per map, +1 every two scenarios, placed during map generation, plus 4 scattered
neutral creeps (wolves, bats, scorpions…) for XP.

| POI | Guards | Reward |
|---|---|---|
| Ancient Ruins | Ambush: undead rise when you first step on it | Gold (40–80 + 10–20 per scenario), 50% chance of an artifact. Loot is claimable only after the ambushers die |
| Mercenary Camp | None | Hire one of 3 off-faction units from the shared unit pool at 1.2× cost; higher levels appear in later scenarios |
| Ancient Shrine | 1–4 themed guards, scaling by scenario | One random permanent buff from the buff pool for the capturing unit |
| Trade Caravan | Escort mission | Escort the caravan unit to your castle: gold (40 + 15/scenario), an artifact or training |

POI guards live on a dedicated neutral side (see *Neutral POI side*).

### Invest (scenario start)

Each player picks two of: +70 gold (plus a supply village), a hero from 5 random offers,
a training level, or an item. Hero offers come from the shared unit pool (below).

### Between-map sequence (after winning scenarios 1–4)

For each surviving player, in side order:

1. **Build a Hero (gacha).** A random hero from the unit pool with 2–3 random buffs.
   Cost 50 + 12 × scenario gold. Rerolls: everything (15g), buffs only (10g), or a
   "bigger" roll with 4–5 buffs (35g). What you see is exactly what you get — the unit is
   shown at its real level. The dialog opens even if the player can't afford anything.
2. **Shop.** Skipped at 0 gold. Two random offers per consumable category plus all
   permanent upgrades.

Both apply the **early-finish discount**: 3% per turn left, max 50%. It applies to
everything, including permanent upgrades — this is intentional: finishing fast is the
strongest lever in the mod, which is the anti-farming mechanism.

**Shop consumables** (random each visit): artifacts (30 + 10/scenario), training
(40 + 8/scenario) and heroes from the unit pool (50 + 12/scenario). Artifacts bought here
are placed next to the leader at the start of the next map — on a free castle hex if there
is one, otherwise the nearest free hex outside the castle.

**Permanent upgrades** (always available; price ×1.6 per purchase):

| Upgrade | Base price | Effect |
|---|---|---|
| Castle Hex | 50 | +1 castle hex next to your keep each map |
| Supply Village | 80 | Castle hex with a village (healing, income, recruit slot) |
| Trade Route | 30 | +3 base income per turn |
| Scout Network | 35 | +3 hex fog reveal around your leader at map start |
| Reinforcements | 70 | +1 free random recruit next to your leader on turn 1 |
| Barracks | 120 | Castle hex that spawns a free recruit every 4 turns |
| Training Ground | 90 | Castle hex; non-leaders ending a turn there gain 4 XP |

Upgrades are always shown (not randomized) so players can plan multi-map strategies.
Fortification locations are mirrored into side variables so they survive save/load.

### Shared unit pool

Invest, gacha, shop heroes and the mercenary camp all draw from one pool
(`lua/wc2x/unit_pool.lua`): every unit type that appears in any advancement tree (it
advances to something, or something advances to it). This deliberately includes units
players can't normally field, while excluding dead-end monsters, ships and props nobody
wants to invest in. Level range by scenario: S1 Lv1–2, S2 Lv2, S3 Lv2–3, S4 Lv3.

### Buff pool (shrines and gacha)

One weighted pool in `config.shrine_buffs` (41 entries, total weight 67) feeds both
shrines and gacha rolls:

- **Stat buffs** (common): HP, melee/ranged damage and strikes, movement, XP, +15%
  resistance per damage type.
- **Abilities** (rare): ambush, skirmisher, regenerates, leadership, teleport (own
  villages only), nightstalk, steadfast, cures, heals +4/+8, and WC3-exclusive:
  - **Bulwark** — adjacent allies +10% all resistances.
  - **Sunder** — adjacent enemies −15% all resistances.
  - **Anchor** — +10% all resistances per adjacent enemy, up to +30% (cap 70%).
- **Weapon specials** (rare): backstab, poison, drain, marksman, berserk, and
  WC3-exclusive:
  - **Supercharge** (melee) — ×4 damage both ways when attacking.
  - **Duelist** — +50% damage when nobody else is adjacent to either fighter.
  - **Pack Hunter** (melee) — +10% damage per other ally adjacent to the target, up to +30%.
  - **Flurry** (melee) — double strikes, half damage per strike.

Scaling buffs use one named `[dummy]` tag for the tooltip plus unnamed, mutually exclusive
tiers (the same pattern mainline uses for diversion and feeding).

**Stacking rules** (engine, `src/units/abilities.cpp`): specials of the same kind with the
same id take the best value; different ids multiply (`multiply`) or add (`add`/`sub`); fixed
`value`s (drain %, magical 70%) take the highest. So supercharge + charge is ×8 — accepted
as a rare jackpot combo.

### WC3 items

Nine items are appended after the WC2 artifact list in `resources/data/artifacts.cfg`
(saves reference artifacts by index, so new items always go at the end). Items can't be
removed once picked up, so the downside is the decision of *who* carries it.

| Item | Upside | Downside |
|---|---|---|
| Bloodprice Blade | Melee drains 100% of damage | Bearer loses 4 HP at the start of each of its turns (can't kill) |
| Gambler's Die | All attacks: fixed 50% to hit, +50% damage | Every strike is a coin flip |
| Plague Banner | Adjacent enemies −15% resistances | Adjacent allies −10% resistances |
| Hive Crown | Melee +2 strikes | Melee gains swarm (strikes shrink with HP) |
| Thunder Maul | Melee stun | Bearer has no zone of control |
| Aegis of the Stubborn | Melee absorb (×0.75 incoming) and deflect | −2 moves |
| Jester's Bells | Diversion | −20% all resistances |
| Parrying Dagger | Melee parry: −20% enemy chance to hit when defending | None |
| Marshal's Baton | Adjacent allies +15% chance to hit | Bearer deals half damage |

Bloodprice's per-turn loss is the only item effect that needs Lua (`item_curses.lua`),
since item effects can't express recurring damage. Icons are in `images/items/wc3-*.png`
(72×72); source art lives outside the repo.

### Final boss (scenario 5)

**Arena.** At prestart an arena (a keep, two rings of castle and an impassable chasm ring) is
stamped at the best site within 6 hexes of the map centre: its footprint may not cover a keep
or a leader, and sites covering villages, items, units or water score worse. Units already in
the footprint are moved to the nearest free hex outside it. POIs and creeps are placed
afterwards and keep 6 hexes from any keep, so they never land inside.

**Trigger.** When every regular enemy leader is dead, the chasm opens and one of three bosses
spawns at random (`lua/wc2x/boss_roster.lua`), with its own themed army: 13 units in the arena
and 10 from the map edges. Killing the boss ends the campaign in victory; the between-map
sequence does not run after scenario 5. The boss does not scale with player count — gold is
split between players, so total player strength is roughly constant.

**Design rule:** each boss has one signature mechanic and one phase change at 50% HP. The
default AI controls the boss and doesn't understand gimmicks, so every mechanic is either
passive or driven by our Lua — never something the AI must choose to do.

| | Lich Sovereign | Wyrm of the Last Age | The Usurper |
|---|---|---|---|
| Unit | Level 5, 120 HP, undeadfoot, chaotic | Level 5, 150 HP, drakefly, chaotic | Level 5, 102 HP, smallfoot, lawful |
| Attacks | touch 8-4 arcane drains; chill tempest 13-5 cold magical; shadow wave 9-5 arcane magical | bite 21-2 blade; tail 24-1 impact; fire breath 14-4 fire marksman | sword 10-4 blade; crossbow 8-3 pierce |
| Abilities | regenerates, skirmisher | regenerates | regenerates, skirmisher, leadership, steadfast |
| Signature | **Phylacteries:** 3 immobile phylacteries spawn hidden in the fog, 10+ hexes from the arena and 5+ from player units. While any survives, the slain Lich rises at the arena keep with half HP and no actions left that turn | **Scorching aura:** player units adjacent to the Wyrm at the start of their turn take 8 fire damage after healing is applied, so villages and healers can't cancel it (resistance applies; can't kill) | **Royal shield:** 3 lieutenants (General, Arch Mage, Master Bowman) spawn 5–7 hexes from the arena; each living one gives the Usurper +25% resistance to everything |
| Phase at 50% HP | **Grave Tide:** 5 undead rise around the Lich | **Wrath:** +1 strike on all attacks, +2 moves | **The Crown's Guard:** 4 Royal Guards appear, and the AI is told to leave the keep and fight (`leader_ignores_keep`, `leader_aggression=1`) |
| Army (arena) | Draug, Banebow, Lich, Death Knight, Ghast | Drake Flameheart, Drake Enforcer, Drake Warden, Drake Blademaster | Royal Guard, Halberdier, Iron Mauler, Master Bowman, Silver Mage |
| Army (edges) | Spectre, Nightgaunt (fast, ignore terrain) | Hurricane Drake, Inferno Drake (fast, ignore terrain) | Cavalier, Grand Knight (normal movement) |

Every boss also gets the heroic trait and a random title. The boss unit types
(`units/wc3_bosses.cfg`) are standalone — no `[base_unit]` — so mainline rebalances can't
change them; mainline numbers were used only as a reference. Signatures appear in the unit's
help as `[dummy]` abilities. The objectives screen shows the boss's status (phylacteries
remaining, lieutenants alive, enraged).

State lives in WML variables (`wc2x_boss_kind`, `wc2x_boss_id`, `wc2x_boss_phase_done`) and
on the map (phylactery units, lieutenants tagged with a `wc3_lieutenant` unit variable), so
save/load needs no extra restore logic. The debug panel can force which boss spawns.

Art: `images/units/wc3-bosses/` (unit sprites and the phylactery) and
`images/portraits/wc3-bosses/` (portraits) currently hold mainline placeholders; replacing
the files swaps the art without code changes.

### Factions

WC2's era plus four WC3 factions built from base-game units: **The Coil**
(naga/saurian/merfolk), **Magnoshutadt** (mage academy with elite summons), **The Swarm**
(insects with purchasable level-3 queens) and **Monsters** (beasts).

### Player tools

- **Unit Finder** (right-click menu): lists traits and abilities across your units, then
  the units that have a chosen one; picking a unit scrolls to it and selects it.
- **Debug panel** (hidden): enabled from Wocopedia → Settings → "Enable detailed logging".
  Grants gold, XP, stats, any buff from the buff pool, upgrades; inspects and forces AI
  director tactics; toggles a per-side 100% shop/gacha discount and LotI free crafting; forces which final boss
  spawns.
  All mutations go through `evaluate_single` so they are MP-safe.

## Technical notes

### Layout

| Path | Contents |
|---|---|
| `lua/wc2x/` | WC3 systems: `config`, `ai_director`, `enemy_scaling`, `poi`, `shop`, `upgrades`, `gacha_hero`, `unit_pool`, `placement`, `item_curses`, `final_boss`, `boss_roster`, `unit_finder`, `debug_panel`, `dialog_utils` |
| `units/` | WC3 unit types (final bosses, phylactery) |
| `lua/campaign_main.lua` | Loads WC3 modules and LotI workarounds |
| `lua/campaign/`, `lua/game_mechanics/`, `lua/map/` | Forked WC2 code (scenario flow, invest, artifacts, map generation) |
| `resources/data/` | Artifacts, training, trait data |
| `era/factions/` | Faction definitions |
| `gui/` | Shop, gacha, merc and help dialogs |

`lua/wc2x/placement.lua` is the one place that decides where things appear next to a
leader (castle hexes first, then nearest free hex, deterministic order); items, gacha
heroes and shop heroes use it, and heroes fall back to the recall list if boxed in.

### Save/load and MP rejoin

Lua module state is lost on load and on MP rejoin (fresh Lua state). Anything that
changes behaviour later must live in WML variables and be rebuilt on `preload`:
fortification locations and pending reinforcements (`upgrades.lua`), AI director slots
and the Micro AI id counter (`ai_director.lua`), the assassin id counter
(`enemy_scaling.lua`) and boss state (`final_boss.lua`).

### Multiplayer sync safety

- All random calls use `mathx.random`, never `math.random`.
- Every `pairs()` loop whose order feeds randomness or state is sorted first (Lua's hash
  order differs between clients). Two such bugs were found and fixed: mercenary level
  selection and the boss army's spawn hexes.
- Every dialog that changes game state (gacha, shop, mercenary camp, debug panel) runs in
  `wesnoth.sync.evaluate_single` with the acting side, and gacha/shop/merc pass an AI
  fallback that declines, so an AI-controlled (e.g. disconnected) side never pops a
  dialog on another client.
- Return values from `evaluate_single` are flat tables of strings/numbers/booleans.
- No `os.time`, `os.clock`, `tostring(table)` or other client-local values in game logic.

### Neutral POI side

POI guards and creeps live on a dedicated side with:
- `team_name = "wc2_enemy"` — allied with enemies so the AI doesn't waste turns on guards
- `ai_algorithm = "idle_ai"` — guards never move or attack; defence is automatic
- `wc2x_is_neutral = true` side variable — identifies the side in code
- Excluded from the AI director, village capture, enemy scaling and recruit events

## Known issues & mod interactions

### LotI Era compatibility

WC3 works alongside LotI Era as a lobby-toggled modification. Several LotI behaviours
assume a standard campaign side layout and break in WC3's co-op structure. WC3 applies
runtime workarounds; none modify LotI's files.

| Issue | Root cause | WC3 workaround | File |
|---|---|---|---|
| `controller=` SSF warnings (~1700/session) | LotI uses `controller=human` in `[filter_side]` blocks; Wesnoth 1.18 ignores this in SSFs and logs a warning each time | Cannot fix without patching LotI. Harmless log noise — the filter is ignored identically on all clients | LotI `global_events.cfg` lines 121, 152, 485, 538, 552, 1724; `utils.cfg` line 70 |
| Player recruits get elite mods (reflect, temptation) | LotI's `DROPS` macro hardcodes `$enemy_sides` to `1,2,...,12`, including the player side | WC3 overwrites `$enemy_sides` at prestart to only include non-human, non-neutral AI sides | `campaign_main.lua` prestart event |
| Item pickup dialog fires for AI units | LotI's `item_pick` event uses `controller=human` filter (ignored by engine), so `[item_pick_menu]` fires for all sides | WC3 wraps `wesnoth.wml_actions.item_pick_menu` to skip non-human sides | `campaign_main.lua` item_pick_menu wrapper |
| Player can't pick up items from own fallen units | `DROPS` die event includes player side; `on_the_ground.add` sets `dropping_side` = player, and the pickup filter excludes that side | WC3 wraps `loti.item.on_the_ground.add` to clear `dropping_side` when it's a human side | `campaign_main.lua` on_the_ground.add wrapper |
| Uncollected items lost on victory | LotI only auto-picks items dropped on the final turn or on impassable terrain; everything else is cleared | WC3 registers a victory event that stores all remaining ground items (gems, gold, equipment) before LotI's handler runs | `campaign_main.lua` victory event |

### Base World Conquest coexistence

When both WC3 and the original World Conquest add-on are installed, several WML macros
are defined by both. WC3 adds `#undef` before each redefinition to suppress preprocessor
warnings: `ICON_THREE`, `ICON_FOUR`, `IMAGE_ONE`, `WC2_CAMPAIGN_NEW`, `WC2_SCENARIO_NEW`,
`WC_II_PAIR` (in `_main.cfg` and `scenarios/WC_II_scenario.cfg`), and
`WCT_CHANCE_ARCANE_BOOST` (in `resources/data/training.cfg`).

### Accepted quirks

- **Four-player defeat.** In 4-player games one leader may die without ending the
  scenario (inherited from WC2). That player skips the gacha and shop.
- **Shop and ruins can drop player-restricted WC2 items** (Root of the Elder Wose,
  Stormbringer, Sylph Bow). Invest respects the restriction; this is accepted.
- **Duplicate buff rolls.** Shrines skip buffs the unit already has (same trait, or an
  ability id it already has). The gacha can still roll an ability the hero's unit type has
  natively; the engine then drops the duplicate.
- **Bloodprice on turn 1** costs 4 HP with no healing to offset it, because the engine
  skips start-of-turn healing on a side's first turn.
- **Attack preview** for adjacency-based specials (pack hunter, duelist, backstab) is
  computed before the attacker moves, so the preview numbers can differ from the real
  fight.

## Open items

- Deferred design: a story-driven unit mechanic.
- Boss art: custom sprites and portraits to replace the placeholders.
