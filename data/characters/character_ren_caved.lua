-- Ren, if the player spent the Crucible's ten quests turning her giving into wanting.
--
-- Kindness "grants others' power instead of coveting it" (docs/story.md) -- the alchemist whose whole
-- craft is handing a quality to somebody who did not have it. Envy is that craft pointed the other way:
-- take the quality, and if you cannot have it, spoil it. Her authored flaw is that she is the giver who
-- never receives (docs/roadmap.md item 20), and that is the debt this line calls in.
--
-- THE EPITHET IS THE ONE THAT IS NOT ITS GENERAL'S. The other six caved companions inherit their
-- general's title outright, because a sin is a seat and the title passes to whoever fills it. Livia's
-- "the Unborn" cannot pass: it is about Livia specifically -- a made thing that wanted to be a person,
-- the one deliberate exception to the pacted-human rule (docs/story.md) -- and it says nothing about
-- envy at all. So Ren takes the sin's own sentence instead: "has no shape until it has seen yours."
--
-- See data/characters/character_rowan_caved.lua for the shape and the reasoning.
local base = require("data.characters.character_ren")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Ren, the Unshaped"
caved.archetype = "aggressive"

-- Not a boss: that flag means "a quest objective" (immune to execute, Charm and Polymorph) and the
-- objective here is the Crown. See character_rowan_caved.lua for the full reasoning.
caved.boss = nil

caved.startingItems = {
    "ability_heal",      "weapon_vitriol_wand", "consumable_panacea",
    false,               "utility_aqua_vitae",  "utility_envious_glass",
    false,               false,                 false,
}

return caved
