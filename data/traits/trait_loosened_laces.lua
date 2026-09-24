-- LOOSENED LACES's rule (data/items/utility/utility_loosened_laces.lua): in the Velvet Queen's presence
-- buckles work loose. Every foe within two tiles of the bearer has 2 less Defense -- a PRESENCE
-- (Trait.liveBonus), read on the foe's own stat path, so the whole company's blows see it.
return {
    name = "Loosened Laces",
    description = "Foes within 2 tiles of you have -2 Defense.",
    presence = { radius = 2, defense = -2 },
}
