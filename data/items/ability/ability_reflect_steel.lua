-- Reflect Steel: the physical twin of ability_reflect_magic.lua. Lay a mirror on yourself or a nearby
-- ally and, for the window, single-target physical blows aimed at them rebound onto the attacker
-- (data/status/reflect_physical.lua).
--
-- Sold by the PRIEST rather than the mage, which is the deliberate half of this. The priest's shelf is
-- already where warding lives -- both Barriers, Aegis, Sanctuary -- and it is the class whose whole
-- answer to violence is to make violence not work. Handing the steel mirror to the mage instead would
-- have made the mage the answer to every school at once; this way each ward sits with the class that
-- has to walk into the thing it wards against.
--
-- Costlier and shorter-lived than its arcane twin (see the duration note in the status), because
-- almost every physical attack in the game is single-target and so almost every physical attack is
-- something this answers. Against an enemy line of swords it is the strongest ward in the game for six
-- ticks; against an archer who simply waits it out, it is twenty-six mana and a turn.
return {
    name = "Reflect Steel",
    description = "Mirrors an ally for a time: single-target physical blows rebound onto the attacker.",
    flavor = "Each ward sits with the class that has to walk into the thing it wards against.",
    sprite = "assets/items/ability_reflect_steel.png",
    type = "ability",
    tags = { "holy", "protective" },
    class = "priest",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "ally", -- includes the caster (a unit is its own ally)
        support = true,
        range = 2,
        speed = 8,
        cost = { stat = "mana", amount = 26 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_reflect_physical")
        end,
    },
}
