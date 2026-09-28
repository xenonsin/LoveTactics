-- ERUPTION STONE: the Thunderhead's eruption, in a player's hand (models/storm.lua; "Fire, Lightning, and Dirty
-- Thunder", round 2, 2026-09-28). The first time the bearer drops to a third of its health, every tile beside it
-- turns to lava (Combat.openChasm at gap 1): an island no melee reaches -- the bearer's own healers included -- for
-- the rest of the fight. Only the lava; the storm's bolt at everyone standing in fire stays the storm's.
return {
    name = "Eruption Stone",
    description = "The first time you drop to a third of your health, every tile beside you turns to lava.",
    notAReaction = true,
    onDamaged = function(ctx)
        local u = ctx.unit
        if ctx.trait.spent or not (u and u.alive) then return end
        local hp = u.char.stats.health
        if hp.current > hp.max / 3 then return end
        ctx.trait.spent = true
        require("models.storm").erupt(ctx.combat, u, false)
    end,
}
