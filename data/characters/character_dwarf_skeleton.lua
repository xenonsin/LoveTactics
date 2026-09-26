-- THE DWARF SKELETON: a Dwarf Delver that delved too deep, and came when Vesh called. Reviewed over three
-- rounds on 2026-09-25 ("The Dead Hand").
--
-- A DELVER STILL, AND DEAD. It extends character_dwarf_delver.lua the way the Skeleton Knight extends the
-- knight: the sprite (redrawn in bone), the class, the hammer and Delve are the living blueprint's, and so
-- is the race -- Stout (it cannot be moved, it cannot be robbed) and Inheritance. `undead = true` is what
-- happened to it (models/character.lua), and Bare Bones is the lattice and the bone picture.
--
-- WHAT DIED WITH IT IS THE WANT. "As skeletons they lose desire for gold": Stout's pull toward loose gold is
-- a rule the dead forget (trait_stout's `deadForget`), so it walks past a heap -- no pocket, no
-- Dragon-Sickness, never a wyrm. And no wages: the coffer is gone with the reason for it.
--
-- "It needs nothing more" was approved as written: a body that is hard to shift and arrives from below.
local base = require("data.characters.character_dwarf_delver")

local dead = {}
for k, v in pairs(base) do dead[k] = v end

dead.name = "Dwarf Skeleton"
dead.undead = true
dead.coffer = nil

dead.stats = {}
for k, v in pairs(base.stats) do dead.stats[k] = v end
-- Thin, on the Skeleton Knight's measured argument: the lattice is the identity and the pool is not.
dead.stats.health = 18

dead.startingItems = {
    "weapon_iron_hammer", "ability_delve", false,
    "utility_bare_bones", false,           false,
    false,                false,           false,
}
-- WHAT IT DROPS (round 3, all four approved): the want gone (the Hollow Helm), the nerves gone (Nerveless
-- Bones), the eyes that still see in the deep (the Skull-Lantern), and the arrival made a payoff (the Pick).
dead.drops = {
    "armor_hollow_helm", "utility_nerveless_bones", "utility_skull_lantern", "weapon_deep_delvers_pick",
}
-- No gilded preference: that was covetousness, and it died too. It goes under and comes up beside somebody.
dead.ai = {
    { priority = "normal", act = "cast", item = "ability_delve",
      when = { subject = "any_foe", test = "exists" } },
}

return dead
