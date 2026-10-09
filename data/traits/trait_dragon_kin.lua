-- DRAGON-KIN: the kobold beastmaster's race item (data/items/utility/utility_dragon_kin.lua, "The Rift's
-- Adventurers", slice D). A creature the bearer summoned (never a planted object) counts as a dragon on its
-- side (Devotion.isDragon), so the bearer and every devout kobold near it fight under the Dragon's Eye
-- (trait_devotion). It is a dragon to look at and nothing more: a struck or fallen beast is not the Godling,
-- and rallies or forsakes nobody (those ride the dragon's own trait_dragonkin).
return {
    name = "Dragon-Kin",
    description = "Your bonded beast counts as a dragon on your side.",
    beastIsDragon = true,
}
