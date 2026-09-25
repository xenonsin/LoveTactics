-- THE HOARD FALLS OUT (round 1): when a Gold Golem falls it breaks into four coin heaps on the tiles
-- around it (Golem.spillHoard). The payout is on the board rather than a line on the victory screen --
-- and in its fight a dwarf crew comes up through the floor to race the company for the gold (round 2).
return {
    name = "The Hoard Falls Out",
    description = "When it falls, it breaks into four coin heaps.",
    onDeath = function(ctx)
        require("models.golem").spillHoard(ctx.combat, ctx.unit)
    end,
}
