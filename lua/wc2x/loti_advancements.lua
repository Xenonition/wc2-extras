-- LotI advancement chain wiring for WC3.
-- [modify_unit_type] only works at config parse time, not inside events.
-- LotI unit types aren't loaded yet at our parse time, so we apply
-- advancement changes per-unit via Lua events at runtime instead.
--
-- Table sourced from: Legend_of_the_Invincibles/extra_advancements.cfg
-- LotI version synced: 4.4.1 (2026-09-12)
-- To update: diff that file against the adv_mods table below.

local on_event = wesnoth.require("on_event")

local adv_mods = {
	["Assassin"] = {set = {"Exterminator"}, xp = 300},
	["Master at Arms"] = {set = {"Champion", "Shadowalker"}, xp = 320},
	["Necromancer"] = {set = {"Arch Necromancer", "09 Ancient Lich", "Demilich"}, xp = 300},
	["Lich"] = {set = {"09 Ancient Lich", "Demilich", "Lich King"}, xp = 300},
	["Elvish Champion"] = {set = {"Elvish Juggernaut"}, xp = 250},
	["Orcish Slayer"] = {set = {"Orcish Nightblade loti"}, xp = 220},
	["Elvish Shyde"] = {set = {"Faerie Incarnation"}, xp = 250},
	["Soulless"] = {set = {"Monstrosity", "Bone Shooter", "Revenant", "Necrophage"}, xp = 90},
	["Skeleton"] = {add = {"Chocobone"}},
	["Revenant"] = {add = {"Death Knight", "Zombie Rider"}},
	["Revenant LotI"] = {add = {"Death Knight", "Zombie Rider"}},
	["Death Knight"] = {set = {"Deathlord", "Infernal Knight", "Lich King"}, xp = 270},
	["Death Knight LotI"] = {set = {"Deathlord", "Infernal Knight", "Lich King"}, xp = 270},
	["Chocobone"] = {set = {"Grim Knight", "Zombie Rider"}, xp = 180},
	["Chocobone LotI"] = {set = {"Grim Knight", "Zombie Rider"}, xp = 180},
	["Ghast"] = {set = {"Abomination"}, xp = 300},
	["Direwolf Rider"] = {set = {"Werewolf Rider"}, xp = 300},
	["Troll Warrior"] = {set = {"Siege Troll"}, xp = 280},
	["Elvish Sharpshooter"] = {set = {"Elvish Assassin", "Elvish Gryphon Rider"}, xp = 250},
	["Elvish Outrider"] = {set = {"Elvish Gryphon Rider"}, xp = 250},
	["Spectre"] = {set = {"Reaper"}, xp = 300},
	["Dwarvish Dragonguard"] = {set = {"Dwarvish Technocrat"}, xp = 300},
	["Elvish Sylph"] = {set = {"Elvish Sylph LotI"}, xp = 200},
	["Elvish Enchantress"] = {set = {"Elvish Sylph LotI", "Elvish Seer"}, xp = 300},
	["Silver Mage"] = {set = {"Duelist Wizard"}, xp = 300},
	["Troll Rocklobber"] = {set = {"Troll Boulderlobber"}, xp = 225},
	["Nightgaunt"] = {set = {"Dark Shade"}, xp = 250},
	["Fencer"] = {add = {"Sword Mage"}},
	["Mage LotI"] = {add = {"Sword Mage"}},
	["Mage"] = {add = {"Sword Mage"}},
	["Lancer"] = {set = {"Lunatic Knight"}, xp = 200},
	["Royal Guard"] = {set = {"Swordmaster"}, xp = 320},
	["Great Mage"] = {set = {"Elder Mage LotI"}, xp = 500},
	["Banebow"] = {set = {"Soul Shooter"}, xp = 280},
	["Halberdier"] = {set = {"Scythemaster"}, xp = 300},
	["Elvish High Lord"] = {set = {"Elvish Overlord"}, xp = 250},
	["Javelineer"] = {set = {"Pilum Master"}, xp = 200},
	["Dwarvish Berserker"] = {set = {"Dwarvish Battlerager"}, xp = 150},
	["Dwarvish Sentinel"] = {set = {"Dwarvish Protector"}, xp = 250},
	["Deathblade"] = {set = {"Phantom", "Grim Knight"}, xp = 120},
	["Elvish Marshal"] = {set = {"Elvish Warlord"}, xp = 260},
	["Dwarvish Lord"] = {set = {"Dwarvish Hero"}, xp = 300},
	["Goblin Pillager"] = {set = {"Goblin Ravager"}, xp = 180},
	["Elvish Avenger"] = {set = {"Elvish Nightprowler"}, xp = 230},
	["Orcish Slurbow"] = {set = {"Orcish Strafer"}, xp = 280},
	["Orcish Warlord"] = {set = {"Orcish Warmonger"}, xp = 350},
	["Goblin Impaler"] = {set = {"Sky Goblin"}, xp = 90},
	["Grand Knight"] = {set = {"Dragon Rider"}, xp = 800},
	["Grand Marshal"] = {set = {"Duke", "Dragon Rider"}, xp = 500},
	["Huntsman"] = {set = {"Predator"}, xp = 320},
	["Ranger"] = {set = {"Forester"}, xp = 300},
	["Cavalier"] = {set = {"Chaos Rider"}, xp = 260},
	["Paladin"] = {set = {"Prophet"}, xp = 300},
	["Mage of Light"] = {set = {"Celestial Messenger", "Prophet"}, xp = 300},
	["Iron Mauler"] = {set = {"Destroyer", "Blackguard"}, xp = 320},
	["Highwayman"] = {set = {"Shadow Prince", "Blackguard"}, xp = 300},
	["Fugitive"] = {set = {"Shadow Prince"}, xp = 300},
	["Goblin Rouser"] = {set = {"Goblin Warbanner"}, xp = 80},
	["Master Bowman"] = {set = {"Champion Bowman"}, xp = 300},
	["Draug"] = {set = {"Deathlord"}, xp = 250},
}

local function apply_loti_advancements(unit)
	local mod = adv_mods[unit.type]
	if not mod then return end

	if mod.set then
		local valid = {}
		for _, t in ipairs(mod.set) do
			if wesnoth.unit_types[t] then
				table.insert(valid, t)
			end
		end
		if #valid > 0 then
			unit.advances_to = valid
		end
	end

	if mod.add then
		local current = unit.advances_to
		for _, t in ipairs(mod.add) do
			if wesnoth.unit_types[t] then
				local found = false
				for _, c in ipairs(current) do
					if c == t then found = true; break end
				end
				if not found then
					table.insert(current, t)
				end
			end
		end
		unit.advances_to = current
	end

	if mod.xp then
		unit.max_experience = mod.xp
	end
end

-- Priority 0: fire before WC2's experience penalty handler (priority 1)
-- so the penalty percentage applies on top of our modified base XP.
on_event("recruit", 0, function(ec)
	local u = wesnoth.units.get(ec.x1, ec.y1)
	if u then apply_loti_advancements(u) end
end)

on_event("recall", 0, function(ec)
	local u = wesnoth.units.get(ec.x1, ec.y1)
	if u then apply_loti_advancements(u) end
end)

on_event("post_advance", 0, function(ec)
	local u = wesnoth.units.get(ec.x1, ec.y1)
	if u then apply_loti_advancements(u) end
end)

on_event("start", function()
	for _, u in ipairs(wesnoth.units.find_on_map()) do
		apply_loti_advancements(u)
	end
end)
