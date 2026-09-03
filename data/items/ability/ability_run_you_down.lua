-- Ira Unbound's anti-kite (data/characters/character_general_wrath_demon.lua carries it in phase two).
-- Past the transform she is fast and she hunts, and her whole rule feeds on the long trade -- so a foe
-- who backs off to wait the demon out is the one thing she cannot allow. This hauls them back: a reach
-- that fetches a distant body, wounds it on the way in, and drops it at her feet, back in the hour.
--
-- Modeled on the Gaff Line (data/items/ability/ability_gaff_line.lua): damage FIRST, so a pull that
-- would have killed simply leaves a corpse where it stood rather than dragging one -- the honest
-- outcome, and one the damage preview shows coming.
--
-- No `class`/`price`: an enemy's kit, never a shelf item; only its base value is ever seen.
local Curve = require("models.curve")

return {
    name = "Run You Down",
    description = "Hooks a distant foe, wounds it, and drags it back into reach.",
    flavor = "There is nowhere on this sand you have not already lost. Come back and lose it here.",
    sprite = "assets/items/ability_gaff_line.png", -- placeholder until its own art exists
    type = "ability",
    class = "creature",
    tags = { "physical" },
    activeAbility = {
        target = "enemy",
        range = 4,
        minRange = 2,          -- pointless on someone already beside her
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            fx.damage(fx.target)
            if not fx.target.alive then return end
            fx.pull(fx.target) -- Combat.pull draws it one tile at a time toward her, springing what it crosses
        end,
    },
}
