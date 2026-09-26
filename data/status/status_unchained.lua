-- UNCHAINED: the War Ogre with its Handler dead (data/traits/trait_the_chain.lua). More damage, and each turn it
-- attacks the nearest body, whichever side it is on (models/rampage.lua). The trait hands in the statBonus at
-- half the ogre's own Damage.
return {
    name = "Unchained",
    abbr = "Unch",
    description = "Unchained: increase damage. It attacks the nearest body, whichever side it is on.",
    color = { 0.700, 0.300, 0.200 }, -- badge tint (raw)
    duration = math.huge,
    hideDuration = true,
}
