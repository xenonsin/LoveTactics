-- The Gaunt Vigil's ward: the iron figure's entire kit, and the reason it is worth planting. Not sold,
-- not stolen, not carried by anything with hands -- it exists so the vigil has something to object
-- with, exactly as a wolf's fangs exist so the wolf has something to bite with.
--
-- It carries data/traits/trait_gaunt_vigil.lua and nothing else: no active, no bonus, no ability. The
-- vigil takes no turns (it is summoned control-"none" and `timeless`), so an ability would never fire,
-- and the whole of its effect rides on somebody ELSE's cast through the onAnyCast broadcast.
--
-- Unpriced and classless, so no vendor stocks it, no growth tally counts it, and `noSteal` keeps a
-- thief from lifting the one thing that makes the object mean anything.
return {
    name = "Vigil's Ward",
    description = "Bites anyone who works a spell within reach of the vigil.",
    flavor = "Whatever is inside the iron was told to watch. Nobody remembers telling it what for.",
    sprite = "assets/items/utility_vigil_ward.png",
    type = "utility",
    tags = { "dark" },
    noSteal = true, -- it is part of the vigil, not equipment
    traits = { "trait_gaunt_vigil" },
}
