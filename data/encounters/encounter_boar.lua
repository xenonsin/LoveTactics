-- Encounter blueprint. Selection is dynamic: `weight` sets how likely this is
-- picked, `depth` gates it behind how far into the campaign the road is, and an optional
-- `condition(ctx)` can gate on biome/quest/etc. See models/encounter.lua.
-- `ctx = { day, biome, quest }`. Combat itself is a later system.
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
    -- Enemy roster for the battle arena, scaled by the campaign day. Returns a flat list of
    -- data/characters ids (models/arena.lua binds them onto enemy spawn tiles).
    composition = function(ctx)
        local n = 2 + math.floor((ctx.depth or 1) / 1)
        local list = {}
        for i = 1, n do list[i] = "character_boar" end
        return list
    end,
}
