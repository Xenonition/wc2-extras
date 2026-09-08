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
