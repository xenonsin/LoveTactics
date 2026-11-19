-- THE WARCHIEF'S PRESENCE: the orc Warchief's organ, the elite's fight (approved as pitched, 2026-09-26, "The Orcs
-- of Wrath"). A foe that ends its turn beside him is Rooted; when he falls, the most-Proven orc takes his place,
-- heals half, and leads (trait_the_strongest_leads, models/succession.lua). The Presence was a +2 Damage aura
-- within 3 until 2026-11-19 (the creature identity pass): see the trait's header for why it holds you instead.
return {
    name = "Warchief's Presence",
    description = "A foe that ends its turn beside it is Rooted. When it falls, the most-Proven orc takes its place, heals, and leads.",
    flavor = "There is no heir. There is whoever is left standing with the most blood on them.",
    sprite = "assets/items/utility_warchiefs_presence.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_strongest_leads" },
}
