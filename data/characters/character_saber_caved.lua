-- Saber, if the player spent the Colosseum's ten quests arguing her out of waiting.
--
-- Patience is "win without trading blows" (docs/story.md) and Ira's rule is the exact inverse: she
-- grows on every blow she takes. Saber caved means she stopped refusing that trade -- and the mail off
-- Ira's body pays her for it, which is the same trap it was when Ira wore it.
--
-- See data/characters/character_rowan_caved.lua for the shape and the reasoning; every caved companion
-- is built the same way. Only inside the Gate Below, only on a save where this line's ledger came to
-- `caved` (models/temptation.lua, data/traits/trait_hollow_crown.lua).
local base = require("data.characters.character_saber")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Saber, the Unappeased"
caved.archetype = "aggressive"

-- Not a boss: that flag means "a quest objective" (immune to execute, Charm and Polymorph) and the
-- objective here is the Crown. See character_rowan_caved.lua for the full reasoning.
caved.boss = nil

-- Her own kit plus the mail, added rather than swapped in. The First Motion is still bound in the
-- centre: the blade that was patience itself, in the hands of somebody who is not waiting any more.
caved.startingItems = {
    false,           "consumable_healing_potion", false,
    "ability_bolas", "weapon_first_motion",       "armor_mail_of_the_unappeased",
    false,           false,                       false,
}

return caved
