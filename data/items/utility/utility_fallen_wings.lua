-- FALLEN WINGS: what holds the Abbess off the floor, and the only body on this stratum that is.
--
-- A passive keyed off the `flying` tag, which Combat.isFlying scans for at the two places movement is
-- decided -- so every tile costs her one whatever it is made of, and ground nobody can walk on opens up.
--
-- AND IT IS WORTH LESS HERE THAN IT LOOKS, WHICH IS WHY SHE MAY HAVE IT. The Thinwall Keep is a warren
-- of rooms (data/biomes/castle.lua) and flight does NOT open a wall -- a wall bars the way by being in
-- it, not by being poor footing (utility_zephyr_striders says so at length). What she actually buys is
-- that the keep's rubble, water and thresholds stop slowing her, so she reaches a doorway in the turn
-- she meant to. On open country this item is a map removed; in here it is a body that is never quite
-- where the walk order said it would be.
--
-- THE FLOCK DOES NOT HAVE IT, and the harpies are the reason to say so out loud. A harpy is the most
-- obviously airborne thing on the floor and crosses the ground like everybody else -- its wings are a
-- WEAPON on this stratum (weapon_stooping_gust), not a movement rule, and handing flight to four cheap
-- bodies would turn a fight about doorways into a fight with no doorways in it. One body on the
-- stratum ignores the floor, and she is the one the floor is named after.
--
-- Hazards still bite: fire on a tile burns a flier that stops over it, and the keep's disarming
-- thresholds spring the same. These lift her over the terrain, not out of the world.
--
-- A creature's kit: no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Fallen Wings",
    description = "Every tile costs one to cross, and no ground is impassable. Walls still stop you.",
    flavor = "They are not a bird's and not a bat's. They are the shape a painter uses when the subject is not to be pitied.",
    sprite = "assets/items/fallen_wings.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "flying" },
    noSteal = true,
}
