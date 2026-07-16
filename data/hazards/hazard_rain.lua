-- Rain: a soaking downpour. A unit entering it is left Wet (data/status/wet.lua), which makes it take
-- extra damage from lightning -- soak a cluster of foes, then Jolt them. The cloud lingers for a
-- duration. Neutral to the AI: being wet only matters if a lightning attacker is around, so enemies
-- neither seek nor shun it. Summoned by the mage's Rain spell (data/items/ability/ability_rain.lua),
-- which -- being water-tagged -- also douses any fire it falls on.
return {
    name = "Rain",
    description = "Soaking downpour: leaves those who enter Wet, and conducts lightning.",
    sprite = "assets/hazards/rain.png",
    -- "water" douses fire (Hazard.douse); "conductable" makes the drenched ground itself carry a
    -- charge, so a bolt landing beside the cloud arcs through it (Combat.tileHasTag).
    tags = { "water", "conductable" },
    duration = 5,
    disposition = "neutral",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "wet")
    end,
}
