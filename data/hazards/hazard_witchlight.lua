-- Witchlight: burning ground-glass that throws a hard, colourless light. Anything standing in it is
-- Limned (data/status/status_limned.lua) -- lit up, and targetable however well it is hidden.
--
-- THE ANSWER TO HIDING. Invisibility, decoys and Stillshade all say "you may not aim at me", and until
-- this the game's only reply was to wait. This is ground somebody spent a slot carrying and a turn
-- throwing, and it works the way ground works: it is somewhere, it is not everywhere, and the rogue
-- gets to walk out of it. What the flare buys is not a reveal -- it is a REGION the enemy may not hide
-- in, which is a far more interesting thing to have to place well.
--
-- Sides nobody, and that is deliberate rather than an oversight: your own vanished assassin is lit by
-- it too. A light does not check heraldry, and the player who scatters flares carelessly through their
-- own line will find out what that costs.
--
-- Short. It is a flare, not a lamp -- long enough to force one exchange, and gone before it becomes a
-- permanent no-hiding zone the enemy simply has to route around forever.
return {
    name = "Witchlight",
    description = "Harsh light: nothing standing in it can hide from being targeted.",
    sprite = "assets/hazards/witchlight.png",
    tags = { "light" },
    duration = 10,           -- ~2 turns: one exchange's worth of being seen
    disposition = "hostile", -- the enemy AI would rather not be stood in it
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_limned")
    end,
}
