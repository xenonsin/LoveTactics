-- THE KNOCK: hit the huntress hard enough and what she ate comes back out of her. Kirby's rule, told as
-- the story doc's own counterplay -- "starve her: burst her down" -- and settled on review 2026-09-23:
-- a big blow or a crit makes her LOSE the power she is holding. Nothing lands on the ground and nobody
-- picks it up; it is simply gone, and she has to go and eat something else.
--
-- The threshold is a share of her CEILING rather than a flat figure, so it holds as Growth scales her down
-- toward the shallows: at her reference level 12% is 29, which is a heavy two-hander's honest swing and a
-- crossbow's lucky one. A crit knocks it loose whatever it deals -- the blow that finds the gap.
--
-- ONLY THE HUNTRESS. The beast keeps everything it eats (models/palate.lua's capacity rule), so this is
-- carried on the huntress's phase relic and nowhere else, and Palate.knock refuses an uncapped body even
-- if the trait ever reached one. The first half of the fight is where you strip her; the second is a race.
return {
    name = "The Knock",
    description = "A blow of 12% of her health, or a critical hit, knocks her copied power out of her.",
    share = 0.12,
    onDamaged = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive and unit.palate and #unit.palate > 0) then return end
        local hp = unit.char and unit.char.stats and unit.char.stats.health
        local max = (hp and hp.max) or 0
        local heavy = max > 0 and (ctx.amount or 0) >= max * ctx.param("share", 0.12)
        if not (heavy or ctx.critical) then return end
        require("models.palate").knock(ctx.combat, unit)
    end,
}
