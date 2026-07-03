-- Encounter blueprint. Selection is dynamic: `weight` sets how likely this is
-- picked, `minPrestige` gates it behind player renown, and an optional
-- `condition(ctx)` can gate on biome/quest/etc. See models/encounter.lua.
-- `ctx = { prestige, biome, quest }`. Combat itself is a later system.
return {
    name = "Wild Boar",
    kind = "combat",
    weight = 3,
    minPrestige = 1,
}
