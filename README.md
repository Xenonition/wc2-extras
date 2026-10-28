# World Conquest III

A co-op campaign for **Battle for Wesnoth 1.18**: a standalone fork of World Conquest II
with a living enemy economy, points of interest, a between-map shop and gacha, new items
and buffs, and a final boss. 1–4 players, five random maps.

## What's different from World Conquest II

- **Enemies earn income.** They start with less gold but take villages and recruit every
  turn, and each AI rolls its own personality and switches tactics mid-map (rushes,
  turtling, raids on your leader, forest ambushes, assassins).
- **Points of interest** on every map: ruins with an undead ambush and treasure, shrines
  that grant a unit a permanent random buff, mercenary camps with off-faction units, and
  merchant caravans to escort.
- **After each victory:** Build a Hero — roll a random hero with 2–3 random buffs and
  reroll it for gold — then a shop with artifacts, training, heroes and permanent upgrades
  (extra castle hexes, supply villages, income, barracks, training grounds…).
- **Finish fast, pay less.** Every turn left on the clock cuts shop and gacha prices: 30%
  off with 5 turns left, 45% with 10, 60% with 20, still growing for very fast wins, plus an XP bottle waiting by your leader on the next map that grows with the
  turns left and with each map won. A beaten enemy reduced to its leader is routed and
  stops recruiting, so there's nothing left to farm.
- **Legendary leaders:** from map two, one enemy leader per map is a legend with
  extra HP and damage, plus affixes like Ironclad, Colossal or Forcebound. Unlike other
  leaders it leaves its keep to fight. Kill it for an artifact.
- **New buffs** you can only get in WC3: supercharge, bulwark, sunder, duelist, pack
  hunter, flurry and anchor.
- **77 shrine buffs**, from stats and traits to rare abilities you rarely see otherwise:
  mainline’s stun, burrow and diversion, and WC2 item powers like banner, corruption and fury.
- **Cursed items** with real downsides, like the Bloodprice Blade (drains 100% of damage,
  but it bleeds you every turn) or the Gambler's Die (every strike is a coin flip).
- **A final boss** on map five: one of three — a Lich you must hunt phylacteries to kill, a
  dragon whose aura burns everyone beside it, or a Usurper shielded by his lieutenants. Its
  army grows with your roster, its escorts get shrine buffs to match your best units, and
  every enemy you kill along the way makes it tougher.
- **Four new factions:** The Coil, Magnoshutadt, The Swarm and Monsters.
- **Unit Finder** (right-click): find which of your units has a given trait or ability.

Works alongside the LotI Era.

## Install

Install from the in-game add-on server (once published), or copy this folder into
`Documents/My Games/Wesnoth1.18/data/add-ons/`.

In multiplayer every player needs the same WC3 and LotI versions. On turn 1 of each map, WC3
posts a chat warning to any player whose unit list differs from Player 1's.

## For developers

Design, numbers and technical notes: [DESIGN.md](DESIGN.md). Release notes:
[CHANGELOG.md](CHANGELOG.md). Tuning values live in `lua/wc2x/config.lua`.
Working conventions (worktrees, release steps, multiplayer-safety rules, lint):
[CLAUDE.md](CLAUDE.md). `tools/retag_saves.py` updates local saves to a new release.
