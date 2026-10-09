-- NEVER FULL: the Hungry Ghost's rule (data/items/utility/utility_never_full.lua). Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E): "Any heal or draught that lands on a body within 2 tiles of a Hungry Ghost is
-- eaten: the ghost gets it instead."
--
-- Any body, of either side: the ghost does not care whose meal it is. Eaten in Combat.applyHeal, the one funnel
-- every heal runs through, beside the Gallows Seed (models/lethe.lua).
return {
    name = "Never Full",
    description = "Heals that land within 2 heal this body instead.",
    eatsHeals = true,
    radius = 2,
}
