-- The cold in a dead thing's flesh: the whole of what makes a corpse a corpse, as far as this game's
-- rules are concerned. Not sold, not stolen, not carried by anything with a pulse -- it exists so the
-- undead have somewhere to keep data/traits/trait_grave_cold.lua, exactly as the Gaunt Vigil's ward
-- exists so the vigil has something to object with (data/items/utility/utility_vigil_ward.lua).
--
-- It lives on an ITEM because that is the only door a trait comes through: Character.instantiate builds
-- its runtime table by an explicit field whitelist and never copies a blueprint's own `traits` list, so
-- a trait written onto data/characters/character_zombie.lua would load, pass every schema check, and do
-- nothing at all. The grid is the delivery mechanism for every innate in the game.
--
-- Unpriced and classless, so no vendor stocks it, no growth tally counts it and no loot roll can drop
-- it; `noSteal` keeps a thief from lifting the fact of somebody's death out of their pockets.
return {
    name = "Grave-Cold",
    description = "Every heal aimed at this body wounds it for the same amount instead.",
    flavor = "The Arcanum's first lesson on the raised: do not send the priest. Send another shovel.",
    sprite = "assets/items/utility_grave_cold.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "dark" },
    noSteal = true, -- it is what the body IS, not equipment
    traits = { "trait_grave_cold" },
}
