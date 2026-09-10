-- A briar lash: the Lust circle's plain blow, and the one that takes nothing.
--
-- WHY THE CIRCLE NEEDED ONE. Every body in this stratum -- the drift, the Chorister, the Suppliant, the
-- Bride -- swung exactly one thing, and that thing Charmed (data/items/weapon/weapon_petal_touch.lua).
-- So a hundred percent of what the circle DID was take a body, an add that could not reach anybody did
-- nothing at all but walk, and the planner's refusal to charm a side's last free body (AI.lastFreeBody)
-- would have left the same add inert on the turn it mattered most. A creature whose only action can be
-- vetoed needs a second one, or the veto reads as the fight switching itself off.
--
-- It is deliberately NOT the better move. Petal Touch is faster, and the charm is worth a flat +3 to the
-- planner (AI.WEIGHTS.STATUS), so an add standing next to somebody still reaches for them -- which is
-- correct, because that is this circle's best line and an AI that declined it would be play-acting. What
-- this buys is the rest of the time: reach 2, so a body held at arm's length presses instead of shuffling,
-- and a real answer on the turn the take is refused.
--
-- PHYSICAL, where the touch is magical. The one channel the circle had ran on magicDefense, so a party
-- in plate walked through it and a party in robes did not, and neither of them could do anything about
-- which. Two channels is a reason to look at what the company is wearing.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Briar Lash",
    description = "Strikes at reach with a whip of thorn.",
    flavor = "The wood does not always want you. Sometimes it simply objects to you standing there.",
    sprite = "assets/items/briar_lash.png",
    type = "weapon",
    class = "creature",
    dropTier = 8,
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 4, -- slower than the touch's 2: reach is bought with tempo
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(4, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
