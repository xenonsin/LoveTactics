-- Quicksand: churned, sucking ground. A unit standing on it is Mired (data/status/mired.lua) -- the
-- inverse of Haste, doubling the time its casts and steps cost. The status is granted as an AURA
-- (tagged with this hazard's id as its `source`), so it clings only while the unit is on the sand and
-- lifts the instant it steps clear (Combat.updateAuras), exactly as a Sanctuary's Regeneration does.
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
        -- Tag the Mired status with its source so it ends the moment the unit steps off the sand
        -- (Combat.updateAuras), rather than lingering its full duration on firm ground.
        ctx.applyStatus(ctx.unit, "mired", { source = "hazard_quicksand" })
    end,
}
