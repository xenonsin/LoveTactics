-- DOWNDRAFT: struck, she throws her wings down and EVERYTHING standing next to her goes back a tile --
-- not only whoever reached in.
--
-- Read it beside the three reflexes it is assembled from, because the differences are the whole of what
-- makes it an alpha's rule rather than a fourth copy of one:
--
--   Shield Shove   two tiles, the attacker only, and it lives in a shield slot.
--   Antler Toss    one tile, the attacker only, an animal born wearing it.
--   Whirl Answer   everything adjacent, and it DAMAGES them.
--   Downdraft      everything adjacent, and it MOVES them.
--
-- So it is Whirl Answer's twin in this circle's own verb. Lust does not answer a blow with a wound; it
-- answers a blow by deciding where you are standing afterwards (models/descent.lua, the Lust entry).
-- Against a company that has surrounded her the arithmetic is brutal in the plainest way: four bodies
-- closed on her, one swing, four bodies now a tile further off and every one of them out of reach for a
-- turn -- and in the Thinwall Keep at least one of them went into a wall on the way (Combat.knockback
-- charges the impact of a shove it could not finish).
--
-- IT DEALS NOTHING ITSELF, which `shoves` declares to the rest of the machinery (models/trait.lua):
-- there is no weapon in the motion, so it is billed the stamina named here rather than a swing's price,
-- and the hover preview names it without promising damage. The wall, the fire and the threshold do the
-- talking, exactly as a mace's shove does.
--
-- IT CATCHES HER OWN FLOCK TOO, and that is left in. A harpy standing beside her goes back with
-- everybody else -- a wing-beat is a wing-beat, which is Whirl Answer's own line -- and it is the one
-- thing that stops the correct play against her being "hide inside the flock".
--
-- NO `answersReactions`, on the stag's reasoning: a rack comes up at a blow, not at an answer. Two of
-- these facing each other across one exchange would beat back and forth until somebody ran dry.
--
-- No cooldown. The escalating answer price (Trait.answerCost doubles each answer within a round) paces
-- it, so she beats the first foe back for 6, the second for 12, and is then a large bird with no wind.
return {
    name = "Downdraft",
    description = "When struck in melee, drives everything adjacent back a tile. A collision hurts them.",
    cost = { stat = "stamina", amount = 6 },
    counter = { reach = "melee", requiresTag = "physical", shoves = 1 },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        local caught = 0
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, 1)) do
            if u ~= ctx.unit and u.alive then
                ctx.knockback(u, ctx.def.counter.shoves)
                caught = caught + 1
            end
        end
        if caught > 0 then
            ctx.log("status", string.format("%s throws her wings down, and the room gives way (%d caught).",
                (ctx.unit.char and ctx.unit.char.name) or "Unit", caught), ctx.unit)
        end
    end,
}
