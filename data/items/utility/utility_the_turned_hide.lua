-- THE TURNED HIDE: the curse worn as a skin, and the ground it leaves behind it.
--
-- The whole of this item is one line -- `trail` -- and that line is the Turning's third mechanic. Any
-- item in the grid carrying `trail = { hazard, duration }` has it laid by Combat.layTrail, called from
-- Combat.enterTile on every walked or forced step (the seam utility_cinderstride_boots, the Tidewalker
-- Boots and the Pilgrim's Sandals already ride). No trait, no hook, no turn spent: the ground he crosses
-- takes the curse because crossing it is what he is.
--
-- ON THE HIDE RATHER THAN ON THE WEAPON, for two reasons that both matter. It is what the thing IS
-- rather than what it does -- and a weapon can be disarmed, which would take the trail off the board
-- along with the blow and quietly delete half the fight for the price of one status.
--
-- The duration is shorter than the curse's own 25 (data/hazards/hazard_curse.lua) and that is the
-- distinction between the two ways this fight lays ground. What a dead boar leaves is a MONUMENT: it
-- sits there for the rest of the fight, because you chose to kill something on that tile. What he
-- leaves walking is a WAKE -- it closes behind him, because otherwise a body with five movement paints
-- the entire arena in three turns and the fight stops being about where anybody stands.
--
-- `bound` is deliberately NOT set: this is not the signature relic (that is utility_the_iron_in_him, on
-- the body this one replaced), and there is nothing here worth locking a centre cell for.
return {
    name = "The Turned Hide",
    description = "The ground it crosses takes the curse.",
    flavor = "Whatever is on the outside of it now, this used to be the outside of a boar.",
    sprite = "assets/items/utility_the_turned_hide.png",
    type = "utility",
    class = "creature",
    tags = { "dark" },
    noSteal = true,
    trail = { hazard = "hazard_curse", duration = 10 },
}
