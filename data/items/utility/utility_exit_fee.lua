-- EXIT FEE: the Tollkeepers' organ ("Sloth's Bestiary", 2026-10-04, slice F), carried by every one of them, Mora
-- included (models/toll.lua). Three rules of the line, one per trait:
--   Exit Fee          a foe that walks out of its reach is struck on the way out; coming in is free
--   Barred            an impact blow breaks its brace -- the Bailiff's gate is opened with a hammer
--   What It Was Owed  when it falls, the Due climbs out of it and goes for its killer
-- Creature kit: bound, unstealable, on no shelf.
return {
    name = "Exit Fee",
    description = "Strikes a foe that walks out of its reach. An impact blow breaks its brace. When it falls, a Due climbs out.",
    flavor = "Coming in is free. Everyone says so, on the way in.",
    sprite = "assets/items/utility_exit_fee.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_exit_fee", "trait_barred", "trait_what_it_was_owed" },
}
