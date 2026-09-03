-- The pact, beating. Ira's phase-two relic (data/characters/character_general_wrath_demon.lua carries
-- it in her demon grid), the twin of her human-form Unappeased Heart: it holds the SAME rule --
-- trait_wrath_rising, harder the nearer she is to death -- and nothing else. What it deliberately does
-- NOT carry is the phase trigger (trait_boss_phases): the transform has already happened by the time
-- this body is on the board, so the demon must not try to shed a shape again.
--
-- Why a grid relic and not the blueprint's `traits` field: character-level traits are not instantiated
-- onto the runtime char (models/character.lua copies no `traits`), so a rule a body is meant to carry
-- has to ride on an item in its 3x3 grid (models/trait.lua, Trait.attach). This is the demon's echo of
-- the human Heart, so the curve keeps compounding through phase two off the heavier base.
--
-- `bound = true`: like the Heart, it can never be stolen or dropped -- a rogue cannot lift the demon's
-- whole rule off her, and it leaves no second copy behind (the player's version of the rule is the
-- looted armor_mail_of_the_unappeased, granted by the quest, never this). No `class`/`price`: not gear
-- anyone shops for; only its base value is ever seen.
local Curve = require("models.curve")

return {
    name = "The Unbound Heart",
    description = "Increase damage by 1 per blow you take, plus up to +20 by the fraction of health missing.",
    flavor = "What she bought with her freedom, beating in the place her own heart was.",
    sprite = "assets/items/sig_unappeased_heart.png", -- shares the Heart's art until its own exists
    type = "utility", -- `bound` (not the type) is what locks it in place
    class = "creature",
    tags = { "signature", "relic" },
    bound = true,
    traits = { "trait_wrath_rising" },
    bonus = { damage = Curve.ramp(2, 12) }, -- levels 0..10 (only base is ever used)
}
