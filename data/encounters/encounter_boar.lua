-- Encounter blueprint. Selection is dynamic: `weight` sets how likely this is
-- picked, `minPrestige` gates it behind player renown, and an optional
-- `condition(ctx)` can gate on biome/quest/etc. See models/encounter.lua.
-- `ctx = { prestige, biome, quest }`. Combat itself is a later system.
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
    minPrestige = 1,
    -- Enemy roster for the battle arena, scaled by prestige. Returns a flat list of
    -- data/characters ids (models/arena.lua binds them onto enemy spawn tiles).
    composition = function(ctx)
        local n = 2 + math.floor((ctx.prestige or 1) / 2)
        local list = {}
        for i = 1, n do list[i] = "character_boar" end
        return list
    end,
}
