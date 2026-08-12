-- Amana, if the player spent the Cathedral's ten quests talking her into taking what was not offered.
--
-- Devotion "gives what is offered, refuses what is not" (docs/story.md), and Luxuria's whole rule is
-- the refusal dropped: she takes. Amana caved is the shortest distance between those two sentences,
-- and the reliquary off Luxuria's body is what she is taking with now.
--
-- She is the one companion the church already branded fallen once, and was wrong about
-- (data/quests/cathedral/quest_cathedral_slot_02.lua -- "The Fallen Confessor", where the player bests
-- her and recruits her instead). A save that ends her line here is a save where the Cathedral turned
-- out to be right about her in the end, for none of the reasons it gave, and only because of the
-- player.
--
-- See data/characters/character_rowan_caved.lua for the shape and the reasoning.
local base = require("data.characters.character_amana")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Amana, the Unbidden"
-- A healer who has stopped asking. `support` keeps her behind the line mending her own side; the point
-- of her now is what she does to yours.
caved.archetype = "aggressive"

-- Not a boss: that flag means "a quest objective" (immune to execute, Charm and Polymorph) and the
-- objective here is the Crown. See character_rowan_caved.lua for the full reasoning.
caved.boss = nil

caved.startingItems = {
    "ability_heal",         "weapon_censer",                "consumable_healing_potion",
    "utility_martyrs_icon", "utility_reliquary_kept_trust", "utility_reliquary_unbidden",
    false,                  false,                          false,
}

return caved
