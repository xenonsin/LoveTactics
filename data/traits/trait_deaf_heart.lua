-- DEAF HEART's rule (data/items/utility/utility_deaf_heart.lua): a PRESENCE over foes within two tiles,
-- carrying `deafens` rather than a stat. Status.deafToAllies reads it at the heal, the buff and the
-- cleanse, so each of those three doors is shut to a foe standing near the bearer.
return {
    name = "Deaf Heart",
    description = "Foes within 2 tiles of you cannot be healed, buffed or cleansed by their allies.",
    presence = { radius = 2, deafens = true },
}
