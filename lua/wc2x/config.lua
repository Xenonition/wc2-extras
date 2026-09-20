-- WC2 Extras — configuration and scaling
-- All tuning knobs in one place for easy playtesting.

local config = {}

-- Enemy economy
config.enemy_gold_multiplier = 0.5
config.enemy_gold_variance = { 0.7, 1.3 }    -- random multiplier on starting gold per side
config.enemy_min_gold_per_turn = 10

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
config.merc_cost_multiplier = 1.2

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
				description = "Adjacent lower-level allied units deal more damage in combat.",
				value = 25,
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
	-- Weapon specials (weight 1 each)
	{ name = "Melee: Backstab",      weight = 1, trait = {
		id = "wc2x_backstab", male_name = "backstab", female_name = "backstab",
		wml.tag.effect { apply_to = "attack", range = "melee",
			wml.tag.set_specials { mode = "append", wml.tag.damage {
				id = "backstab", name = "backstab",
				description = "Double damage when an ally is on the opposite side of the target.",
				multiply = 2, active_on = "offense",
				wml.tag.filter_opponent { wml.tag.filter_adjacent {
					is_enemy = "yes", adjacent = "opposite",
				}},
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
}

-- Caravan settings
config.caravan_gold_reward_base = 40
config.caravan_gold_reward_per_scenario = 15
config.caravan_reward_weights = { gold = 3, artifact = 2, training = 2 }

return config
