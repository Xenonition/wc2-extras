# WC2 Extras — Design Document

A WC2 extension mod that addresses replayability issues with the base World Conquest II
campaign: the gold-dump-and-turtle loop, lack of territory contesting, and limited
inter-map investment options.

## Core changes from base WC2

### 1. Enemy economy: income-based, not lump-sum

Base WC2 gives enemies a large gold lump at map start and pre-places most of their army.
This mod gives enemies moderate starting gold (player start * 2) and lets them earn income
from villages like a normal MP side. The default Wesnoth AI already contests villages,
recruits from income, and retreats wounded units — changing the economic setup is enough
to make territory matter without writing custom AI.

Difficulty scaling: enemy starting gold and income rate scale with WC2 difficulty settings.

### 2. Points of interest

2-3 POIs per map, placed during map generation. Small number keeps them meaningful without
cluttering the map.

| POI type | Guards | Reward | Notes |
|---|---|---|---|
| Ruins | 1-2 weak undead | Random artifact or gold cache | Low-risk exploration |
| Mercenary camp | None (friendly) | Pay gold to recruit an off-faction unit | Spend now for tactical flexibility |
| Shrine | 2-3 themed units (moderate) | Permanent stat buff to capturing unit | Worth sending your best unit |
| Caravan | Escort mission (moves toward keep, enemies target it) | Large gold payout on arrival | Time-limited, forces attention split |
| Neutral creeps | Scattered weak units (wolves, bandits) | XP only | Fills dead space, no special hex needed |

POI guard strength scales with difficulty and scenario number.

Multiplayer scaling: POI count and rewards stay fixed regardless of player count. More
players means POIs are proportionally less pivotal — accepted tradeoff to avoid map clutter.

### 3. Between-map shop

Appears after winning a map, before proceeding to next scenario. Players spend leftover
gold plus an early-finish discount (the anti-farming mechanism — finishing faster gives
a shop discount).

**Consumables** (random subset each visit, from WC2's pool + our additions):
- Artifacts
- Training
- Heroes
- Gold

Random subset ensures different runs feel different. The total pool is large (base WC2 +
our additions), so showing a subset per visit creates roguelike variety.

**Permanent upgrades** (always available, escalating prices):

| Item | Effect |
|---|---|
| Castle hex | +1 starting castle hex next map |
| Supply village | Castle hex with village (heals + income from turn 1) |
| Unit discount | Reduce recruit cost of a chosen unit type by X gold, permanently |
| Recall discount | Reduce recall cost for all units permanently |
| Starting gold | +X base gold each map |
| Vision radius | +X fog reveal around keep at map start |
| Reinforcements | X free units from recruit list spawn outside castle turn 1 |
| Barracks | Special hex that auto-spawns a level 1 recruit every N turns |
| Training ground | Castle hex where units gain +4 XP per turn ending there |

Permanent upgrades are always available (not randomized) because:
- Players need to plan multi-map investment strategies
- Escalating prices already create variance between runs
- Only 9 items — too few for meaningful random subsets

Prices escalate with each purchase (e.g. 1st castle hex: 50g, 2nd: 80g, 3rd: 120g).
All prices scale with difficulty.

### 4. Map progression, era, factions

Same as base WC2. This mod extends WC2, not replaces it.

## Anti-farming

Single mechanism: early-finish shop discount. WC2 already has turn limits per scenario.
Finishing early gives a percentage discount in the shop, incentivizing efficient play
over gold farming. No reinforcement waves needed.

## Starting numbers

Enemy starting gold: player starting gold * 2. With income-based spending, enemies start
stronger but the player catches up through village control. All numbers are initial
estimates for playtesting.

## Technical approach

WC2 extension using `#ifdef LOAD_WC2` guard. Lives in `data/add-ons/`, does not modify
WC2's own files. Uses WC2's existing era, factions, artifacts, and training systems.
New mechanics implemented in Lua, shop as a custom GUI dialog (same tech as WC2's invest
screen).

## Known issues & mod interactions

### LotI Era compatibility

WC3 is designed to work alongside LotI Era as a lobby-toggled modification. Several LotI
behaviors assume a standard campaign side layout and break in WC3's co-op structure. WC3
applies runtime workarounds; none modify LotI's files.

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

### Multiplayer sync safety

WC3's Lua code is audited for OOS (out-of-sync) safety:

- **All random calls use `mathx.random`** (synced RNG), never `math.random`.
- **All `pairs()` iterations** that feed into random selection or state changes sort the
  result before use. (A `pairs()` OOS bug in mercenary level selection was found and fixed
  — the candidates array was unsorted, causing different clients to pick different tiers
  from the same roll.)
- **All dialogs** that affect game state (shop, mercenary camp, item pickup, debug panel)
  are wrapped in `wesnoth.sync.evaluate_single`.
- **No `os.time`/`os.clock`/`tostring(table)`** or other non-deterministic values in game logic.

### Neutral POI side

POI guards and creeps live on a dedicated side with:
- `team_name = "wc2_enemy"` — allied with enemies so AI doesn't waste turns attacking guards
- `ai_algorithm = "idle_ai"` — guards never move or initiate attacks; defense is automatic
- `wc2x_is_neutral = true` side variable — used to identify the neutral side in code
- Excluded from: AI director, village capture, enemy scaling, recruit events
