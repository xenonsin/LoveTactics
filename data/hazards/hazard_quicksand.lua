-- Quicksand: churned, sucking ground. A unit standing on it is Mired (data/status/mired.lua) -- the
-- inverse of Haste, doubling the time its casts and steps cost. Mired declares no `lingers`, so it is
-- ZONE-BOUND: the grant is stamped with this hazard's id as its `source`, and it clings only while the
-- unit is on the sand, lifting the instant it steps clear or the sand itself settles (Hazard.reap) --
-- exactly as a Sanctuary's Regeneration does.
--
-- Terrain the mage churns up with the Quicksand spell (data/items/ability/ability_quicksand.lua). It
-- lingers a good while and reads as HOSTILE to the enemy AI, which will step around a patch rather than
-- bog itself down -- so it doubles as area denial, funnelling foes onto firmer ground.
return {
    name = "Quicksand",
    description = "Sucking ground: doubles the movement and ability costs of any unit standing in it.",
    sprite = "assets/hazards/quicksand.png",
    tags = { "earth" },
    duration = 8,             -- ticks the churned ground persists
    disposition = "hostile",  -- the enemy AI steps around it
    onEnter = function(ctx)
        -- Mired does not declare `lingers`, so it is zone-bound: the grant is stamped with this hazard
        -- as its source automatically, and lifts the moment the unit steps onto firm ground or the sand
        -- itself settles.
        ctx.applyStatus(ctx.unit, "mired")
    end,
}
