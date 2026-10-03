-- CAST BY YOU: the badge a Shade wears for the whole fight (data/traits/trait_cast_by_you.lua). Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 1).
--
-- A STATUS, NOT A TRAIT, because the read has to follow the body wherever it is put: a status hears every tile it
-- is walked or shoved onto (onEnterTile) and the end of its turn, and a trait hears neither. Beside a wall or
-- ridge the Shade is Unseen (status_invisible, the game's one concealment); on open ground it is Limned
-- (models/envy_oneoffs.lua). So a shove into the open finds it at once, which is the counter the review named.
--
-- Not a debuff and never stripped: it is what the body is.
return {
    name = "Cast by You",
    abbr = "Shd",
    description = "Cast by You: Unseen beside a wall or ridge, and Limned on open ground.",
    color = { 0.300, 0.290, 0.360 }, -- badge tint (shadow on stone)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    onEnterTile = function(ctx)
        require("models.envy_oneoffs").reshadow(ctx.combat, ctx.unit, true)
    end,
    onTurnEnd = function(ctx)
        require("models.envy_oneoffs").reshadow(ctx.combat, ctx.unit, true)
    end,
}
