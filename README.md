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
- **Finish fast, pay less.** Every turn left on the clock is 3% off in the shop and gacha,
  up to 50%.
- **New buffs** you can only get in WC3: supercharge, bulwark, sunder, duelist, pack
  hunter, flurry and anchor.
- **Cursed items** with real downsides, like the Bloodprice Blade (drains 100% of damage,
  but it bleeds you every turn) or the Gambler's Die (every strike is a coin flip).
- **A final boss** on map five, rolled at random, with its own army.
- **Four new factions:** The Coil, Magnoshutadt, The Swarm and Monsters.
- **Unit Finder** (right-click): find which of your units has a given trait or ability.

Works alongside the LotI Era.

## Install

Install from the in-game add-on server (once published), or copy this folder into
`Documents/My Games/Wesnoth1.18/data/add-ons/`.

## For developers

Design, numbers and technical notes: [DESIGN.md](DESIGN.md). Release notes:
[CHANGELOG.md](CHANGELOG.md). Tuning values live in `lua/wc2x/config.lua`.
