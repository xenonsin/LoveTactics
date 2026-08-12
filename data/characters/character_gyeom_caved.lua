-- Gyeom, if the player spent the Arcanum's ten quests persuading her she had nothing left to learn.
--
-- Humility is "the mage who is never finished" (docs/story.md) -- she meets a spell with a
-- better-practised self, not a bigger one. Sublimitas is the same woman certain of her own summit. The
-- codex off her body answers every spell with your own, which is what being finished looks like from
-- the inside: nothing new to say, so say theirs back.
--
-- See data/characters/character_rowan_caved.lua for the shape and the reasoning.
local base = require("data.characters.character_gyeom")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Gyeom, the Unequalled"
caved.archetype = "aggressive"

-- Not a boss: that flag means "a quest objective" (immune to execute, Charm and Polymorph) and the
-- objective here is the Crown. See character_rowan_caved.lua for the full reasoning.
caved.boss = nil

caved.startingItems = {
    "weapon_wand",  "ability_fire_bolt", "consumable_mana_potion",
    false,          "utility_ledger",    "utility_codex_unanswered",
    false,          false,               false,
}

return caved
