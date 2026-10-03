-- MANY FACES: the Many Faced One's badge for the whole fight, and the carrier of its forms (models/many_faced.lua).
--
-- A STATUS, NOT A TRAIT, for status_faceless's reason: a form swaps the grid, and the rule has to sit where every
-- form still finds it. A wound that drops the bar through a share puts the next form on (or the split); the top of
-- its turn puts the stage's face back on when something stripped it.
--
-- Not a debuff and never stripped: it is what the body is.
return {
    name = "Many Faces",
    abbr = "Many",
    description = "Many Faces: wears each general in turn, one share of its health apiece, then splits into the company.",
    color = { 0.700, 0.640, 0.420 }, -- badge tint (a dull crown-gold)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    onDamaged = function(ctx)
        require("models.many_faced").onDamaged(ctx.combat, ctx.unit)
    end,
    onTurnStart = function(ctx)
        require("models.many_faced").onTurnStart(ctx.combat, ctx.unit)
    end,
}
