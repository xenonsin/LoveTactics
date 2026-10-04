-- COLD-HEARTED: a splinter of the Snow Queen's mirror in the heart ("Sloth's Bestiary", 2026-10-04, approved). Laid
-- by her Shard-Bolt (3 turns) and by the Splinter of the Mirror, the spellbreaker's drop (2 turns).
--
-- IT REFUSES EVERY KINDNESS AIMED AT AN ALLY -- no heal, no buff, no swap (`forbidsAid`, read by Combat.useItem and
-- Combat.abilityTargets at the aim, and by Combat.itemBlockReason for a support cast that spreads). The body may
-- still look after itself and still strike: the splinter takes the company's support away, not its blade.
--
-- FIRE THAWS IT: a blow carrying fire takes it off at once. A debuff, so a Cure from an ally lifts it too -- which
-- is the review's counter, "spread your support so one splinter can't cut off the whole company's healing".
return {
    name = "Cold-Hearted",
    abbr = "Cold",
    description = "Cold-Hearted: cannot heal, buff or aid an ally. Fire thaws it.",
    color = { 0.700, 0.860, 0.950 }, -- badge tint (mirror-ice)
    duration = 15, -- three turns at Status.TICKS_PER_TURN
    debuff = true,
    forbidsAid = true,
    onDamaged = function(ctx)
        for _, t in ipairs(ctx.tags or {}) do
            if t == "fire" then
                ctx.log("status", string.format("The splinter in %s's heart thaws.",
                    (ctx.unit.char and ctx.unit.char.name) or "it"))
                ctx.expire()
                return
            end
        end
    end,
}
