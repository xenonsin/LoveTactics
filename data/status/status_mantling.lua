-- MANTLING: the hawk hunched over its kill, wings spread to hide it -- falconry's own word. Worn by the HAWK
-- (data/traits/trait_mantling.lua) while its prey wears status_mantled. It cannot walk off the body and
-- cannot dodge anything thrown at it: it is eating, and eating is all it is doing.
--
-- It ends the moment anything hits the hawk (the trait's onDamaged), or when either body falls.
return {
    name = "Mantling",
    abbr = "Mnt",
    description = "Hunched over its prey: it cannot move and cannot dodge.",
    color = { 0.520, 0.380, 0.250 }, -- badge tint (feather brown)
    duration = 999,
    hideDuration = true,
    blocksMove = true,
    statBonus = { avoid = -100 },
}
