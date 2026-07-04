-- Encounter blueprint. Selection is dynamic: `weight` sets how likely this is
-- picked, `minPrestige` gates it behind player renown, and an optional
-- `condition(ctx)` can gate on biome/quest/etc. See models/encounter.lua.
-- `ctx = { prestige, biome, quest }`. Combat itself is a later system.
return {
    name = "Wild Boar",
    kind = "combat",
    weight = 3,
    minPrestige = 1,
    -- Enemy roster for the battle arena, scaled by prestige. Returns a flat list of
    -- data/characters ids (models/arena.lua binds them onto enemy spawn tiles).
    composition = function(ctx)
        local n = 2 + math.floor((ctx.prestige or 1) / 2)
        local list = {}
        for i = 1, n do list[i] = "boar" end
        return list
    end,
}
