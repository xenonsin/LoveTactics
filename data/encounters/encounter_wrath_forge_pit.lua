-- THE FORGE PIT: the Forge-Wretch, and the fight that teaches Kindling.
--
-- The wretch sharpens with every blow it takes, up to a ceiling. The kin beside it are there to make
-- chipping tempting -- there is always something else worth hitting -- which is exactly the mistake the
-- wretch is priced against. Commit and it dies before it matters; spread your damage and you build it.
--
-- Two wretches on purpose at depth: the lesson lands harder when the second one is already sharp.
return {
    name = "The Forge Pit",
    kind = "combat",
    weight = 4,
    minDay = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_forge_wretch", "character_cinder_kin" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_forge_wretch"
        end
        return list
    end,
}
