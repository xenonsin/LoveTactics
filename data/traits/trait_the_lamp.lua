-- THE LAMP: the Lamp's rule (utility_the_lamp). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- `grantsWishes` is what the Wishmaker asks for before every wish (Djinn.lampStands). Breaking it ends the
-- wishes, and takes Lamp-Bound off a Wishmaker who has already made her last one -- so she can fall again.
return {
    name = "The Lamp",
    description = "While it stands, the Wishmaker's wishes are granted.",
    grantsWishes = true,
    onDeath = function(ctx)
        require("models.djinn").lampBroken(ctx.combat, ctx.unit)
    end,
}
