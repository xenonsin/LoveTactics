-- TAPAS BEADS: the asura's stillness, for a company monk (Descent.DROPS; models/asura.lua). Gather -- the
-- Centering Charm's coil -- also banks 2 chi, so a monk can wait its way up to an Asura Strike and carry the
-- Empowered blow into it. Does nothing without a Gather to spend it on. Tapas is the heat the asura built up
-- through austerity, and then spent on war.
return {
    name = "Tapas Beads",
    description = "Gather also gains 2 chi.",
    flavor = "Counted a thousand times, and every time the count came out hotter.",
    sprite = "assets/items/utility_tapas_beads.png",
    type = "utility",
    tags = { "fist" },
    class = "monk",
    unstocked = true,
    unlockLevel = 8,
    gatherCharge = 2,
}
