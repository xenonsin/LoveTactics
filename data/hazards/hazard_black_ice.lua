-- Black Ice: a sheet of it, clear enough that the ground looks bare. Anything that finds it is
-- Crippled -- slowed to a crawl for as long as it stands there.
--
-- The terrain twin of Rimeguard (data/hazards/hazard_rimeguard.lua), and it differs in the one way that
-- matters: Rimeguard is a knight's aura and is SIDED, sparing the line it forms around. This is ground.
-- It has no owner and no allegiance, so it cripples whoever is standing on it, and a party that routes
-- carelessly through its own tundra pays exactly what the enemy pays.
--
-- Cripple, not Root or Mired, because of the floor it is seeded onto. The tundra's `ice` is the one
-- terrain feature that costs nothing extra to cross (models/arena.lua), so a tundra board has no
-- movement obstacles on it at all -- which leaves nothing for a route to be chosen around. This is that
-- something. A hazard that stopped a unit outright would cancel the biome's speed rather than shape it,
-- and one that taxed casts would be answered by not casting; slowing whoever crosses it makes the ROUTE
-- across an otherwise open field the decision, rather than the distance.
--
-- Zone-bound: Cripple declares no `lingers`, so the grant is stamped with this hazard as its source and
-- lifts the moment the unit steps onto honest snow (Hazard.reap). You do not carry black ice with you.
return {
    name = "Black Ice",
    description = "Inflicts Cripple on units standing on it.",
    tags = { "ice" },
    duration = 24,           -- ~5 turns: terrain outlasts a cast-made zone, because nobody made it
    disposition = "hostile", -- the enemy AI paths around it rather than across
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_cripple")
    end,
}
