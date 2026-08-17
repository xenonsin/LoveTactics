-- CONDUCTION: the Winter Hart lays freezing ground where it walks, and the tundra carries it.
--
-- The tundra's whole terrain identity is that ice costs nothing to cross and CONDUCTS -- a lightning
-- line that would clip one body on grass sweeps a whole frozen front (data/biomes/tundra.lua). So the
-- mythic body of this circle is the one that manufactures that ground, and the danger is not the animal
-- but where it has been.
--
-- Fires on onCast, so it pays for the ground with its turn: a Hart that spends the fight walking is not
-- also hitting you. Lays black ice, which is the biome's own signature hazard rather than a new one --
-- the circle should feel like more of its stratum, not like a different stratum arriving.
return {
    name = "Conduction",
    description = "Leaves black ice on the tile it is standing on as it acts.",
    onCast = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        ctx.placeHazard(u.x, u.y, "hazard_black_ice")
    end,
}
