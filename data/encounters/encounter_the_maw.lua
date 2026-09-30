-- Encounter blueprint. THE MAW: Gluttony's stop for INSATIABLE and WASTEFULNESS (reviewed in three rounds,
-- 2026-09-29). A mouth in the ground that eats what it is fed and gives back something better, and wants
-- more every time.
--
-- Feed it N pieces from the pack and they are destroyed; it hands back one sealed find a rung above the
-- best of them. N starts at 1 and climbs by one every feeding, for the whole save, and it never closes
-- (models/maw.lua keeps the count on the player; ui/panels/maw.lua is where the pieces are chosen).
--
-- `weight = 0`: never rolled. It is GUARANTEED once on Gluttony's first floor, on a dead end where the
-- board has one (Descent.SINS' gluttony `stops`). Unlike the Carcass and the Watering Hole it is NOT spent
-- by use: the cell stays open, because the only thing that closes an appetite is the price.
return {
    name = "The Maw",
    kind = "maw",
    weight = 0,
    depth = 1,
}
