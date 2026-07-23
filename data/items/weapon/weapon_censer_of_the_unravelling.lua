-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_unravelling -- picked-loose
-- ground in which everything takes more from every magical hit.
--
-- Quest-only: `class` with no `price`.
--
-- The censer for a party built around the Arcanum, and the most dangerous one to carry. A priest walking
-- with this is a mobile amplifier: wherever they stand, the mage's spells land harder, and the priest can
-- put that square wherever the fight actually went instead of where it was when the mage cast.
--
-- INCLUDING ON YOU, which is the cost and is not a small one. The smoke is unsided and it is centred on
-- the priest, so the priest is permanently standing in a square where magic hurts more -- and so is
-- everyone standing beside the priest, which in most formations is the whole line. Against an enemy with
-- no casters it is free. Against an enemy mage it is a way to lose the party.
--
-- Read against data/items/weapon/weapon_unravelling_shaft.lua, which lays the same ground from five tiles
-- away and never has to stand in it. That one is safe and static; this one is mobile and suicidal, and
-- the difference is the whole reason both are worth having.
return {
    name = "Censer of the Unravelling",
    description = "Wreathes you in picked-loose air: everything near you takes more from magic. Including you.",
    flavor = "The Arcanum lent it to the Cathedral, once, and has been notably polite about it ever since.",
    sprite = "assets/items/censer_unravelling.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "arcane", "melee" },
    class = "priest",
    incense = {
        hazard = "hazard_unravelling",
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
