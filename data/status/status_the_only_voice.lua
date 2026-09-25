-- The Only Voice: the Lorelei's song, heard (data/characters/character_lorelei.lua). The bearer hears
-- nobody but her -- it cannot be healed, and no buff and no cleanse from its own side reaches it
-- (Status.deafToAllies, read at Combat.applyHeal, Status.apply and fx.cleanse). The Siren's Longing
-- prices walking away from her; this one prices being looked after.
--
-- A CURE CANNOT LIFT IT, and that is the rule working rather than a gap in it: the Cure an ally would
-- throw is exactly what the bearer cannot hear. What ends it is time, Beeswax in the ears beforehand,
-- or the Lorelei falling -- the song ends with its singer (Combat's releaseCharmedBy), which is the
-- circle's standing counterplay: cut the one doing it.
return {
    name = "The Only Voice",
    abbr = "Voi",
    description = "Hears only her: cannot be healed, and no buff or cleanse from its own side reaches it.",
    color = { 0.470, 0.300, 0.620 }, -- badge tint (a deeper violet than Longing)
    duration = 10,       -- ~2 turns; she tops it up every turn she is still singing
    debuff = true,
    lingers = true,
    hearsOnlyHer = true, -- Status.deafToAllies
    onApply = function(ctx)
        if ctx.applier then ctx.status.singer = ctx.applier end
    end,
}
