-- BORROWED HORN: the Hornless Twin's mana, drawn from her sister (trait_the_hornless_sister). Approved 2026-09-26
-- ("The Oni of Wrath"): "every cast drains mana from her sister. Silence or kill the horned one and the hornless
-- one can't cast."
--
-- At the top of her turn she draws up to DRAW mana out of her sister's pool into her own. If there is no sister to
-- draw from -- fallen, Silenced, or her horn Snapped -- she is Silenced until her next turn instead.
local DRAW = 12
local TURN = 5 -- Status.TICKS_PER_TURN

return {
    name = "Borrowed Horn",
    abbr = "Borrow",
    description = "Draws her mana from her sister each turn. Without her sister, Silenced.",
    color = { 0.380, 0.520, 0.720 }, -- badge tint (a paler blue)
    duration = math.huge,
    hideDuration = true,
    draw = DRAW,
    onTurnStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local Status = require("models.status")
        local def = require("models.trait").defs["trait_the_hornless_sister"]
        local s = def and def.sister(ctx.combat, u)
        if not s or Status.has(s, "status_horn_snapped") or Status.has(s, "status_silenced") then
            Status.apply(ctx.combat, u, "status_silenced", { duration = TURN + 1 })
            return
        end
        local from = s.char.stats.mana
        local to = u.char.stats.mana
        if not (from and to) then return end
        local want = math.min(DRAW, math.max(0, (to.max or 0) - (to.current or 0)), from.current or 0)
        if want <= 0 then return end
        from.current = from.current - want
        to.current = to.current + want
    end,
}
