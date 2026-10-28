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
2. **Finish, don't farm.** Finishing a map early is rewarded (shop discount and an XP
   bottle), and a beaten enemy is routed so it stops feeding recruits, so sitting on the
   last enemy to farm XP has a real cost.
3. **Every run is different.** Heroes, shop stock, shrine buffs and the final boss are rolled
   from large pools, so no two campaigns play the same.
4. **Decisions over free power.** New items carry real downsides; buffs are rare and random.

## Core changes from WC2

### Enemy economy: income, not a lump sum

WC2 gives enemies a large starting gold pile and pre-places most of their army. WC3 gives
each enemy side the map file's gold (300; 350 on map 5) plus (100 + 25 × map) ×
`enemy_gold_multiplier` (0.5) × difficulty scale (0.8–1.5×) × a random 0.7–1.3, a base
income of max(10 × players, 10 × players × difficulty scale) per turn that grows by
`enemy_income_growth_pct` (15%) per map after the first, 5 gold per village (players get
2), and pre-captures 30% of villages (+10% per scenario, max 80%, never within 4 hexes of a
player). For 3 players on Normal (×1.2) that is 36 / 42 / 47 / 53 / 58 gold per turn on
maps 1–5: start gold stays modest, but income keeps pace with the players' between-map
gains (heroes, upgrades, XP bottles). The default AI
already contests villages and recruits from income, so territory matters without custom AI.

Enemy strength also scales by scenario:
- **Leaders** spawn at level 2 (S1), 3 (S2–3), 4 (S4) and 5 (S5), walking up their
  advancement tree.
- **Recruit lists** gain level-2 units from S2 and level-3 units from S4.
- **Assassins:** from S2, each enemy recruit has a 12% chance to become an assassin that
  hunts the nearest player leader (Micro AI `assassin`).
- **Personality:** each AI side rolls aggression, caution, village focus, leader
  aggression and recruitment habits from ranges, so enemies behave differently per map.
- **Rout** (`enemy_scaling.check_rout`): from turn 3, an enemy side down to its leader
  alone (no other units) with at most 1 village loses its gold and base income for the
  rest of the map. Without this, the income floor (10 × players per turn) buys the beaten
  leader one recruit a turn, which players farmed for XP instead of finishing. Checked on
  "side turn", which fires before income is paid. One-way, announced in chat.
- **Legendary leader** (`lua/wc2x/legendary.lua`): from S2, one random enemy leader per
  map loses WC2's heroic trait and gets the "legendary" trait instead (+25% HP, +25% damage
  on all attacks, +2 moves, laurel overlay) and affixes (1 in S2–3, 2 in S4–5), and
  killing it drops a random WC2 artifact (owned by the killer's side, so item carryover
  returns it if left on the ground). Picked on "start", after prestart's `[wc2_enemy]`
  made the leaders; a narrator line and an objectives note name it and its affixes. It gets
  no title of its own: LotI already gives every AI leader one when it is placed
  (`check_unit_title`), and stacking ours on top read as two titles.

  The legend is meant to step out and fight: its side's AI `leader_aggression` (rolled per
  side from -5 to 1) is raised to at least `config.legendary_leader_aggression` (1.0), and
  the +2 moves are a trait effect on top of the unit type's moves. WC2 creates enemy leaders
  with `max_moves = 0`, but with LotI that never sticks: LotI's `update_stats` recreates
  every unit from its type and modifications, so all enemy leaders actually have their
  type's moves, and only effects inside modifications survive.

  Affixes (`config.legendary_affixes`) are data only: each is a list of shrine buff names
  or inline effects, and parts the leader already has or can't use are skipped
  (`poi.buff_is_redundant`). Weighted toward making the leader hard to burst down:

  | Affix | Weight | Parts |
  |---|---|---|
  | Ironclad | 3 | steadfast, +20% all resistances |
  | Colossal | 3 | +50% HP |
  | Forcebound | 3 | forcefield, +10% all resistances |
  | Unyielding | 2 | melee first strike, +1 melee strike |
  | Bloodsworn | 1 | melee drain, regenerates |
  | Warlord | 1 | leadership, banner |
  | Shadowborn | 1 | darkness, corruption |
  | Venomous | 1 | melee poison, +2 melee damage |

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
| Mercenary Camp | None | Hire one of 3 off-faction units from the shared unit pool at half their normal cost (offers are rolled on the first visit and fixed for that camp, shared by all players); higher levels appear in later scenarios. Mercs are plain units (no heroic trait or buffs), which is their niche against invest, gacha and shop heroes: cheap reinforcements in the middle of a fight |
| Ancient Shrine | 1–4 themed guards, scaling by scenario | One random permanent buff from the buff pool for the capturing unit |
| Trade Caravan | None; the caravan (a Ruffian with 4 moves and +10 HP) is yours to move and can be killed | Move it onto any castle or keep hex: gold (40 + 15/scenario), an artifact (dropped next to your leader, castle first, like invest items) or training |

POI guards live on a dedicated neutral side (see *Neutral POI side*).

### Invest (scenario start)

Each player picks two of: +70 gold (plus a supply village), a hero from 5 random offers,
a training level, or an item. Hero offers come from the shared unit pool (below). An
invested item is placed like any other delivery (below), not on the hex under the leader.

### Leader deliveries

Everything handed to a player's leader goes through `lua/wc2x/placement.lua`, so it all
lands the same way: on a free castle hex if there is one, otherwise the nearest free hex
within 4 (never one with a unit or another item), with a deterministic order for MP.

- **Now:** `placement.artifact_to_leader` (invest items); a boxed-in leader gets the
  artifact directly. Heroes and reinforcements use `placement.unit_to_map`.
- **Next map:** `placement.queue_artifact` stores carried-over and shop artifacts in the
  side variable `wc2x_pending_artifacts`; `xp_bottle` stores `wc2x_pending_xp_bottle`. On
  `wc2_start`, after the castle upgrades, `placement.deliver_pending` places both for each
  player side, sharing one set of taken hexes. The variable names are unchanged
  from earlier versions, so saves taken between maps still deliver.

### Between-map sequence (after winning scenarios 1–4)

For each surviving player, in side order:

1. **Build a Hero (gacha).** A random hero from the unit pool with 2–3 random buffs.
   Cost 25 + 10 × map won (35 / 45 / 55 / 65g), cheap next to the rerolls so taking a
   mediocre roll is worth it. Rerolls: everything (15g), buffs only (10g), or a
   "bigger" roll with 4–5 buffs (35g). What you see is exactly what you get — the unit is
   shown at its real level. The dialog opens even if the player can't afford anything.
2. **Shop.** Skipped at 0 gold. Two random offers per consumable category plus all
   permanent upgrades.

Both apply the **early-finish discount**: `90 × t² // (t² + 12²)` %, t = turns left
(`config.shop_discount_ceiling`, `shop_discount_half_turns`). Squaring t makes it an
S-shaped (Hill) curve rather than the XP bottle's: a narrow win earns little (5% at 3 turns
left, 13% at 5), it climbs fastest around 12 turns left (36% at 10, 54% at 15) and flattens
toward 90% for very fast wins (66% at 20, 77% at 30, 82% at 40). It applies to
everything, including permanent upgrades — this is intentional: finishing fast is the
strongest lever in the mod, which is the anti-farming mechanism.

**XP bottle** (`lua/wc2x/xp_bottle.lua`). The discount is one-off gold while farmed XP
compounds across maps, so finishing also pays in XP: at victory, each player still in the
game is owed `M × t // (t + 15)` XP, t = turns left, where M is the ceiling for the map just
won (60 / 90 / 120 / 150 for maps 1–4, `config.xp_bottle_ceiling`): it climbs about M/15
per turn early, then flattens toward M, and later maps pay more because XP is worth less to
higher-level units. Whole-number maths, so every client gets the same amount; computed at
victory priority 10, before the map number advances. On the next map a
blue XP bottle (`images/items/wc3-xp-bottle.png`) labelled "+N XP" is placed next to their
leader with the other deliveries (see *Leader deliveries*); only the owner's units can drink it, and `unit:advance` then levels the unit with the engine's synced
advancement choice, as after a fight. An undrunk bottle is lost at the end of that map.

**Item pickup choices.** Stepping on a WC2 item opens a choice: pick it up, leave it, send it
next to your own leader (unless the unit is the leader), or send it to another player who still
has a leader, which places it on the nearest free hex to that
leader (castle wins ties) and makes them its owner for carryover. A unit that can't use the item
can still leave or send it. The "skip pickup confirmation" preference still picks items up
directly.

**Item carryover.** WC2 items still on the ground at victory (scenarios 1–4) are not lost:
each is sent to its owner and placed at their castle at the start of the next map, through the
same delivery as shop purchases (`lua/wc2x/item_carryover.lua`). The owner is set when the item
appears: the killer's player for death drops, the finder for bonus points, ruins and the caravan,
the buyer for invest and shop items. Items with no owner, or whose owner has been defeated, go to
the player whose leader is nearest. LotI items are not affected.

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

Invest, gacha, shop heroes, the mercenary camp and heroes found at WC2 bonus points all draw from one pool
(`lua/wc2x/unit_pool.lua`): every unit type that appears in any advancement tree (it
advances to something, or something advances to it). This deliberately includes units
players can't normally field, while excluding dead-end monsters, ships and props nobody
wants to invest in. Level range by scenario: S1 Lv1–2, S2 Lv2, S3 Lv2–3, S4 Lv3.

The pool is built from the unit types loaded on each machine, so it can differ between players.
Random picks therefore never run on every machine: `unit_pool.synced_sample` / `sync_ids` roll
on the acting player's machine (via `wesnoth.sync.evaluate_single`) and send the chosen type ids
to everyone. Inside a dialog that is already synced (the gacha) they just roll locally. The pool
is sorted by byte order, not with Lua's locale-dependent string `<`. On turn 1 every machine
compares a fingerprint of its pool (count + hash) with side 1's and posts a chat warning on a
mismatch, since a hero type missing on one machine would still break that player's game.

### Buff pool (shrines and gacha)

One weighted pool in `config.shrine_buffs` (77 entries, 70 of them rollable, total weight 96) feeds shrines,
gacha rolls and the final boss's escort buffs. New entries are appended only: gacha buffs
that aren't traits are stored on units by their index in this list.

- **Stat buffs** (common): HP (+8 to +32), melee/ranged damage (+1 to +4) and strikes,
  movement (+1 to +4), XP (+20%/+40%/+50%), +15% resistance per damage type, +10% or +20% all
  resistances, +5% or +10% defense on every terrain.
- **Traits** (weight 0 since 0.14.2, so never rolled): strong, quick, resilient, intelligent,
  healthy, fearless, loyal. Every unit already rolls its own traits, so they read as wasted
  bonuses. They stay in the list because indices are stored, and the debug panel and gacha pick
  still offer them. They use the mainline trait ids, so a unit that already has one is skipped.
- **Abilities** (rare): ambush, skirmisher, regenerates (+8, or +4 with the same id so a unit
  never gets both), leadership, teleport (own villages only), nightstalk, steadfast, cures,
  heals +4/+8; from mainline units outside the default era: concealment, burrow, diversion;
  from WC2's items and training: distract, tenacity, banner, forcefield, darkness (skipped on
  units that illuminate), corruption; and WC3-exclusive:
  - **Bulwark** — adjacent allies +10% all resistances.
  - **Sunder** — adjacent enemies −15% all resistances.
  - **Anchor** — +10% all resistances per adjacent enemy, up to +30% (cap 70%).
- **Weapon specials** (rare): backstab, poison, drain, marksman, berserk; from mainline:
  stun, absorb (×0.75 incoming), deflect (all attacks), arcane edge (all attacks); from WC2:
  fury (melee, berserk capped at 3 rounds), disengage (ranged, 1 move back after attacking);
  and WC3-exclusive:
  - **Supercharge** (melee) — ×4 damage both ways when attacking.
  - **Duelist** — +50% damage when nobody else is adjacent to either fighter.
  - **Pack Hunter** (melee) — +10% damage per other ally adjacent to the target, up to +30%.
  - **Flurry** (melee) — double strikes, half damage per strike.

The WC2 abilities reuse WC2's ids, so WC2's handlers in `ability_events.lua` (corruption,
disengage) and its aura halo effect work for them unchanged. Petrify is deliberately left
out: escorts draw from this pool, and it would remove player heroes for good.

`poi.buff_is_redundant` decides which buffs a unit would waste: a trait it already has, an
ability id it already has, a conflicting ability (`conflicts`), or an attack buff for a range
it has no attack in (a ranged buff on a melee-only unit). Shrines, boss escorts and gacha all
skip those. When several buffs are rolled at once (gacha, escorts), each pick is applied
before the next check, so one roll can't hold two buffs that cancel out (regenerates +8 and
+4). Gacha checks against an unplaced copy of the hero (`gacha.create_hero`): hero traits
don't depend on random rolls, so the copy matches the hero that is placed.

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
spawns at random (`lua/wc2x/boss_roster.lua`), with its own themed army in the arena and from
the map edges. Killing the boss ends the campaign in victory; the between-map sequence does
not run after scenario 5.

**Adaptive army** (`lua/wc2x/boss_scaling.lua`). Players arrive at scenario 5 with very
different strength, so the army is measured from them at the moment the boss spawns:

| Measure | From | Effect |
|---|---|---|
| Roster value | recruit cost of every player unit, map + recall list, all players | arena escort 13 + 1 per 300 gold above 1500 (max 18, the hexes in rings 1–2); edge units 10 + 1 per 150 gold above 1500 (max 20) |
| Key-unit score | each player's top 5 key units (heroic, carrying a WC2 or LotI item, level 2+, or the leader), pooled and averaged | shrine-pool buffs on every escort unit: 0 below 4, then +1 per 2 points (max 4); XP buffs and abilities the unit already has are skipped |
| Campaign kills | enemy units killed by player units, counted in `wc2x_campaign_kills` across all scenarios | boss max HP +5% per 50 kills (max +100%), quoted in a narrator line after the boss's intro; the revived Lich keeps it |

A unit's score is how far it sits above a fresh, trait-less unit of its own type, so it
doesn't matter whether a bonus came from traits, shrines, gacha or a LotI item: +1 per +20%
max HP, +1 per +25% best attack (damage × strikes), +1 per new named weapon special, attack
or ability (stealth abilities and unnamed hidden tiers don't count), +1 per +10% average
resistance, +0.5 per extra move. Measured on the playtest saves: about 3 for a party's
carries at scenario 3, 8–9 for a strong 2-player party late in scenario 4; roster value about
1600 at scenario 3 and 2900 late in scenario 4. Only key units count because plain recruits
all carry the same faction training, which said nothing about who is stronger. The numbers
used are stored in `wc2x_boss_scaling`; the debug panel shows them live.

**Design rule:** each boss has one signature mechanic and one phase change at 50% HP. The
default AI controls the boss and doesn't understand gimmicks, so every mechanic is either
passive or driven by our Lua — never something the AI must choose to do.

| | Lich Sovereign | Wyrm of the Last Age | The Usurper |
|---|---|---|---|
| Unit | Level 5, 120 HP, undeadfoot, chaotic | Level 5, 150 HP, drakefly, chaotic | Level 5, 102 HP, smallfoot, lawful |
| Attacks | soul rend 9-3 arcane, drains + plague (victims rise as Soulless); grave chill 10-4 cold, magical + slows; death knell 28-1 arcane, magical | devour 18-1 blade, supercharge (x4 both ways when attacking); tail sweep 14-2 impact, stun; inferno 11-4 fire, marksman + burning (6 fire damage for the target's next 2 turns, after healing; orange tint and status icon; can't kill; re-hit restarts the timer) | kingsblade 12-4 blade, first strike; executioner's stroke 16-2 blade, execute (x2 vs targets below half HP at the start of the fight); crossbow 10-3 pierce, marksman |
| Abilities | regenerates, skirmisher, chill of the grave (adjacent enemies deal 15% less damage) | regenerates | regenerates, skirmisher, steadfast, tyrant's command (adjacent allies of any level +25% damage) |
| Signature | **Phylacteries:** 3 immobile phylacteries spawn hidden in the fog, 10+ hexes from the arena and 5+ from player units. While any survives, the slain Lich rises at the arena keep with half HP and no actions left that turn | **Scorching aura:** player units adjacent to the Wyrm at the start of their turn take 8 fire damage after healing is applied, so villages and healers can't cancel it (resistance applies; can't kill) | **Royal shield:** 3 lieutenants (General, Arch Mage, Master Bowman) spawn 5–7 hexes from the arena; each living one gives the Usurper +25% resistance to everything |
| Phase at 50% HP | **Grave Tide:** 5 undead rise around the Lich | **Wrath:** +1 strike on all attacks, +2 moves | **The Crown's Guard:** 4 Royal Guards appear, and the AI is told to leave the keep and fight (`leader_ignores_keep`, `leader_aggression=1`) |
| Army (arena) | Draug, Banebow, Lich, Death Knight, Ghast | Drake Flameheart, Drake Enforcer, Drake Warden, Drake Blademaster | Royal Guard, Halberdier, Iron Mauler, Master Bowman, Silver Mage |
| Army (edges) | Spectre, Nightgaunt (fast, ignore terrain) | Hurricane Drake, Inferno Drake (fast, ignore terrain) | Cavalier, Grand Knight (normal movement) |

Every boss also gets the heroic trait and a random title. The boss unit types
(`units/wc3_bosses.cfg`) are standalone — no `[base_unit]` — so mainline rebalances can't
change them. Each has its own attack kit built only from stock specials, WC3 specials and
condition filters (no Lua). Signatures appear in the unit's
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

- **Retrain** (right-click menu): on a unit recruited this turn, re-roll its training for 50%
  of its recruit cost (`retrain_cost_pct`), as often as the player can pay. It replaces the
  recruit-and-dismiss loop players used to fish for good training; veterans can't be re-rolled.
- **Unit Finder** (right-click menu): lists traits and abilities across your units, then
  the units that have a chosen one; picking a unit scrolls to it and selects it.
- **Debug panel** (hidden): enabled from Wocopedia → Settings → "Enable detailed logging".
  Grants gold, XP, stats, any buff from the buff pool, upgrades; inspects and forces AI
  director tactics; toggles a per-side 100% shop/gacha discount and LotI free crafting. A per-side
  "Gacha Pick" toggle adds a Pick button to the gacha that sets the hero type (by level) and
  its bonuses from the full shrine pool, skipping the can-it-use-this check. Its "Final Boss" menu
  forces which boss spawns, skips straight to scenario 5 (wins the current scenario with
  `wc2_scenario` set to 4), and on scenario 5 kills every enemy leader to spawn the boss. It
  also shows the adaptive-army readout (roster value, key-unit score with the units behind it,
  kills and the resulting army) and can add 50 campaign kills for testing.
  All mutations go through `evaluate_single` so they are MP-safe.

## Technical notes

### Layout

| Path | Contents |
|---|---|
| `lua/wc2x/` | WC3 systems: `config`, `ai_director`, `enemy_scaling`, `poi`, `shop`, `upgrades`, `gacha_hero`, `unit_pool`, `placement`, `item_curses`, `burning`, `item_carryover`, `xp_bottle`, `legendary`, `retrain`, `migrations`, `final_boss`, `boss_roster`, `boss_scaling`, `unit_finder`, `debug_panel`, `dialog_utils` |
| `units/` | WC3 unit types (final bosses, phylactery) |
| `lua/campaign_main.lua` | Loads WC3 modules and LotI workarounds |
| `lua/campaign/`, `lua/game_mechanics/`, `lua/map/` | Forked WC2 code (scenario flow, invest, artifacts, map generation) |
| `resources/data/` | Artifacts, training, trait data |
| `era/factions/` | Faction definitions |
| `gui/` | Shop, gacha, merc and help dialogs |
| `tools/` | Dev scripts (not loaded by the game): `retag_saves.py` |

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
- Data that can differ per client never feeds synced randomness. The unit pool is built from
  each client's loaded unit types, so picks from it are rolled on the acting client and
  broadcast (`unit_pool.sync_ids`); a turn-1 fingerprint check warns players whose pool
  differs from side 1's. Before 0.10.1 each client rolled on its own pool and bonus-point
  heroes came out as different units per player.
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
| Uncollected items lost on victory | LotI only auto-picks items dropped on the final turn or on impassable terrain, then clears its item list | WC3 registers a victory handler at priority 10 so it runs before LotI's (priority 0, added earlier) and stores all remaining ground items: equipment into the shared item storage, gems into the shared gem counts, gold piles pooled and split evenly between players with a leader (before the gacha and shop run, so it is spendable there) | `campaign_main.lua` victory event |

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
- **Bloodprice on turn 1** costs 4 HP with no healing to offset it, because the engine
  skips start-of-turn healing on a side's first turn.
- **Attack preview** for adjacency-based specials (pack hunter, duelist, backstab) is
  computed before the attacker moves, so the preview numbers can differ from the real
  fight.

- **Deserter advancement prompt.** WC2's starting deserter hero is advanced by scenario
  (`wc2_heroes.place`); with LotI's extra advancement options the player may be asked to
  pick one. It is a unit they keep, so the choice is accepted. (The bonus-point trainer,
  which only appears briefly, is no longer advanced since 0.10.1.)

## Open items

- Deferred design: a story-driven unit mechanic.
- Boss art: custom sprites and portraits to replace the placeholders.
- Unconfirmed bug: an artifact from a WC2 bonus point (and the bonus point) reportedly
  disappeared after save and load. Not reproduced; no code path that clears items on load
  was found. Needs the scenario, turn and save to investigate.
