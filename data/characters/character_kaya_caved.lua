-- Kaya, if the player spent the Lodge's ten quests arguing her past the point she would have stopped.
--
-- Temperance is "the hunt that knows when to stop" (docs/story.md). Gula's rule is that it never does.
-- There is no third state between those, and the Maw off Gula's body is what closes the gap.
--
-- See data/characters/character_rowan_caved.lua for the shape and the reasoning.
local base = require("data.characters.character_kaya")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Kaya, the Unsated"
caved.archetype = "aggressive"

-- Not a boss: that flag means "a quest objective" (immune to execute, Charm and Polymorph) and the
-- objective here is the Crown. See character_rowan_caved.lua for the full reasoning.
caved.boss = nil

caved.startingItems = {
    "weapon_iron_longbow", "ability_pinning_shot",  "consumable_healing_potion",
    false,                 "utility_wolfsong_horn", "utility_maw_of_the_unfed",
    false,                 false,                   false,
}

return caved
