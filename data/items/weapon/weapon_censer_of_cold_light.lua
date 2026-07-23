-- A censer, so the smoke is the weapon (docs/weapons.md). Its cloud is hazard_witchlight -- harsh light
-- in which nothing standing can hide from being targeted.
--
-- A walking lamp, and the party's answer to a stealth warband. Every other anti-stealth tool in the game
-- is a shot that has to be aimed at something you can already see, which is the shape of the problem:
-- you cannot target the assassin in order to reveal it. This does not target anything. The priest walks,
-- and the square they are in is simply a place where hiding does not work -- so an invisible body that
-- wants to reach your back line has to come through a square that will give it away.
--
-- It is area denial the enemy cannot shoot out, because it is attached to a person rather than to a
-- tile, and that is the whole argument for putting the effect on a censer rather than on the Witchlight
-- Bow's arrow (data/items/weapon/weapon_witchlight_bow.lua): the bow lights a square and this lights
-- wherever the fight went.
--
-- Unsided, as ground generally is: your own rogue is exactly as visible in it, which is a real conflict
-- in a party running both.
return {
    name = "Censer of Cold Light",
    description = "Wreathes you in harsh light: nothing standing near you can hide from being targeted.",
    flavor = "It gives off no heat and casts no shadow, and the Cathedral's censer-bearers do not like carrying it.",
    sprite = "assets/items/censer_cold_light.png",
    type = "weapon",
    tags = { "censer", "impact", "physical", "light", "melee" },
    class = "priest",
    price = 480,
    repRank = 4,
    incense = {
        hazard = "hazard_witchlight",
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
