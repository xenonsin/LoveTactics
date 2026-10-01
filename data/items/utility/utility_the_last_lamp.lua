-- THE LAST LAMP: the Wishmaker's drop. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- Her third wish, made small enough to carry: once a fight, falling below a third of its health turns the
-- bearer into a djinn for three turns (status_djinn_form) -- +4 magic damage, and a foe that comes next to it
-- sends it blinking clear, free (models/djinn.lua). It is the djinn's flight without the djinn's shame: a body in
-- the form that has nowhere to go simply stays. On the summoner's shelf, because a lamp is a thing you call out of.
return {
    name = "The Last Lamp",
    description = "Once a fight, below a third of your health: become a djinn for 3 turns. +4 magic damage; blink from foes beside you.",
    flavor = "Three wishes, and she spent all of them on herself. This is what was left in the bottom.",
    sprite = "assets/items/utility_the_last_lamp.png",
    type = "utility",
    tags = { "charm" },
    class = "summoner",
    unlockLevel = 14,
    unstocked = true,
    traits = { "trait_the_last_lamp" },
}
