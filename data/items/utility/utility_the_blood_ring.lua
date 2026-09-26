-- THE BLOOD RING: the orc Pit-Fighter's organ, the alpha's fight (approved as pitched, 2026-09-26, "The Orcs of
-- Wrath"). Its orcs line the edge and shove back anyone who ends a turn beside them; it takes half damage from
-- all but its challenger; when a body falls, one of the crowd steps in (trait_the_blood_ring).
return {
    name = "The Blood Ring",
    description = "Its crowd shoves back whoever ends a turn beside it and joins when a body falls. Takes half from all but its challenger.",
    flavor = "Nobody leaves the ring. The crowd has come to see that, and it will see it.",
    sprite = "assets/items/utility_the_blood_ring.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_blood_ring" },
}
