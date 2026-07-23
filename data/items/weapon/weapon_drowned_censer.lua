-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_rain -- everything that
-- walks through it is left Wet, and the ground it covers conducts.
--
-- Quest-only: `class` with no `price`.
--
-- The one UNSIDED censer, and that is its whole character. Every other cloud in the family declares a
-- side: incense blesses allies, choking smoke poisons enemies, muster does both by asking who is
-- standing there. Rain does not ask. It soaks whoever is in it, and what that is worth depends entirely
-- on who brought what -- Wet is +6 from lightning and ice, -6 against fire (data/status/status_wet.lua).
--
-- So it is a censer whose value is decided by the rest of the roster rather than by the priest. Carried
-- alongside data/items/weapon/weapon_conductor.lua it is the best item on the shelf: the priest walks
-- into the enemy line, soaks the whole formation, and the mage collects on all of it from range. Carried
-- alongside a fire mage it is actively harmful, since the enemy now resists the party's damage.
--
-- The third rung of the water chain that runs across three shelves -- the Wetstone Mace soaks one and
-- shocks it, Tidesbreak soaks a rank, and this soaks whatever the priest walks past for as long as they
-- keep walking.
return {
    name = "The Drowned Censer",
    description = "Wreathes you in rain: everything near you is left soaked, whichever side it is on.",
    flavor = "It has not been dry since it was made. The Cathedral stopped trying some time ago.",
    sprite = "assets/items/drowned_censer.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "water", "melee" },
    class = "priest",
    incense = {
        hazard = "hazard_rain",
        radius = 1,
        amount = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
