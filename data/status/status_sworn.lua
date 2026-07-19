-- Sworn: the visible face of Acedia's rule (data/traits/trait_unrelieved.lua), and unlike Wrath's
-- badge this one IS the mechanic -- the trait only strikes the pairs, the bite lives here.
--
-- That split is on purpose and worth stating, since status_wrath.lua argues the opposite case for
-- itself. Wrath's damage is a per-battle stat bonus, which a status cannot express (Status.statBonus
-- reads a static def table), so the trait had to own it. This effect is a RECURRING check against the
-- board -- where are you standing, right now, relative to one specific body -- and `onTurnEnd` is the
-- hook for exactly that. Putting it on the trait instead would need a per-turn trait hook that does
-- not exist.
--
-- `onTurnEnd` rather than `onTick`: this is a judgement on a turn ENDED, not an effect accruing over
-- the clock. Where you finished is the whole question, so a fast unit and a slow one are asked it the
-- same number of times.
--
-- Raw damage, and deliberately: the oath is not a blow anyone blocks. Armor turns a spear; it does
-- nothing about being alone.
return {
    name = "Sworn",
    abbr = "Swn",
    description = "Sworn to another. End your turn apart from them and it bites.",
    color = { 0.38, 0.32, 0.50 }, -- badge tint (a cold liturgical violet)
    duration = 999,       -- an imposed oath does not wear off; it lasts the battle
    hideDuration = true,  -- the countdown is meaningless -- where you are standing is the story
    magnitude = 6,        -- damage taken for a turn ended apart; the trait overwrites it
    onTurnEnd = function(ctx)
        local partner = ctx.status.partner
        local unit = ctx.unit

        -- Sworn to a corpse. The oath does not release you for having failed it, which is the entire
        -- point of the woman who imposed it -- and it is why letting a partner die is the worst thing
        -- that can happen to a formation in this fight, not a way out of the rule.
        if not partner or not partner.alive then
            ctx.damage(unit, ctx.magnitude, { "dark" }, { raw = true })
            ctx.log("action", string.format("%s stands alone, and the oath does not care why.",
                (unit.char and unit.char.name) or "Unit"))
            return
        end

        -- Orthogonal adjacency, matching the guard redirect (Combat.tryRedirect) exactly. "Beside" has
        -- to mean one thing across the knight's whole vocabulary, or the wall Rowan is trying to hold
        -- and the wall Acedia is trying to break are measured with different rulers.
        local apart = math.abs(partner.x - unit.x) + math.abs(partner.y - unit.y) > 1
        if apart then
            ctx.damage(unit, ctx.magnitude, { "dark" }, { raw = true })
        end
    end,
}
