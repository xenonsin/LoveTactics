-- Encounter blueprint. Selection is dynamic: `weight` sets how likely this is
-- picked, `depth` gates it behind how far into the campaign the road is, and an optional
-- `condition(ctx)` can gate on biome/quest/etc. See models/encounter.lua.
-- `ctx = { depth, rung, biome, quest, seed }`. How MANY bodies is models/band.lua.
--
-- THE WILD BOAR: the wood's ordinary traffic, and the ONLY stop in the game that fields boars alone.
--
-- IT USED TO BE TWO STOPS. `encounter_the_sounder` stood beside this one fielding boars and only
-- boars, and the pair was the clearest case in the game of a duplicate hiding behind a count: both
-- were pinned at the skirmish ceiling (Arena.SKIRMISH_CAP, four) within a floor or two of the top --
-- this one by a curve of `2 + depth` that added a body PER FLOOR where every neighbour added one per
-- five -- so the player met four boars at weight 6 and four boars at weight 4, on the same ground.
-- Ten stops in sixty spent on one fight under two names.
--
-- The Sounder is deleted. Nothing was moved onto this file to replace it, because there was nothing
-- to replace: one cast that was being drawn twice is now drawn once, and the weight it was drawn at
-- stays where it was. See tests/encounter_spec.lua for the rule that makes the pair unrepeatable.
local Band = require("models.band")

return {
    name = "Wild Boar",
    kind = "combat",
    -- The ordinary road fights carry the pool now that the elite no longer does. These four (boar,
    -- wolf, ogre, stag) were authored when an elite's weight was 1-2 and were correct then; once
    -- encounter_elite's weight climbed with prestige unchecked they were drowned, and capping it left
    -- the pool barely fight-heavy at all -- which matters because Overworld's combat-share CAP is meant
    -- to be what decides the mix, and a cap that does not bind decides nothing. Doubled together, so
    -- the relative mix the author chose (boar/wolf common, ogre/stag rarer) is untouched. Measured with
    -- `. board-report`: fights 4.05 -> 4.50 a board, guarded boons 51.5% -> 55.5%.
    weight = 6,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    -- LOCKED TO THE WOOD, which is the circle-lock rule arriving rather than a retune: humans
    -- float to every floor and everything else belongs to exactly one circle. This was shared
    -- road stock on all fifteen, and the beast band is Gluttony's identity now.
    condition = function(ctx) return ctx.biome == "forest" end,
    -- Enemy roster for the battle arena, rolled off the fight's own seed and scaled by the depth.
    -- Returns a flat list of data/characters ids (models/arena.lua binds them onto enemy spawn tiles).
    --
    -- THREE OR FOUR, which is what a sounder is and also all the room a skirmish has. The old curve
    -- (`2 + depth`) was pinned at that ceiling from floor two down anyway, so what the rewrite actually
    -- changed is not how many boars turn up -- it is that the number is now inside the tier, where a
    -- band has room to roll and the player can see it move (models/band.lua).
    composition = function(ctx)
        return Band.fill({}, ctx, "character_boar", { base = 3, min = 3, max = 4, per = 5 })
    end,
}
