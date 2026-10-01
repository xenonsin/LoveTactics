-- THE SENTENCE: the Throne's second phase, which overlaps the first (reviewed 2026-09-30, "Pride's Bestiary").
-- Every third turn of the bearer's, the two foes standing furthest apart are chained (status_sentenced, each naming
-- the other): end a turn more than 2 tiles apart and both are hurt. The count is the bearer's own turns, since this
-- game has no rounds; it is kept on the trait instance, so it starts again with every fight.
return {
    name = "The Sentence",
    description = "Every third turn, chains the two foes furthest apart. Ending a turn more than 2 apart hurts both.",
    notAReaction = true,
    every = 3,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local t = ctx.trait
        t.turnsSeen = (t.turnsSeen or 0) + 1
        if t.turnsSeen % ctx.param("every", 3) ~= 0 then return end
        local Choir = require("models.choir")
        local a, b = Choir.sentencePair(ctx.combat, u)
        if not (a and b) then return end
        if Choir.sentence(ctx.combat, u, a, b) then
            ctx.log("action", string.format("%s passes sentence: %s and %s are bound.",
                (u.char and u.char.name) or "The Throne", (a.char and a.char.name) or "one",
                (b.char and b.char.name) or "another"), u)
        end
    end,
}
