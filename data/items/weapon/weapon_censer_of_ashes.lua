-- The censer family read from the other side, and the extra a named censer owes its base
-- (docs/weapons.md): where data/items/weapon/weapon_censer.lua blesses the ground it walks, this one
-- chokes it (data/hazards/hazard_choking.lua) -- everyone in the smoke but the bearer's own side.
--
-- Both are the Cathedral's, and that is the point rather than an oddity. "The faithful arm those who
-- purge" is the shop's own line (data/vendors/vendor_cathedral.lua), and a faith with a punitive half
-- is the whole of what lust's shelf is: the same object, swung in blessing or in judgement, and nothing
-- about the censer itself changes between the two.
--
-- The extra is a change in how the weapon is PLAYED, which is what a good one always is. A supporting
-- weapon normally wants you tucked behind your line; this one only does anything where the enemy is
-- standing, so carrying it means walking your priest into them and staying there while they choke. The
-- walk is the attack. Nothing about the number is different.
--
-- And unlike the Blessing its counterpart hands out, Poison DECLARES `lingers` -- so what this cloud
-- gives is not a leash but a wound: it travels with the victim and keeps burning long after they have
-- fled it. You can walk out of a blessing. You cannot walk out of a lungful.
return {
    name = "Censer of Ashes",
    description = "Wreathes you in acrid smoke: foes standing beside you are Poisoned.",
    flavor = "The same rite, read aloud in a colder voice.",
    sprite = "assets/items/censer_of_ashes.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "poison", "melee" },
    class = "priest",
    price = 240,
    repRank = 3,
    incense = {
        hazard = "hazard_choking",
        radius = 1,
        amount = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
    },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- as feeble as its counterpart: the smoke is the weapon
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
