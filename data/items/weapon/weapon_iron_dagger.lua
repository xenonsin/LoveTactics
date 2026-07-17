-- The dagger archetype: fast, cheap, and it opens a wound (docs/weapons.md). Two things define every
-- dagger -- a very low `speed`, so the wielder comes back around the timeline almost at once, and
-- Bleed (data/status/bleed.lua) on the hit.
--
-- The bleed is the point, and it is why the dagger's own damage can afford to be modest. It taxes the
-- victim for every tile it walks: a knifed foe that wants to disengage, chase, or reposition pays for
-- the privilege in blood, and one that stays put to avoid paying has been pinned in place without a
-- root. The rogue's answer to a runner.
--
-- The Undercroft's entry-rank blade; data/items/weapon/weapon_kingsblood_dagger.lua is the rank-4 version of
-- this same idea, faster still and far dearer.
return {
    name = "Iron Dagger",
    description = "Deals damage and inflicts Bleed, which taxes every tile the victim walks.",
    flavor = "The Undercroft's first blade. It does not need to kill you; it only needs you to keep moving.",
    sprite = "assets/items/dagger.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    price = 70,
    repRank = 1,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick: you act again long before a swordsman does
        cost = { stat = "stamina", amount = 5 },
        damage = { 5, 5, 6, 7, 7, 8, 9, 9, 10, 11, 12 }, -- modest: the wound does the rest of the work
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_bleed")
        end,
    },
}
