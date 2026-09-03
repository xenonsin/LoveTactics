-- COMMON. The one relic on the rung that answers ATTRITION rather than a fight: a raised ceiling is
-- health the company keeps across the whole floor, where a heal is spent the moment it lands.
--
-- Uses maxBonus, which is folded into Combat.unreservedMax the same way utility_attunement's mana is --
-- so it raises the ceiling without touching what is currently in the pool, and a wound's own ceiling
-- (models/wound.lua) still bites underneath it.
return {
    name = "The Full Skin",
    blurb = "+%d maximum health for the whole company.",
    tier = "common", mark = "Sk",
    scale = { 6, 6 },
    maxBonus = { health = 6 },
}
