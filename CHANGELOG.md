# Changelog

## 0.14.3 — 2026-10-30

- A legendary leader's affixes are now traits shown beside "legendary" in the unit's traits
  (e.g. "legendary, ironclad, venomous"), with what each one gives in its tooltip. Since
  0.14.0 dropped the affix titles from the leader's name, they were only named in the
  narrator line and objectives. Ability parts no longer show as separate traits
  ("steadfast"): they are part of the affix.

## 0.14.2 — 2026-10-29

- The seven mainline trait bonuses (strong, quick, resilient, intelligent, healthy, fearless,
  loyal) no longer roll from shrines, the gacha or boss escorts: units already have their own
  traits. They are set to weight 0 rather than removed, so existing gacha heroes keep theirs.
- Debug: a per-side "Gacha Pick Hero/Bonuses" toggle in the debug menu (saved like the 100%
  discount). With it on, the gacha has a Pick button to choose the hero type and any bonuses
  from the shrine pool, including ones the unit couldn't normally roll.
- Enemy base income grows 15% per map after the first (`config.enemy_income_growth_pct`):
  for 3 players on Normal it is 36 / 42 / 47 / 53 / 58 gold per turn on maps 1–5, where it
  used to stay at 36. Start gold is unchanged.
- Fixed legendary leaders' +2 moves not applying (a Dwarvish Sentinel legend had 4 moves):
  LotI rebuilds units from their type and modifications, which threw away the directly set
  moves. The bonus is now part of the legendary trait, so it adds 2 to the type's moves.

## 0.14.1 — 2026-10-28

- Early-finish discount is an S-curve, 90 × t² ÷ (t² + 144) % for t turns left: 5% at 3
  turns left, 13% at 5, 36% at 10, 54% at 15, 66% at 20, 77% at 30, approaching 90%. It was
  3% per turn left, capped at 50%, so narrow wins now earn a little less and fast wins much more.

## 0.14.0 — 2026-10-28

- Gacha heroes are cheaper: 25 + 10 gold per map won (35 / 45 / 55 / 65), was 50 + 12
  (62 / 74 / 86 / 98). Rerolls are unchanged, so buying a decent roll beats rerolling.
- Trade caravan artifacts are dropped next to your leader (free castle hex first) instead of
  being equipped on the leader, so you choose who carries them.
- Legendary leaders lose the heroic trait, get 2 moves (other enemy leaders have none), and
  their side's AI sends the leader out to fight more readily (leader aggression at least 1.0).
- Legendary leaders no longer add "the Ironclad" etc. to their name, which stacked with
  LotI's leader title ("Alajaih the Ironclad the Enlightened Annihilator"). The affix names
  are listed in the announcement and objectives instead.

## 0.13.1 — 2026-10-27

- XP bottle rebalanced (was 8 XP per turn left, max 120): XP = M × turns left ÷ (turns left
  + 15), so it flattens out instead of hitting a cap, and the ceiling M grows with the map
  won: 60 / 90 / 120 / 150. Winning map 2 with 14 turns left gives 43 XP.
- Invested items are placed like other deliveries (free castle hex first) instead of always
  on the hex below the leader, which could be off the map, impassable or already taken.
- Code: invest, shop, item carryover and XP bottle deliveries share one placement path
  (`placement.lua`).

## 0.13.0 — 2026-10-27

- **Rout:** from turn 3, an enemy side down to its leader alone with at most one village
  loses its gold and income for the rest of the map, so it stops recruiting units to farm.
- **XP bottle:** finishing early leaves a bottle by your leader on the next map, worth 8 XP
  per turn left (max 120). Only your units can drink it; it is lost if not drunk that map.
- **Legendary leaders:** from scenario 2, one enemy leader per map gets the legendary trait
  (+25% HP, +25% damage on all attacks, a laurel),
  a title and 1–2 affixes (Ironclad, Colossal, Forcebound, Unyielding, Bloodsworn, Warlord,
  Shadowborn, Venomous). Killing it drops an artifact.

## 0.12.0 — 2026-10-27

- Seven more filler buffs in the shrine pool (77 total): +4 melee or ranged damage, +32 HP,
  +4 movement, +50% XP bonus, +20% all resistances, +10% defense everywhere.

## 0.11.0 — 2026-10-26

- Shrine buff pool grows from 41 to 70 buffs (shared with gacha and the boss escorts):
  - Filler: +3 melee or ranged damage, +24 HP, +10% all resistances, +5% defense everywhere,
    +40% XP bonus.
  - Traits: strong, quick, resilient, intelligent, healthy, fearless, loyal.
  - Mainline abilities few units have: stun, absorb, deflect, arcane edge, concealment, burrow,
    diversion, regenerates +4.
  - WC2's item and training abilities: distract, tenacity, banner, forcefield, darkness,
    corruption, fury, disengage.
- Shrines, Build a Hero and boss escorts no longer waste a buff on a unit that can't use it: a
  ranged buff on a unit with no ranged attack (or melee on no melee), a trait or ability the
  unit already has, or darkness on a unit that illuminates. A single gacha or escort roll also
  can't contain two buffs that overlap, like regenerates +8 and +4.

## 0.10.1 — 2026-10-25

- Fixed heroes from bonus points (and mercenary camp offers) coming out as different units on
  each player's screen. Each machine rolled on its own copy of the unit pool, and those copies
  can differ. The acting player's machine now rolls and sends the result to everyone; invest
  and shop hero offers use the same path. The pool is also sorted independently of the
  player's language setting.
- New: on turn 1 of each map, a chat warning tells any player whose unit list differs from
  Player 1's (usually a different LotI or WC3 version).
- Fixed a bonus point's training reward asking you to pick an advancement for the trainer (e.g.
  Master at Arms -> Champion/Shadowalker) on scenario 4 and later. The trainer is only shown while
  it speaks and is then removed; WC2 advanced it to look senior, and LotI's extra advancement
  options turned that into a choice. The trainer now appears at its base type.

## 0.10.0 — 2026-10-05

- Adaptive final boss army: the escort's size follows the total value of the players'
  units (arena 13–18, edges 10–20), escort units get 0–4 shrine buffs to match the players'
  best units (heroes, item carriers, level 2+ and leaders, compared against their own unit
  type), and the boss gets +5% HP per 50 enemies the players killed this campaign (up to
  +100%). Kills are counted from this version on.
- LotI gold left on the ground at victory is now split evenly between all players with a leader,
  instead of all of it going to whoever's turn it was. It is collected before the gacha and shop, so it
  can be spent there.
- Heroes found at WC2 bonus points now come from the shared unit pool (like invest, the gacha,
  shop heroes and mercenary camps), at the scenario's level, instead of WC2's faction hero lists
  advanced after spawning.
- Debug panel, unit Progression menu: change the XP a unit needs to level (-25%, -50%, +25%,
  stackable) or reset those debug modifiers.
- Debug panel "Final Boss" menu: shows the adaptive-army readout and can add campaign kills.

## 0.9.1 — 2026-10-04

- Fixed Retrain being offered on recalled units: the "recruited this turn" mark only stored the
  turn number and carried over between maps, so a unit recruited on turn N of an earlier map
  qualified again when recalled on turn N. The mark now includes the scenario and is cleared on
  recall.
- Fixed points of interest (e.g. a mercenary camp) and creeps spawning on the same hex as a WC2
  bonus point or an existing unit.

## 0.9.0 — 2026-10-04

- Item pickup menu: new "Send to my leader" option, which places the item next to your own
  leader (not shown when the unit on the item is the leader).
- Fixed LotI items and gems left on the ground being lost at victory. WC3's collector ran after
  LotI's own victory handler, which had already cleared its item list; it now runs first.

## 0.8.0 — 2026-10-03

- Stepping on a WC2 item now offers: pick up, leave it, or send it to another player. A sent
  item appears next to that player's leader. Units that can't use an item can still send it on.
- Mercenary camp offers are rolled on the first visit and stay fixed for that camp for the rest
  of the scenario, shared by all players; walking in and out no longer re-rolls them.

## 0.7.0 — 2026-10-02

- WC2 items left on the ground at the end of a scenario are no longer lost: they are delivered
  to their owner's castle at the start of the next map (the killer for drops, the finder for
  loot, the buyer for invest/shop items; otherwise the nearest player).

## 0.6.2 — 2026-10-02

- Trade caravan pays out on any castle or keep hex; it no longer needs your leader within 3
  hexes. Artifact rewards still go to your leader, or drop on the hex if you have none.

## 0.6.1 — 2026-09-30

- Fixed the shrine/gacha "Melee: Backstab" buff never triggering: it checked a direction
  ("opposite") that Wesnoth does not recognise. It now uses the same check as mainline backstab,
  and units that already have the broken buff are repaired when a save loads.

## 0.6.0 — 2026-09-29

- Retrain: right-click a unit recruited this turn to re-roll its training for 50% of its
  recruit cost, instead of recruiting and dismissing units to fish for good rolls.
- Fixed the trade caravan never paying out: its arrival check read the event location from the
  handler argument, which is always empty, so it silently did nothing.

## 0.5.0 — 2026-09-27

- Invest menu showed training as "level X/4" when the top level is 3, and never labelled the
  final step "Maximum Level". Both now use the real maximum.
- Removed leftover unit-discount code from the shop summary (it only logged warnings).

## 0.4.1 — 2026-09-27

- Mercenary camp units cost half their normal price (was 1.2x). They stay plain units with no
  heroic trait or buffs, giving the camp a niche as cheap mid-war reinforcements.
- Hired mercenaries now receive your faction's training upgrades, like normal recruits.

## 0.4.0 — 2026-09-26

- Final boss roster: the random boss is replaced by one of three hand-designed bosses, each
  with a signature mechanic, a phase change at half HP and a themed army — the Lich
  Sovereign (phylacteries), the Wyrm of the Last Age (scorching aura, Wrath) and the Usurper
  (lieutenants shield him; the Crown's Guard), with custom sprites and portraits.
- Each boss has a unique attack kit: the Lich's plague touch, slowing chill and death knell
  plus an aura that weakens adjacent enemies; the Wyrm's supercharged devour, stunning tail
  and burning breath (its own status: orange tint, 6 damage for 2 turns, not cured by
  villages); the Usurper's first-strike blade, execute stroke and a leadership aura that
  works on allies of any level.
- Objectives show the boss's status. Debug panel "Final Boss" menu: force which boss spawns,
  skip to the final scenario, or spawn the boss immediately.
- Fixed location searches that put the radius at the top level of a filter (applied after
  [not]): the Usurper's lieutenants never spawned, arena evacuation did nothing and item
  placement could pick blocked hexes.
- Boss edge units only spawn on hexes they can stand on (cavalry stuck in deep water), and
  no longer pick off-map border hexes.

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
