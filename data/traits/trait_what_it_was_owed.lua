-- WHAT IT WAS OWED: when a Tollkeeper falls, what it was owed climbs out of it -- the Due (data/characters/
-- character_the_due.lua), a small, fast demon that goes for whoever made the kill (models/toll.lua, Toll.spawnDue
-- and Toll.plan).
--
-- onDeath rather than a threshold, for trait_split's reason: Trait.onDeath runs from killUnit before the field is
-- unwound, so the Due lands beside the body while its tile is still the place it fell. The Due is no Tollkeeper and
-- owes nothing, so a Due that falls lets nothing out. No killer -- a burn, a trap, a hazard -- and it simply fights.
return {
    name = "What It Was Owed",
    description = "When it falls, a Due climbs out and goes for its killer.",
    notAReaction = true,
    onDeath = function(ctx)
        require("models.toll").spawnDue(ctx.combat, ctx.unit)
    end,
}
