-- STUDIED: every blow teaches the body what it was, and the next blow of that kind lands on a body that
-- already knows it. Gula's second rule -- the apex LEARNS -- and the rule on the Studied Hide lifted off
-- her (data/items/armor/armor_studied_hide.lua). Settled on review 2026-09-23: "have her gain resistance
-- every time she gets hit, just like the item she drops".
--
-- The slime's Adaptive (data/traits/trait_adaptive.lua) with two differences, and both are the point:
--
--   * IT READS STEEL TOO. Adaptive learns only the elements, because a slime's answer to a sword is its
--     body (amorphous, immune). A hunter's answer to a sword is to have been cut by one before -- so the
--     three physical kinds teach this as well as the nine elements.
--   * IT IS A RESISTANCE, NOT AN IMMUNITY. Resistant: <kind> (-4 per blow, floored at 1 like all
--     mitigation), the same status a ward spell hands an ally. A company that swings the same thing
--     twice has thrown a weaker second blow, not a wasted one.
--
-- ONE LESSON AT A TIME, and that is the whole counterplay, for the reason Adaptive's header gives: a
-- body that stacked them would become unhittable in exactly the number of blows it took to show it every
-- kind, which is a puzzle without a solution. So the last lesson is dropped when the next arrives, and a
-- company that ALTERNATES -- a sword, then an arrow, then a sword -- always lands its blow at full. The
-- order the company acts in becomes part of the fight.
--
-- It forgets only what IT taught. A Resistant status some ally cast on the bearer is a different promise
-- and is none of this rule's business, so the one being replaced is read off the trait's own record
-- (`ctx.trait.learned`) rather than swept by kind.
local PHYSICAL = { "slash", "pierce", "impact" }

return {
    name = "Studied",
    description = "Each hit grants resistance to its damage type, replacing the last.",
    duration = 40, -- ~8 turns: every fresh blow re-teaches it long before it would lapse
    onDamaged = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive) then return end
        local Combat = require("models.combat")
        local Status = require("models.status")

        -- The blow's own tag order, which is authored and so replays identically: the first damage kind
        -- the weapon names is the one it is about.
        local kinds = {}
        for _, k in ipairs(PHYSICAL) do kinds[k] = true end
        for _, e in ipairs(Combat.ELEMENTS) do kinds[e] = true end
        local kind
        for _, t in ipairs(ctx.tags or {}) do
            if kinds[t] and Status.defs["status_resistant_" .. t] then kind = t; break end
        end
        if not kind then return end

        local was = ctx.trait.learned
        if was and was ~= kind then ctx.clearStatus(unit, "status_resistant_" .. was) end
        ctx.trait.learned = kind
        ctx.applyStatus(unit, "status_resistant_" .. kind, { duration = ctx.param("duration", 40) })
        if was ~= kind then
            ctx.log("status", string.format("%s has learned the taste of %s.",
                (unit.char and unit.char.name) or "It", kind), unit)
        end
    end,
}
