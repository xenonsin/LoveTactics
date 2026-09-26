-- THE WARCHIEF'S PRESENCE: the orc Warchief's organ, the elite's fight (approved as pitched, 2026-09-26, "The Orcs
-- of Wrath"). Allies within 3 deal +2 Damage; when he falls, the most-Proven orc takes his place, heals half, and
-- leads (trait_the_strongest_leads, models/succession.lua).
return {
    name = "Warchief's Presence",
    description = "Allies within 3 deal 2 more damage. When it falls, the most-Proven orc takes its place, heals, and leads.",
    flavor = "There is no heir. There is whoever is left standing with the most blood on them.",
    sprite = "assets/items/utility_warchiefs_presence.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_strongest_leads" },
}
