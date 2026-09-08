-- WC2 Extras — configuration and scaling
-- All tuning knobs in one place for easy playtesting.

local config = {}

-- Enemy economy
config.enemy_gold_multiplier = 2.0
config.enemy_min_gold_per_turn = 5

config.difficulty_gold_scale = {
	[6] = 0.8,
	[7] = 1.0,
	[8] = 1.2,
	[9] = 1.5,
}

-- POI settings
config.poi_count_per_map = 3
config.poi_guard_base_level = 1
config.poi_gold_reward_base = 20
config.poi_gold_reward_per_scenario = 10

config.creep_count_per_map = 4
config.creep_types = {
	"Wolf", "Vampire Bat", "Giant Scorpion", "Mudcrawler",
	"Giant Rat", "Fire Guardian", "Water Serpent",
}

-- Shop settings
config.shop_discount_per_turn_early = 3
config.shop_max_discount = 50
config.shop_consumable_slots = 4

-- Permanent upgrade base prices
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
config.upgrade_price_escalation = 1.6

config.barracks_spawn_interval = 4
config.training_ground_xp_per_turn = 4

config.caravan_gold_reward_base = 40
config.caravan_gold_reward_per_scenario = 15

return config
