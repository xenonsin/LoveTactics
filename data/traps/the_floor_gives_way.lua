-- THE FLOOR GIVES WAY: a mine that is a hole (data/items/ability/ability_the_floor_gives_way.lua; slice D). The
-- Hollow Crown drops the board's edge into the Pit; carried out, the bombardier digs the Pit under one tile and hides
-- it. The first foe across it falls through: a heavy impact, and Rooted at the bottom.
--
-- THE BEAR TRAP DOES BOTH HALVES TOO (data/traps/bear_trap.lua, a trapper's): bite and Root. This is the same shape
-- at the bottom of the rift's weight -- twice the bear trap's bite, impact rather than pierce -- and it lives on the
-- Crucible's rack, not the Lodge's, because it is powder and a hole rather than steel jaws.
return {
    name = "The Floor Gives Way",
    description = "A hidden hole: the first enemy across it falls through, takes heavy impact damage and is Rooted.",
    sprite = "assets/traps/the_floor_gives_way.png",
    health = 6,
    tags = { "trap", "impact", "physical" },
    damage = 24, -- pre-mitigation; twice the bear trap's, which is what the bottom of the rift pays
    onTrigger = function(ctx)
        ctx.damage(ctx.victim, ctx.trap.amount or ctx.trap.def.damage, ctx.trap.tags)
        ctx.applyStatus(ctx.victim, "status_root")
    end,
}
