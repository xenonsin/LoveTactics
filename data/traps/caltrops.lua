-- Caltrops: a spike trap for a fraction of the price, scattered rather than set. Same contract as
-- data/traps/spike_trap.lua and deliberately the lesser of the two on every axis -- a third of the
-- damage, a third of the HP -- because a spike trap costs a unit its turn to place ONE, while caltrops
-- are strewn free on every tile a walk crosses (Combat.layTrail). The trap that costs nothing must be
-- the weaker trap, or nobody would ever set the other.
--
-- What makes them worth carrying anyway is the count. A single caltrop barely stings; a corridor the
-- wearer has paced back and forth is a floor the enemy cannot cross without paying for every tile.
return {
    name = "Caltrops",
    description = "Scattered spikes: prick the first enemy to cross the tile, then are spent.",
    sprite = "assets/traps/caltrops.png",
    health = 2,                            -- brittle: a revealed caltrop is kicked aside by one blow
    tags = { "trap", "pierce", "physical" },
    damage = 6,                            -- pre-mitigation; a third of a spike trap's 18
    onTrigger = function(ctx)
        ctx.damage(ctx.victim, ctx.trap.amount or ctx.trap.def.damage, ctx.trap.tags)
    end,
}
