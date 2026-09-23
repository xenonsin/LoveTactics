-- BACKDRAUGHT: struck, it draws, and everything standing next to it catches fire.
--
-- Read it beside the family it joins, because the differences are the whole of what makes it the
-- Whirl Elemental's rule and not a fourth copy of one. The codebase already keeps this list once, in
-- trait_downdraft; this is the fifth line of it:
--
--   Shield Shove   two tiles, the attacker only, and it lives in a shield slot.
--   Antler Toss    one tile, the attacker only, an animal born wearing it.
--   Whirl Answer   everything adjacent, and it DAMAGES them.
--   Downdraft      everything adjacent, and it MOVES them.
--   Backdraught    everything adjacent, and it LIGHTS them.
--
-- WHICH IS THE OTHER HALF OF THE SAME CIRCLE'S ANSWER. The Matriarch answers a blow by deciding where
-- you are standing afterwards; this answers a blow by deciding what you are standing there ON FIRE for.
-- Two alphas, one stratum, one reflex apiece, and each one is its own element's version of the same
-- refusal to trade wounds.
--
-- AND IT IS THE FIRST HALF OF THIS BODY'S OWN LOOP, WHICH IS WHY IT MATTERS MORE HERE THAN THE WIND
-- WOULD. The Chimney-Draw hauls a BURNING body all the way in and a cold one a single tile
-- (data/items/weapon/weapon_chimney_draw.lua). So a company that opens on the Whirl Elemental the ordinary way
-- -- walk up, swing -- sets its own front rank alight, and the next thing the body does is use that
-- fire as a handhold. Hit it, burn, get dragged. That is the fight, and both halves are visible from
-- the first exchange.
--
-- IT CATCHES ITS OWN ESCORT TOO, and that is left in on Downdraft's reasoning -- a draught is a
-- draught. The Fire Elementals standing around it do not care (they resist fire almost entirely), which is
-- the one place this body and its chaff agree, and it is why the Flue seats those two together and
-- nothing else.
--
-- A COUNTER, where trait_wanting_costs beside it is a property. The distinction is the one that trait's
-- header argues: a candle is simply hot, and this is a body DOING something -- it pays stamina, it is
-- melee-gated, and Trait.answerCost doubles the price of each answer within a round, so it lights the
-- first two foes to reach it and is then a large fire with no air.
return {
    name = "Backdraught",
    description = "When struck in melee, sets fire to everything adjacent.",
    cost = { stat = "stamina", amount = 6 },
    -- NO `answersReactions`, on the stag's and the Matriarch's reasoning: a draught comes up at a blow,
    -- not at an answer. Two of these facing each other across one exchange would light and re-light
    -- until somebody ran dry.
    counter = { reach = "melee", requiresTag = "physical" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        local caught = 0
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, 1)) do
            if u ~= ctx.unit and u.alive then
                ctx.applyStatus(u, "status_burn")
                caught = caught + 1
            end
        end
        if caught > 0 then
            ctx.log("status", string.format("%s draws, and the air around it lights (%d caught).",
                (ctx.unit.char and ctx.unit.char.name) or "Unit", caught), ctx.unit)
        end
    end,
}
