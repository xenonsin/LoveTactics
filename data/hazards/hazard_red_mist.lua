-- The Red Mist (data/items/ability/ability_red_mist.lua): two turns of cloud, and anyone standing in it is Seeing
-- Red. Zone-bound -- Seeing Red does not linger -- so a body that is carried or shoved out of the mist comes back
-- to itself at once. Both sides: the goblins who stand in it lose their heads too.
return {
    name = "Red Mist",
    description = "Anyone inside is Seeing Red.",
    tags = { "curse" },
    duration = 10, -- two turns
    disposition = "hostile",
    onEnter = function(ctx)
        if not (ctx.unit and ctx.unit.alive) then return end
        ctx.applyStatus(ctx.unit, "status_seeing_red", { duration = 10 })
    end,
}
