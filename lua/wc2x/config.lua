-- WC2 Extras — configuration and scaling
-- All tuning knobs in one place for easy playtesting.

local config = {}

-- Enemy economy
config.enemy_gold_multiplier = 0.5
config.enemy_gold_variance = { 0.7, 1.3 }    -- random multiplier on starting gold per side
config.enemy_min_gold_per_turn = 10
-- Rout: from this turn, an enemy side down to its leader (no other units) and at most this many
-- villages loses its gold and base income for the rest of the map, so it can't feed recruits to
-- players farming XP
config.rout_min_turn = 3
config.rout_max_villages = 1

-- XP bottle: finishing a map early leaves one next to each player's leader on the next map
config.xp_bottle_per_turn = 8    -- XP per turn left at victory
config.xp_bottle_max = 120

config.difficulty_gold_scale = {
	[6] = 0.8,
	[7] = 1.0,
	[8] = 1.2,
	[9] = 1.5,
}

-- POI settings
config.poi_base_count = 3
config.poi_per_scenario = 0.5
config.poi_gold_reward_base = { 40, 80 }
config.poi_gold_reward_per_scenario = { 10, 20 }

config.creep_count_per_map = 4
config.creep_types = {
	"Wolf", "Vampire Bat", "Giant Scorpion", "Mudcrawler",
	"Giant Rat", "Fire Guardian", "Water Serpent",
}

-- Enemy village capture at map start
config.enemy_village_base_pct = 30
config.enemy_village_pct_per_scenario = 10
config.enemy_village_max_pct = 80
config.enemy_village_safe_radius = 4

-- Shop settings
config.shop_discount_per_turn_early = 3
config.shop_max_discount = 50
config.shop_slots_per_category = 2

-- Permanent upgrade base prices
config.upgrade_prices = {
	castle_hex = 50,
	supply_village = 80,
	base_income = 30,
	vision_radius = 35,
	reinforcements = 70,
	barracks = 120,
	training_ground = 90,
}
config.upgrade_price_escalation = 1.6

-- Retrain (right-click on a unit recruited this turn): re-roll its training for this share of its cost
config.retrain_cost_pct = 50

config.barracks_spawn_interval = 4
config.training_ground_xp_per_turn = 4

-- Mercenary camp scaling — weights per level, by scenario threshold
-- Each entry: from that scenario onward, use these weights when picking offers.
-- Higher-level mercs appear with increasing probability in later scenarios.
config.merc_level_weights = {
	{ scenario = 1, weights = { [2] = 10 } },
	{ scenario = 2, weights = { [2] = 8, [3] = 2 } },
	{ scenario = 3, weights = { [2] = 5, [3] = 4, [4] = 1 } },
	{ scenario = 4, weights = { [2] = 3, [3] = 5, [4] = 2 } },
	{ scenario = 5, weights = { [2] = 2, [3] = 4, [4] = 3, [5] = 1 } },
}
config.merc_offer_count = 3
-- half price: mercs are plain units (no heroic trait or buffs), the cheap mid-war option
config.merc_cost_multiplier = 0.5

-- Enemy leader scaling — target leader level by scenario.
-- The leader spawns at the highest available level up to this target,
-- walking the advancement tree from the data table's L3 type.
config.enemy_leader_level = {
	{ scenario = 1, level = 2 },
	{ scenario = 2, level = 3 },
	{ scenario = 4, level = 4 },
	{ scenario = 5, level = 5 },
}

-- Enemy recruit expansion (add higher-level units to recruit list in later scenarios)
config.enemy_recruit_tiers = {
	{ level = 2, start_scenario = 2, count = 3 },
	{ level = 3, start_scenario = 4, count = 2 },
	{ level = 4, start_scenario = 6, count = 1 },
}

-- Assassin spawns (enemy units that target player leaders)
config.assassin_start_scenario = 2     -- scenario where assassins can appear
config.assassin_chance_pct = 12        -- % chance per enemy recruit to become an assassin

-- AI personality — randomized per side from these ranges
config.ai_personality_ranges = {
	aggression        = { 0.1,  0.8  },   -- 0=passive, 1=attacks everything
	caution           = { 0.05, 0.7  },   -- higher=retreats more, plays safer
	village_value     = { 1,    5    },   -- how much AI prioritizes villages
	villages_per_scout = { 3,   12   },   -- lower=more scouts grabbing villages
	leader_aggression = { -5,   1    },   -- negative=stays on keep, positive=fights
	scout_village_targeting = { 2, 6 },   -- how far scouts travel for villages
}
config.ai_grouping_options = { "offensive", "defensive", "no" }

-- Recruitment save-gold baseline (randomized per side)
config.ai_save_gold_ranges = {
	active         = { 1, 2 },       -- turn from which saving activates
	save_begin     = { 1.2, 2.0 },   -- start saving when unit-cost/gold ratio above this
	save_end       = { 0.8, 1.2 },   -- resume spending when ratio drops below this
}
config.ai_recruitment_ranges = {
	recruitment_diversity   = { 1.5, 3.0 },
	recruitment_randomness  = { 20,  80  },
}

-- AI Director overrides per tactic (multiplied against baseline save_begin)
config.ai_tactic_spend_modifier = {
	rally_strike     = 0.6,   -- spend freely, build army for push
	village_turtle   = 1.4,   -- conserve gold, hold position
	village_grab     = 1.0,   -- moderate spending
	castle_defense   = 0.4,   -- spend everything, recruit reinforcements now
	fighting_retreat = 0.8,   -- spend moderately while pulling back
}

-- POI guard scaling by scenario
config.poi_guard_scaling = {
	shrine = {
		{ scenario = 1, count = { 1, 1 }, types = { "Footpad", "Poacher", "Thug", "Orcish Grunt", "Troll Whelp" } },
		{ scenario = 2, count = { 1, 2 }, types = { "Orcish Warrior", "Troll", "Ogre", "Bandit", "Mage", "Wolf Rider" } },
		{ scenario = 3, count = { 2, 3 }, types = { "Orcish Crossbowman", "Troll Warrior", "Swordsman", "White Mage", "Rogue" } },
		{ scenario = 5, count = { 2, 4 }, types = { "Orcish Slurbow", "Troll Hero", "Knight", "Red Mage", "Assassin" } },
	},
	ruins = {
		{ scenario = 1, count = { 1, 1 }, types = { "Skeleton", "Walking Corpse", "Wolf", "Mudcrawler" } },
		{ scenario = 2, count = { 1, 2 }, types = { "Ghoul", "Orcish Archer", "Thief", "Giant Scorpion", "Troll Whelp" } },
		{ scenario = 3, count = { 2, 3 }, types = { "Revenant", "Chocobone", "Troll", "Orcish Warrior", "Ghost" } },
		{ scenario = 5, count = { 2, 4 }, types = { "Bone Shooter", "Wraith", "Troll Warrior", "Orcish Crossbowman", "Ogre" } },
	},
}

-- Shrine buff table (weight = relative chance)
-- "effect" buffs are applied as objects; "trait" buffs are applied as traits
config.shrine_buffs = {
	{ name = "+8 Hitpoints",      weight = 5, effect = { apply_to = "hitpoints", increase_total = 8 } },
	{ name = "+1 Melee Damage",   weight = 4, effect = { apply_to = "attack", range = "melee", increase_damage = 1 } },
	{ name = "+1 Ranged Damage",  weight = 4, effect = { apply_to = "attack", range = "ranged", increase_damage = 1 } },
	{ name = "+1 Movement",       weight = 3, effect = { apply_to = "movement", increase = 1 } },
	{ name = "+20% XP Bonus",     weight = 3, effect = { apply_to = "max_experience", increase = "-20%" } },
	{ name = "+1 Melee Strike",   weight = 1, effect = { apply_to = "attack", range = "melee", increase_attacks = 1 } },
	{ name = "+1 Ranged Strike",  weight = 1, effect = { apply_to = "attack", range = "ranged", increase_attacks = 1 } },
	-- Uncommon stat buffs
	{ name = "+12 Hitpoints",     weight = 3, effect = { apply_to = "hitpoints", increase_total = 12 } },
	{ name = "+16 Hitpoints",     weight = 2, effect = { apply_to = "hitpoints", increase_total = 16 } },
	{ name = "+2 Melee Damage",   weight = 2, effect = { apply_to = "attack", range = "melee", increase_damage = 2 } },
	{ name = "+2 Ranged Damage",  weight = 2, effect = { apply_to = "attack", range = "ranged", increase_damage = 2 } },
	{ name = "+2 Movement",       weight = 2, effect = { apply_to = "movement", increase = 2 } },
	{ name = "+3 Movement",       weight = 1, effect = { apply_to = "movement", increase = 3 } },
	-- Resistance buffs (negative = more resistant)
	{ name = "+15% Blade Resist",  weight = 2, effect = { apply_to = "resistance", replace = false, wml.tag.resistance { blade = -15 } } },
	{ name = "+15% Impact Resist", weight = 2, effect = { apply_to = "resistance", replace = false, wml.tag.resistance { impact = -15 } } },
	{ name = "+15% Fire Resist",   weight = 2, effect = { apply_to = "resistance", replace = false, wml.tag.resistance { fire = -15 } } },
	{ name = "+15% Cold Resist",   weight = 2, effect = { apply_to = "resistance", replace = false, wml.tag.resistance { cold = -15 } } },
	{ name = "+15% Pierce Resist", weight = 2, effect = { apply_to = "resistance", replace = false, wml.tag.resistance { pierce = -15 } } },
	{ name = "+15% Arcane Resist", weight = 2, effect = { apply_to = "resistance", replace = false, wml.tag.resistance { arcane = -15 } } },
	-- Rare abilities (weight 1 each)
	{ name = "Ability: Ambush",      weight = 1, trait = {
		id = "wc2x_ambush", male_name = "ambush", female_name = "ambush",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.hides { id = "ambush", name = "ambush",
				description = "This unit can hide in forest, and remain undetected by its enemies.",
				wml.tag.filter_self { wml.tag.filter_location { terrain = "*^F*" } },
			},
		}},
	}},
	{ name = "Ability: Skirmisher",  weight = 1, trait = {
		id = "wc2x_skirmisher", male_name = "skirmisher", female_name = "skirmisher",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.skirmisher { id = "skirmisher", name = "skirmisher",
				description = "This unit's movement is not slowed by enemy zones of control.",
			},
		}},
	}},
	{ name = "Ability: Regenerates", weight = 1, trait = {
		id = "wc2x_regenerates", male_name = "regenerates", female_name = "regenerates",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.regenerate { id = "regenerates", name = "regenerates",
				description = "This unit restores 8 HP at the start of each turn.",
				value = 8,
			},
		}},
	}},
	{ name = "Ability: Leadership",  weight = 1, trait = {
		id = "wc2x_leadership", male_name = "leadership", female_name = "leadership",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.leadership { id = "leadership", name = "leadership",
				description = "Adjacent lower-level allied units deal 25% more damage for each level of difference.",
				value = "(25 * (level - other.level))", cumulative = false, affect_self = false,
				wml.tag.affect_adjacent { wml.tag.filter { formula = "level < other.level" } },
			},
		}},
	}},
	{ name = "Ability: Teleport",    weight = 1, trait = {
		id = "wc2x_teleport", male_name = "teleport", female_name = "teleport",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.teleport { id = "teleport", name = "teleport",
				description = "This unit can teleport between any two friendly villages.",
				wml.tag.tunnel {
					id = "village_teleport",
					wml.tag.source { terrain = "*^V*",
						formula = "owner_side = teleport_unit.side_number and (unit = teleport_unit or not unit) where unit = unit_at(loc)",
					},
					wml.tag.target { terrain = "*^V*",
						formula = "owner_side = teleport_unit.side_number and not unit_at(loc)",
					},
					wml.tag.filter { ability = "teleport" },
				},
			},
		}},
	}},
	{ name = "Ability: Nightstalk",  weight = 1, trait = {
		id = "wc2x_nightstalk", male_name = "nightstalk", female_name = "nightstalk",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.hides { id = "nightstalk", name = "nightstalk",
				description = "This unit becomes invisible during night.",
				wml.tag.filter_self { wml.tag.filter_location { time_of_day = "chaotic" } },
			},
		}},
	}},
	{ name = "Ability: Steadfast",   weight = 1, trait = {
		id = "wc2x_steadfast", male_name = "steadfast", female_name = "steadfast",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.resistance { id = "steadfast", name = "steadfast",
				description = "This unit's resistances are doubled when defending, up to a maximum of 50%.",
				multiply = 2, max_value = 50, active_on = "defense",
				wml.tag.filter_base_value { greater_than = 0, less_than = 50 },
			},
		}},
	}},
	{ name = "Ability: Cures",       weight = 1, trait = {
		id = "wc2x_cures", male_name = "cures", female_name = "cures",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.heals { id = "curing", name = "cures",
				description = "This unit can cure adjacent allied units of poison.",
				affect_allies = true, affect_self = false, poison = "cured",
				wml.tag.affect_adjacent {},
			},
		}},
	}},
	{ name = "Ability: Heals +4",    weight = 1, trait = {
		id = "wc2x_heals4", male_name = "heals +4", female_name = "heals +4",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.heals { id = "healing4", name = "heals +4",
				description = "This unit heals adjacent allied units for 4 HP per turn.",
				value = 4, affect_allies = true, affect_self = false, poison = "slowed",
				wml.tag.affect_adjacent {},
			},
		}},
	}},
	{ name = "Ability: Heals +8",    weight = 1, trait = {
		id = "wc2x_heals8", male_name = "heals +8", female_name = "heals +8",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.heals { id = "healing8", name = "heals +8",
				description = "This unit heals adjacent allied units for 8 HP per turn.",
				value = 8, affect_allies = true, affect_self = false, poison = "slowed",
				wml.tag.affect_adjacent {},
			},
		}},
	}},
	{ name = "Ability: Bulwark",     weight = 1, trait = {
		id = "wc2x_bulwark", male_name = "bulwark", female_name = "bulwark",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.resistance { id = "bulwark", name = "bulwark",
				description = "Adjacent allied units gain +10% resistance to all damage types.",
				add = 10, affect_self = false, affect_allies = true, affect_enemies = false,
				wml.tag.affect_adjacent {},
			},
		}},
	}},
	{ name = "Ability: Sunder",      weight = 1, trait = {
		id = "wc2x_sunder", male_name = "sunder", female_name = "sunder",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.resistance { id = "sunder", name = "sunder",
				description = "Adjacent enemy units have 15% lower resistance to all damage types.",
				sub = 15, affect_self = false, affect_allies = false, affect_enemies = true,
				wml.tag.affect_adjacent {},
			},
		}},
	}},
	-- Weapon specials (weight 1 each)
	{ name = "Melee: Backstab",      weight = 1, trait = {
		id = "wc2x_backstab", male_name = "backstab", female_name = "backstab",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.damage {
				id = "backstab", name = "backstab",
				description = "When used offensively, this attack deals double damage if there is an enemy of the target on the opposite side of the target, and that unit is not incapacitated (turned to stone or otherwise paralyzed).",
				multiply = 2, active_on = "offense",
				-- same check as mainline WEAPON_SPECIAL_BACKSTAB: the unit behind the target along the attack line
				wml.tag.filter_opponent {
					formula = "enemy_of(self, flanker) and not flanker.petrified where flanker = unit_at(direction_from(loc, other.facing))",
				},
			}},
		},
	}},
	{ name = "Melee: Poison",        weight = 1, trait = {
		id = "wc2x_poison", male_name = "poison", female_name = "poison",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.poison {
				id = "poison", name = "poison",
				description = "This attack poisons living targets, dealing 8 damage per turn.",
			}},
		},
	}},
	{ name = "Melee: Drain",         weight = 1, trait = {
		id = "wc2x_drain", male_name = "drain", female_name = "drain",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.drains {
				id = "drains", name = "drains",
				description = "This attack recovers half the damage dealt.",
				value = 50,
			}},
		},
	}},
	{ name = "Ranged: Marksman",     weight = 1, trait = {
		id = "wc2x_marksman", male_name = "marksman", female_name = "marksman",
		wml.tag.effect { apply_to = "attack", range = "ranged",
			wml.tag.set_specials { mode = "append", wml.tag.chance_to_hit {
				id = "marksman", name = "marksman",
				description = "When used offensively, this attack always has at least a 60% chance to hit.",
				value = 60, cumulative = true, active_on = "offense",
			}},
		},
	}},
	{ name = "Melee: Berserk",       weight = 1, trait = {
		id = "wc2x_berserk", male_name = "berserk", female_name = "berserk",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.berserk {
				id = "berserk", name = "berserk",
				description = "This unit fights until one of the combatants is dead.",
				value = 30,
			}},
		},
	}},
	{ name = "Melee: Supercharge",   weight = 1, trait = {
		id = "wc2x_supercharge", male_name = "supercharge", female_name = "supercharge",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.damage {
				id = "supercharge", name = "supercharge",
				description = "When used offensively, this attack deals quadruple damage to the target. It also causes this unit to take quadruple damage from the target's counterattack.",
				multiply = 4, apply_to = "both", active_on = "offense",
			}},
		},
	}},
	{ name = "All Attacks: Duelist", weight = 1, trait = {
		id = "wc2x_duelist", male_name = "duelist", female_name = "duelist",
		wml.tag.effect { apply_to = "attack",
			wml.tag.set_specials { mode = "append", wml.tag.damage {
				id = "duelist", name = "duelist",
				description = "+50% damage when no other unit is adjacent to either combatant.",
				multiply = 1.5,
				wml.tag.filter_self { wml.tag.filter_adjacent { count = 1 } },
				wml.tag.filter_opponent { wml.tag.filter_adjacent { count = 1 } },
			}},
		},
	}},
	{ name = "Melee: Pack Hunter",   weight = 1, trait = {
		id = "wc2x_pack_hunter", male_name = "pack hunter", female_name = "pack hunter",
		wml.tag.effect { apply_to = "attack", range = "melee",
			-- unnamed tiers are hidden; the named dummy carries the tooltip. count includes this unit.
			wml.tag.set_specials { mode = "append",
				wml.tag.dummy { id = "wc2x_pack_hunter", name = "pack hunter",
					description = "+10% damage for each other ally adjacent to the target, up to +30%." },
				wml.tag.damage { id = "wc2x_pack_hunter_1", multiply = 1.1,
					wml.tag.filter_opponent { wml.tag.filter_adjacent { is_enemy = "yes", count = "2" } } },
				wml.tag.damage { id = "wc2x_pack_hunter_2", multiply = 1.2,
					wml.tag.filter_opponent { wml.tag.filter_adjacent { is_enemy = "yes", count = "3" } } },
				wml.tag.damage { id = "wc2x_pack_hunter_3", multiply = 1.3,
					wml.tag.filter_opponent { wml.tag.filter_adjacent { is_enemy = "yes", count = "4-6" } } },
			},
		},
	}},
	{ name = "Melee: Flurry",        weight = 1, trait = {
		id = "wc2x_flurry", male_name = "flurry", female_name = "flurry",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append",
				wml.tag.attacks { id = "wc2x_flurry", name = "flurry",
					description = "This attack strikes twice as many times, but each strike deals half damage.",
					multiply = 2 },
				wml.tag.damage { id = "wc2x_flurry_damage", multiply = 0.5 },
			},
		},
	}},
	{ name = "Ability: Anchor",      weight = 1, trait = {
		id = "wc2x_anchor", male_name = "anchor", female_name = "anchor",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.dummy { id = "wc2x_anchor", name = "anchor",
				description = "This unit holds the line: +10% resistance to all damage types for each adjacent enemy, up to +30%." },
			wml.tag.resistance { id = "wc2x_anchor_1", add = 10, max_value = 70, affect_self = true,
				wml.tag.filter { wml.tag.filter_adjacent { is_enemy = "yes", count = "1" } } },
			wml.tag.resistance { id = "wc2x_anchor_2", add = 20, max_value = 70, affect_self = true,
				wml.tag.filter { wml.tag.filter_adjacent { is_enemy = "yes", count = "2" } } },
			wml.tag.resistance { id = "wc2x_anchor_3", add = 30, max_value = 70, affect_self = true,
				wml.tag.filter { wml.tag.filter_adjacent { is_enemy = "yes", count = "3-6" } } },
		}},
	}},
	-- 0.11.0 additions. Append only: gacha buffs are stored by their index in this list.
	-- Filler stats
	{ name = "+3 Melee Damage",   weight = 1, effect = { apply_to = "attack", range = "melee", increase_damage = 3 } },
	{ name = "+3 Ranged Damage",  weight = 1, effect = { apply_to = "attack", range = "ranged", increase_damage = 3 } },
	{ name = "+24 Hitpoints",     weight = 1, effect = { apply_to = "hitpoints", increase_total = 24 } },
	{ name = "+10% All Resist",   weight = 1, effect = { apply_to = "resistance", replace = false,
		wml.tag.resistance { blade = -10, pierce = -10, impact = -10, fire = -10, cold = -10, arcane = -10 } } },
	-- replace=false adds to the size of the value and keeps its sign, so negative (capped) defenses improve too
	{ name = "+5% Defense",       weight = 1, effect = { apply_to = "defense", replace = false,
		wml.tag.defense { shallow_water = -5, reef = -5, swamp_water = -5, flat = -5, sand = -5, forest = -5,
			hills = -5, mountains = -5, village = -5, castle = -5, cave = -5, frozen = -5, fungus = -5,
			deep_water = -5, unwalkable = -5 } } },
	{ name = "+40% XP Bonus",     weight = 1, effect = { apply_to = "max_experience", increase = "-40%" } },
	-- Mainline traits (same ids, so a unit that already has the trait is skipped)
	{ name = "Trait: Strong",      weight = 1, trait = {
		id = "strong", male_name = "strong", female_name = "strong",
		wml.tag.effect { apply_to = "attack", range = "melee", increase_damage = 1 },
		wml.tag.effect { apply_to = "hitpoints", increase_total = 1 },
	}},
	{ name = "Trait: Quick",       weight = 1, trait = {
		id = "quick", male_name = "quick", female_name = "quick",
		wml.tag.effect { apply_to = "movement", increase = 1 },
		wml.tag.effect { apply_to = "hitpoints", increase_total = "-5%" },
	}},
	{ name = "Trait: Resilient",   weight = 1, trait = {
		id = "resilient", male_name = "resilient", female_name = "resilient",
		wml.tag.effect { apply_to = "hitpoints", increase_total = 4 },
		wml.tag.effect { apply_to = "hitpoints", times = "per level", increase_total = 1 },
	}},
	{ name = "Trait: Intelligent", weight = 1, trait = {
		id = "intelligent", male_name = "intelligent", female_name = "intelligent",
		wml.tag.effect { apply_to = "max_experience", increase = "-20%" },
	}},
	{ name = "Trait: Healthy",     weight = 1, trait = {
		id = "healthy", male_name = "healthy", female_name = "healthy", description = "Always rest heals",
		wml.tag.effect { apply_to = "healthy" },
		wml.tag.effect { apply_to = "hitpoints", increase_total = 1 },
		wml.tag.effect { apply_to = "hitpoints", times = "per level", increase_total = 1 },
	}},
	{ name = "Trait: Fearless",    weight = 1, trait = {
		id = "fearless", male_name = "fearless", female_name = "fearless",
		description = "Fights normally during unfavorable times of day/night",
		wml.tag.effect { apply_to = "fearless" },
	}},
	{ name = "Trait: Loyal",       weight = 1, trait = {
		id = "loyal", male_name = "loyal", female_name = "loyal", description = "Zero upkeep",
		wml.tag.effect { apply_to = "loyal" },
		wml.tag.effect { apply_to = "wc2_overlay", add = "misc/loyal-icon.png" },
	}},
	-- Mainline abilities and specials that few or no default-era units have
	{ name = "Melee: Stun",          weight = 1, trait = {
		id = "wc2x_stun", male_name = "stun", female_name = "stun",
		-- the effect itself is mainline's data/lua/stun.lua, keyed on the [stun] special type
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.stun {
				id = "stun", name = "stun",
				description = "This attack hits so hard that the opponent is dazed and can no longer enforce a zone of control. The effect wears off on the opponent's next turn.",
			}},
		},
	}},
	{ name = "All Attacks: Deflect", weight = 1, trait = {
		id = "wc2x_deflect", male_name = "deflect", female_name = "deflect",
		wml.tag.effect { apply_to = "attack",
			wml.tag.set_specials { mode = "append", wml.tag.chance_to_hit {
				id = "deflect", name = "deflect",
				description = "When used defensively, this attack reduces the opponent's chance to hit by 10%.",
				sub = 10, cumulative = true, active_on = "defense", apply_to = "opponent",
			}},
		},
	}},
	{ name = "Melee: Absorb",        weight = 1, trait = {
		id = "wc2x_absorb", male_name = "absorb", female_name = "absorb",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.damage {
				id = "absorb", name = "absorb",
				description = "This attack puts the unit in good defensive position: enemy strikes deal 25% less damage.",
				multiply = 0.75, apply_to = "opponent",
			}},
		},
	}},
	{ name = "All Attacks: Arcane Edge", weight = 1, trait = {
		id = "wc2x_arcane_edge", male_name = "arcane edge", female_name = "arcane edge",
		wml.tag.effect { apply_to = "attack",
			wml.tag.set_specials { mode = "append", wml.tag.damage_type {
				id = "arcane_damage", name = "arcane",
				description = "This attack combines the arcane type with the type of weapon used so that resistance to the arcane type does not penalize the user.",
				alternative_type = "arcane",
			}},
		},
	}},
	{ name = "Ability: Concealment", weight = 1, trait = {
		id = "wc2x_concealment", male_name = "concealment", female_name = "concealment",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.hides { id = "concealment", name = "concealment", affect_self = true,
				description = "This unit can hide in villages, and remain undetected by its enemies, except by those standing next to it.",
				wml.tag.filter { wml.tag.filter_location { terrain = "*^V*" } },
			},
		}},
	}},
	{ name = "Ability: Burrow",      weight = 1, trait = {
		id = "wc2x_burrow", male_name = "burrow", female_name = "burrow",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.hides { id = "burrow", name = "burrow", affect_self = true,
				description = "This unit can hide in forest or sand if it is resting (has not moved for a turn), and remain undetected by its enemies.",
				wml.tag.filter {
					wml.tag.filter_location { terrain = "*^F*,*^Qhhf,*^Qhuf,D*^*" },
					formula = "if(self.moves = self.max_moves, 1, 0)",
				},
			},
		}},
	}},
	{ name = "Ability: Diversion",   weight = 1, trait = {
		id = "wc2x_diversion", male_name = "diversion", female_name = "diversion",
		-- mainline ABILITY_DIVERSION: a weapon special used as an ability, one [affect_adjacent] per hex axis
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.chance_to_hit { id = "diversion", name = "diversion", sub = 20, cumulative = true,
				description = "If there is an enemy of the target on the opposite side of the target, this unit diverts the target's attention and reduces its chance to hit by 20%.",
				affect_self = false, affect_allies = false, affect_enemies = true,
				wml.tag.filter { wml.tag.filter_adjacent { is_enemy = true } },
				wml.tag.affect_adjacent { adjacent = "n,s",
					wml.tag.filter { wml.tag.filter_adjacent { is_enemy = true, count = "2-6", adjacent = "n,s" } } },
				wml.tag.affect_adjacent { adjacent = "se,nw",
					wml.tag.filter { wml.tag.filter_adjacent { is_enemy = true, count = "2-6", adjacent = "se,nw" } } },
				wml.tag.affect_adjacent { adjacent = "ne,sw",
					wml.tag.filter { wml.tag.filter_adjacent { is_enemy = true, count = "2-6", adjacent = "ne,sw" } } },
			},
		}},
	}},
	{ name = "Ability: Regenerates +4", weight = 1, trait = {
		id = "wc2x_regenerates4", male_name = "regenerates +4", female_name = "regenerates +4",
		-- same ability id as Regenerates (+8): a unit never gets both
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.regenerate { id = "regenerates", name = "regenerates +4", value = 4, poison = "cured", affect_self = true,
				description = "The unit will heal itself 4 HP per turn. If it is poisoned, it will remove the poison instead of healing.",
			},
		}},
	}},
	-- WC2's own abilities and specials (same ids as WC2's items and training, so its handlers in
	-- ability_events.lua work and a unit that already has one is skipped)
	{ name = "Ability: Distract",    weight = 1, trait = {
		id = "wc2x_distract", male_name = "distract", female_name = "distract",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.skirmisher { id = "distract", name = "distract", affect_self = false, affect_allies = true,
				description = "Allied units ignore enemy zones of control adjacent to this unit.",
				wml.tag.affect_adjacent { adjacent = "n,ne,se,s,sw,nw" },
			},
		}},
	}},
	{ name = "Ability: Tenacity",    weight = 1, trait = {
		id = "wc2x_tenacity", male_name = "tenacity", female_name = "tenacity",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.resistance { id = "tenacity", name = "tenacity", divide = 2, max_value = 0,
				affect_self = true, active_on = "defense",
				description = "This unit's vulnerabilities are halved when defending.",
				wml.tag.filter_base_value { less_than = 0 },
			},
		}},
	}},
	{ name = "Ability: Banner",      weight = 1, trait = {
		id = "wc2x_banner", male_name = "banner", female_name = "banner",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.leadership { id = "banner", name = "banner", add = 20, cumulative = true,
				affect_self = false, affect_allies = true,
				description = "Adjacent allied units do 20% more damage. This is cumulative with leadership.",
				wml.tag.affect_adjacent { adjacent = "n,ne,se,s,sw,nw" },
			},
		}},
	}},
	{ name = "Ability: Forcefield",  weight = 1, trait = {
		id = "wc2x_forcefield", male_name = "forcefield", female_name = "forcefield",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.leadership { id = "forcefield", name = "forcefield", value = -13, cumulative = false,
				affect_self = false, affect_allies = false, affect_enemies = true,
				description = "Adjacent enemies do 13% less damage.",
				wml.tag.affect_adjacent { adjacent = "n,ne,se,s,sw,nw" },
			},
		}},
		wml.tag.effect { apply_to = "wc2_update_aura" },
	}},
	{ name = "Ability: Darkness",    weight = 1, conflicts = "illumination,illuminates", trait = {
		id = "wc2x_darkness", male_name = "darkness", female_name = "darkness",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.illuminates { id = "darkness", name = "darkness", value = -25, min_value = -25,
				cumulative = false, affect_self = true,
				description = "This unit darkens the surrounding area, making chaotic units fight better, and lawful units fight worse. Any units adjacent to this unit will fight as if it were dusk when it is day, and as if it were night when it is dusk.",
			},
		}},
		wml.tag.effect { apply_to = "wc2_update_aura" },
	}},
	{ name = "Ability: Corruption",  weight = 1, trait = {
		id = "wc2x_corruption", male_name = "corruption", female_name = "corruption",
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.dummy { id = "wc2_corruption", name = "corruption",
				description = "This unit corrupts adjacent enemies at the beginning of our turn. Corrupted units lose 6 HP or are reduced to 1 HP. Corruption cannot, of itself, kill a unit.",
			},
		}},
	}},
	{ name = "Melee: Fury",          weight = 1, trait = {
		id = "wc2x_fury", male_name = "fury", female_name = "fury",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.berserk {
				id = "wct_fury", name = "fury", value = 3,
				description = "Whether used offensively or defensively, this attack presses the engagement until one of the combatants is slain, or 3 rounds of attacks have occurred.",
			}},
		},
	}},
	{ name = "Ranged: Disengage",    weight = 1, trait = {
		id = "wc2x_disengage", male_name = "disengage", female_name = "disengage",
		wml.tag.effect { apply_to = "attack", range = "ranged",
			wml.tag.set_specials { mode = "append", wml.tag.dummy {
				id = "wc2_disengage", name = "disengage",
				description = "Attack with this weapon gives unit 1 moves at end of combat (unit doesn't gain a new attack).",
				-- WC2's handler checks special_id_active, which needs a filter tag on the special
				wml.tag.filter_self {},
			}},
		},
	}},
	-- 0.12.0 additions: top-tier filler (append only)
	{ name = "+4 Melee Damage",   weight = 1, effect = { apply_to = "attack", range = "melee", increase_damage = 4 } },
	{ name = "+4 Ranged Damage",  weight = 1, effect = { apply_to = "attack", range = "ranged", increase_damage = 4 } },
	{ name = "+32 Hitpoints",     weight = 1, effect = { apply_to = "hitpoints", increase_total = 32 } },
	{ name = "+4 Movement",       weight = 1, effect = { apply_to = "movement", increase = 4 } },
	{ name = "+50% XP Bonus",     weight = 1, effect = { apply_to = "max_experience", increase = "-50%" } },
	{ name = "+20% All Resist",   weight = 1, effect = { apply_to = "resistance", replace = false,
		wml.tag.resistance { blade = -20, pierce = -20, impact = -20, fire = -20, cold = -20, arcane = -20 } } },
	{ name = "+10% Defense",      weight = 1, effect = { apply_to = "defense", replace = false,
		wml.tag.defense { shallow_water = -10, reef = -10, swamp_water = -10, flat = -10, sand = -10, forest = -10,
			hills = -10, mountains = -10, village = -10, castle = -10, cave = -10, frozen = -10, fungus = -10,
			deep_water = -10, unwalkable = -10 } } },
}

-- Legendary leaders: from legendary_from_scenario, one random enemy leader per map gets a title,
-- legendary_hp_bonus and affixes (count by scenario). Each affix part is a shrine buff name or an
-- inline buff ({ effect = ... }); parts the leader already has or can't use are skipped, and an
-- affix with no usable part isn't rolled. Killing the leader drops a WC2 artifact.
config.legendary_from_scenario = 2
config.legendary_hp_bonus = "25%"
config.legendary_affix_count = { [2] = 1, [3] = 1, [4] = 2, [5] = 2 }
config.legendary_affixes = {
	{ title = "Ironclad",   weight = 3, desc = "steadfast, +20% resistances",
	  parts = { "Ability: Steadfast", "+20% All Resist" } },
	{ title = "Colossal",   weight = 3, desc = "+50% hitpoints",
	  parts = { { effect = { apply_to = "hitpoints", increase_total = "50%" } } } },
	{ title = "Forcebound", weight = 3, desc = "forcefield, +10% resistances",
	  parts = { "Ability: Forcefield", "+10% All Resist" } },
	{ title = "Unyielding", weight = 2, desc = "melee first strike, +1 melee strike",
	  parts = {
		{ effect = { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.firststrike {
				id = "firststrike", name = "first strike",
				description = "This unit always strikes first with this attack, even if defending.",
			}},
		}},
		"+1 Melee Strike",
	  } },
	{ title = "Bloodsworn", weight = 1, desc = "melee drain, regenerates",
	  parts = { "Melee: Drain", "Ability: Regenerates" } },
	{ title = "Warlord",    weight = 1, desc = "leadership, banner",
	  parts = { "Ability: Leadership", "Ability: Banner" } },
	{ title = "Shadowborn", weight = 1, desc = "darkness, corruption",
	  parts = { "Ability: Darkness", "Ability: Corruption" } },
	{ title = "Venomous",   weight = 1, desc = "melee poison, +2 melee damage",
	  parts = { "Melee: Poison", "+2 Melee Damage" } },
}

-- Caravan settings
config.caravan_gold_reward_base = 40
config.caravan_gold_reward_per_scenario = 15
config.caravan_reward_weights = { gold = 3, artifact = 2, training = 2 }

return config
