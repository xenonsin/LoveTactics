-- Clem, if the player spent the Undercroft's ten quests teaching her to keep it.
--
-- Charity "takes from the rich and keeps none of it" (docs/story.md), and the whole distance between
-- her and Aurea is that last clause. She is also the companion whose authored flaw is that she forgives
-- every debt but her own (docs/roadmap.md item 20) -- which is the crack this line widens: somebody who
-- believes she is owed nothing is somebody who can be talked into being owed everything.
--
-- See data/characters/character_rowan_caved.lua for the shape and the reasoning.
local base = require("data.characters.character_clem")

local caved = {}
for k, v in pairs(base) do caved[k] = v end

caved.name = "Clem, the Ever-Owed"
-- Already `aggressive` on the companion -- restated rather than inherited so every caved blueprint
-- reads the same way, and so a future tuning pass on the recruit cannot quietly change what the Gate
-- fights.
caved.archetype = "aggressive"

-- Not a boss: that flag means "a quest objective" (immune to execute, Charm and Polymorph) and the
-- objective here is the Crown. See character_rowan_caved.lua for the full reasoning.
caved.boss = nil

-- Her grid is the fullest of the seven: six cells spoken for, so the purse takes the seventh.
caved.startingItems = {
    "weapon_envenomed_kris",   "ability_shadow_strike", "consumable_smoke_bomb",
    "ability_shadow_step",     "weapon_borrowed_time",  "utility_feather_boots",
    "utility_bottomless_purse", false,                  false,
}

return caved
