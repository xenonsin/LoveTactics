-- A strangleknot: the lamia's close work, and the Lust circle's returned fifth verb.
--
-- ROOT WAS LISTED AND UNFIELDED ON THIS GROUND, with a condition written into Descent.SINS on how it
-- could come back: not on a body that is also doing the moving. The harpies pinned in an early cut and
-- it was wrong for a mechanical reason -- Root sets `blocksForcedMove`, so a rooted victim cannot be
-- shoved or dragged by ANYBODY, and the flock was switching its own circle off one target at a time.
-- A lamia displaces nothing. It is the body the condition was written for.
--
-- WHAT IT MEANS BESIDE THE FLOCK, and it is a texture rather than a bug: a company held by the coils
-- cannot be thrown by the wind. Being pinned next to a serpent is genuine shelter from being scattered
-- by a harpy, and on a floor that fields both, choosing which of the two to be caught by is a decision
-- the player can actually make. The two bodies are not additive and were never meant to be.
--
-- IT IS HALF A SENTENCE. The fang at reach says the other half (weapon_lunging_fang): this one means
-- YOU CANNOT LEAVE THIS TURN, and that one means you cannot leave at all. Root's six ticks is about a
-- turn; Coiled has no clock at all. Same claim, two lengths.
--
-- A DEMON'S BLOW BURNS (docs/bestiary.md): `fire` on the tag list, the channel unmoved -- a physical
-- blow with an element on it, so a coat still answers it.
--
-- THE ROOT RIDES INSIDE THE HIT (`inflicts`) rather than on a line after it, so a miss takes it with
-- the wound (docs/accuracy.md).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Strangleknot",
    description = "Winds around an adjacent foe and leaves Root.",
    flavor = "It is not trying to break anything. It is only closing the space you were using.",
    sprite = "assets/items/strangleknot.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "fire", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_root" })
        end,
    },
}
