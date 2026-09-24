-- Lead the Wind: the Alpha Wyvern's, and the thing that makes it the kill order -- the Alpha Wolf's Pack
-- Presence told in wind. Every wyvern within `radius` of it is `avoid` harder to hit, on top of its own
-- Tailwind, and keeps it even with a foe standing beside it.
--
-- A FLAG, answered on the RECEIVING body (trait_tailwind reads it off whoever is near): a live bonus is a
-- claim about the body being shot at, so it is asked there. Gone the instant the alpha falls or goes
-- Aloft -- the wind it leads is the wind it is flying in -- and silenced by Sunder like any flag.
return {
    name = "Lead the Wind",
    description = "Wyverns within 3 tiles gain +15 Avoid, even with a foe adjacent.",
    leadsTheWind = true,
    radius = 3,
    avoid = 15,
}
