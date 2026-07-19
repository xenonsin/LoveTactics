-- Rowan's third oath, and the answer to Acedia executed in a verb (docs/story.md, "Her three oaths").
--
-- The innate Oathward (data/traits/trait_oathward.lua) takes the first hit each turn for WHOEVER
-- happens to be standing beside its bearer -- reflexive, undiscriminating, thin, and on a cooldown.
-- That is oath two, "I will be the relief": an unlimited promise that never chooses, so it is always
-- running and never deciding.
--
-- This one NAMES a ward. It guards that one unit absolutely -- no cooldown, every blow -- and it
-- guards nobody else at all. The bearer can no longer be everywhere, and that is the whole gain:
-- Acedia's claim is that no post is ever chosen, only assigned, and a knight who walks in having
-- picked one is the refutation standing on the board. Note the symmetry with what she does: her trait
-- swears pairs nobody chose (data/traits/trait_unrelieved.lua). Same mechanic, opposite authorship.
--
-- KNOWN GAP, and it is the character rather than the code: the ward should be the PLAYER's pick at
-- combat start. There is no pre-combat prompt yet, and one owes mouse + keyboard + gamepad like
-- everything in ui/, so this picks the ally with the least health remaining -- the documented cheap
-- fallback. It keeps the mechanic and loses the choice, and the choice is the point. Wire the prompt
-- and delete the fallback.
return {
    name = "Oathward Declared",
    description = "Names one ally at the start of battle. Every blow on them is taken by you instead.",
    onCombatStart = function(ctx)
        local best, bestHp
        for _, u in ipairs(ctx.combat.units) do
            if u.alive and u.side == ctx.unit.side and u ~= ctx.unit then
                local hp = u.char and u.char.stats and u.char.stats.health
                local left = (hp and hp.current) or math.huge
                if not best or left < bestHp then best, bestHp = u, left end
            end
        end
        -- Alone on the field, so there is nobody to swear to. Deliberately NOT falling back on the
        -- innate guard: an oath with no one on the other end of it is the thing this whole line is
        -- about, and quietly re-arming a general-purpose shield here would say the opposite.
        if not best then return end

        -- `cooldown = 0` is the narrowing paying out: one ward, but every blow, not the first each
        -- turn. `ward` is read by Combat.tryRedirect, which skips a declared guard whose ward is not
        -- the unit being struck.
        ctx.unit.guard = { kind = "oathward", cooldown = 0, ward = best }
        ctx.log("system", string.format("%s takes post beside %s.",
            (ctx.unit.char and ctx.unit.char.name) or "The knight",
            (best.char and best.char.name) or "an ally"))
    end,
}
