-- Totem-Carver's Kit: the standing rule of the Totemist's charm of the same name. Everything the bearer
-- plants stands up with more health than it was written with, and keeps it.
--
-- A flag (Trait.flag) read by Combat.summonRiders. It raises the ceiling AND fills it, so the totem
-- arrives with the health rather than arriving wounded inside a larger body -- a distinction that only
-- shows up when somebody forgets to do it.
--
-- This is the whole answer to what a Totemist actually fears. A totem is control-"none" and timeless:
-- it never moves, never strikes, never takes a turn, and holds its zone open purely by continuing to
-- exist. Twenty-four health is two swings. The discipline's real vulnerability was never its damage,
-- it was that the enemy could delete the build by walking over and hitting a post twice.
--
-- Written against `summoned` generally rather than against totems, the same way the Beastlord's Bond is
-- -- so a Totemist who also fields a wolf gets a tougher wolf, and nothing here has to know it.
return {
    name = "Totem-Carver's Kit",
    magnitude = 16, -- extra health, on top of whatever the summoning ability scaled it to
    bolstersSummons = true,
}
