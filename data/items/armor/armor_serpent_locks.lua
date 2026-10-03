-- SERPENT LOCKS: Medusa's hair, cut into a poisoner's coat (data/characters/character_medusa.lua; "Envy's
-- Bestiary", row md_body, approved word for word). When a slashing blow strikes you, an adder springs up beside
-- you -- her own blood rule (trait_gorgon_blood; models/gorgon.lua), on your side of the fight, to four adders
-- at once. A Poisoner's because the adders bite with Poison.
--
-- Leather: a square of pace, as every coat costs. An unstocked trophy on the approach's rung.
local Curve = require("models.curve")

return {
    name = "Serpent Locks",
    description = "When a slashing blow strikes you, an adder springs up beside you.",
    flavor = "They are mostly asleep. A blade is the one thing that reliably wakes them.",
    sprite = "assets/items/armor_serpent_locks.png",
    type = "armor",
    tags = { "leather" },
    class = "poisoner",
    unlockLevel = 11,
    unstocked = true,
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
    traits = { "trait_gorgon_blood" },
}
