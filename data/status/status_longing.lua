-- Longing: the Siren's song, heard (data/characters/character_siren.lua). Every step the bearer takes
-- that ends FARTHER from the singer than it began costs it health. Steps toward her, or across, are free,
-- and a shove costs nothing -- only a body's own feet are billed -- so the turn stays the player's and
-- what she prices is RETREAT. The cheap way out of the song is to walk in, toward the channel the naga
-- are waiting in.
--
-- WHY IT IS NOT A FIFTH WAY OF TAKING A BODY. Lust already owns four: a taunt takes the turn, a charm the
-- side, a drag the tile, and the Fire Elemental bills reaching. This bills LEAVING, which is the circle's
-- own sentence -- wanting costs -- read from the other side.
--
-- WHO SANG IT is stamped on the instance (`singer`), for two reasons: the step is measured against her,
-- and the song ends with her (Combat's releaseCharmedBy strips every Longing pointing at a body that
-- leaves the field). A refresh re-points it at the latest singer, so two Sirens hold one Longing between
-- them and it answers to whoever sang last.
--
-- Raw damage, for Bleed's reason: armour turns a blade, and does nothing whatever about wanting to stay.
return {
    name = "Longing",
    abbr = "Lng",
    description = "Longing: every step it takes away from the singer costs it health.",
    color = { 0.620, 0.420, 0.720 }, -- badge tint (song violet)
    duration = 10,  -- ~2 turns at Status.TICKS_PER_TURN; a singer still singing tops it up every turn
    magnitude = 3,  -- health per step away; the song scales it with the singer's level
    debuff = true,  -- Cure lifts it -- unless the bearer also hears only her (the Only Voice)
    lingers = true, -- you carry the song away with you; that is the point
    onApply = function(ctx)
        if ctx.applier then ctx.status.singer = ctx.applier end
    end,
    onEnterTile = function(ctx)
        if ctx.reason ~= "walk" or not ctx.fromX then return end
        local singer = ctx.status.singer
        if not (singer and singer.alive) then ctx.expire() return end
        local Combat = require("models.combat")
        local before = Combat.cellGap(ctx.fromX, ctx.fromY, singer)
        local after = Combat.cellGap(ctx.unit.x, ctx.unit.y, singer)
        if after > before then
            ctx.damage(ctx.unit, ctx.magnitude or 3, { "longing" }, { raw = true })
        end
    end,
}
