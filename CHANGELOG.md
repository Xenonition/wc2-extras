# Changelog

## Unreleased

- Final boss roster: the random boss is replaced by one of three hand-designed bosses, each
  with a signature mechanic, a phase change at half HP and a themed army — the Lich
  Sovereign (phylacteries), the Wyrm of the Last Age (scorching aura, Wrath) and the Usurper
  (lieutenants shield him; the Crown's Guard), with custom sprites.
- Each boss has a unique attack kit: the Lich's plague touch, slowing chill and death knell
  plus an aura that weakens adjacent enemies; the Wyrm's supercharged devour, stunning tail
  and burning breath (its own status: orange tint, 6 damage for 2 turns, not cured by villages); the Usurper's first-strike blade, execute stroke and a leadership aura
  that works on allies of any level.
- Objectives show the boss's status. Debug panel "Final Boss" menu: force which boss spawns,
  skip to the final scenario, or spawn the boss immediately.

## 0.3.1 — 2026-09-25

Fixes from the pre-release audit.

- The final boss arena is placed at the clearest site near the map centre instead of
  stamping over whatever was there (keeps and leaders are never covered), and units
  already in its footprint are moved out instead of being trapped behind the chasm.
- Shrines no longer roll a buff the unit already has.
- Fixed the final boss's escort army spawning on different hexes per client in
  multiplayer (unsorted hex list fed to a shuffle).
- Barracks, training grounds and pending reinforcements now survive save/load and MP
  rejoin (their locations were only kept in Lua memory).
- AI director tactics and Micro AI ids now survive save/load; previously a reload
  orphaned the running Micro AIs and could reuse their ids. The assassin unit-id counter
  is saved too.
- Ancient Ruins ambush: loot is now claimable only after the ambushers die (it was
  granted on the same step the guards spawned).
- Shop heroes now come from the shared unit pool at their real level (they were old
  faction heroes shown at level 1 and advanced after purchase).
- Items bought in the shop are dropped on the nearest free hex outside the castle when
  no castle hex is free (they were force-given to the leader, bypassing item restrictions).
- Gacha, invest and shop heroes are placed castle-first next to the leader, and go to
  the recall list instead of crashing when the leader is boxed in.
- Four-player games: when one leader has been defeated, the gacha and shop now run for
  the remaining players (the highest-numbered player was being skipped).
- AI-controlled sides (e.g. a disconnected player) no longer pop gacha, shop or
  mercenary dialogs on another client.
- Unit Finder now closes and selects the chosen unit (with its coordinates listed), so
  you can tell which unit in a group has the trait.
- Bloodprice Blade: per-turn HP loss reduced from 8 to 4.
- Debug panel: removed the old Traits/Abilities menus (they applied melee-only specials
  to every attack, and their backstab and teleport were broken); the buff-pool picker
  replaces them. The shop now opens at 0 gold when the free-shop toggle is on.

## 0.3.0 — 2026-09-23

- Final boss encounter on scenario 5: arena at the map centre, random boss advanced
  toward level 6, escort army and flyers; killing it wins the campaign.
- Four new player factions: The Coil, Magnoshutadt, The Swarm, Monsters.
- Build a Hero (gacha) after each victory; shared unit pool for invest, gacha, shop and
  mercenary camp, with hero level scaling by scenario.
- WC3-exclusive buffs: supercharge, bulwark, sunder, duelist, pack hunter, flurry, anchor;
  15 new stat/resistance/healing entries in the buff pool.
- Nine new items: Bloodprice Blade, Gambler's Die, Plague Banner, Hive Crown, Thunder
  Maul, Aegis of the Stubborn, Jester's Bells, Parrying Dagger, Marshal's Baton, with
  custom icons.
- AI director: castle defense and fighting retreat tactics, stochastic reassessment,
  bodyguard boost.
- Unit Finder right-click menu; debug panel (hidden) with buff picker and free-shop toggle.
- Fixes: leadership only boosting its bearer, steadfast doubling weaknesses, teleport
  reaching enemy villages, gacha dialog showing to the wrong player, hero advancement
  crash, unit finder crash, several LotI Era interaction bugs.

## 0.2.0 — 2026-09-11

- AI director with tactic engine (rally, turtle, grab, ambush, raid, bodyguard).
- Shrine buff table with weighted drops including rare abilities.
- POI guard scaling by scenario; ruins drop artifacts next to the unit.
- Trade Route (+3 income) replaces the starting-gold upgrade; unit and recall discount
  upgrades removed.
- Enemy gold multiplier reduced; fortification sprites and hex labels.

## 0.1.0 — 2026-09-08

- Standalone fork of World Conquest II with income-based enemy economy, points of
  interest, between-map shop and permanent upgrades.
