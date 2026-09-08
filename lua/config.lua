-- WC2 Extras — configuration and scaling
-- All tuning knobs in one place for easy playtesting.

local config = {}

-- Enemy economy
-- Starting gold multiplier relative to player starting gold
config.enemy_gold_multiplier = 2.0
-- Per-village income for enemy sides (Wesnoth default is 1 per village per turn)
-- We don't override this — the engine handles it. This is here for documentation.
config.enemy_village_income = 1
-- Minimum gold floor for enemy sides (prevents total stall-out)
config.enemy_min_gold_per_turn = 5

-- Difficulty scaling multipliers (indexed by wc2_difficulty.enemy_power, range 6-9)
-- These multiply enemy starting gold on top of the base multiplier
config.difficulty_gold_scale = {
	[6] = 0.8,   -- easy
	[7] = 1.0,   -- normal
	[8] = 1.2,   -- hard
	[9] = 1.5,   -- nightmare
}

-- POI settings
config.poi_count_per_map = 3
-- Guard strength scales with scenario number
config.poi_guard_base_level = 1
-- Reward gold scales with scenario number
config.poi_gold_reward_base = 20
config.poi_gold_reward_per_scenario = 10

-- Neutral creep settings
config.creep_count_per_map = 4
config.creep_types = {
	"Wolf", "Vampire Bat", "Giant Scorpion", "Mudcrawler",
	"Giant Rat", "Fire Guardian", "Water Serpent",
}

-- Shop settings
-- Percentage discount per turn finished early (e.g. 3% per turn)
config.shop_discount_per_turn_early = 3
-- Max discount cap
config.shop_max_discount = 50
-- Number of random consumable items to show per category
config.shop_consumable_slots = 4

-- Permanent upgrade base prices (escalation: price * purchase_count)
config.upgrade_prices = {
	castle_hex = 50,
	supply_village = 80,
	unit_discount = 40,
	recall_discount = 60,
	starting_gold = 30,
	vision_radius = 35,
	reinforcements = 70,
	barracks = 120,
	training_ground = 90,
}
-- Price escalation: nth purchase costs base * escalation_factor^(n-1)
config.upgrade_price_escalation = 1.6

-- Barracks settings
config.barracks_spawn_interval = 4  -- spawn a unit every N turns

-- Training ground settings
config.training_ground_xp_per_turn = 4

-- Caravan settings
config.caravan_gold_reward_base = 40
config.caravan_gold_reward_per_scenario = 15

return config
