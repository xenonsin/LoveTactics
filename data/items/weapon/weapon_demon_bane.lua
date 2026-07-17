-- Demon Bane: a consecrated blade that carries the `holy` tag on every swing. Holy is routed like
-- physical damage -- it scales off the wielder's Damage stat and is mitigated by Defense -- so any
-- fighter can carry it; the tag only matters where something is written to take (or shrug off) holy.
-- Demonic flesh resists it in the negative (data/items/utility/utility_demonic_essence.lua), so against the
-- Hollow Crown and its shades this cuts far deeper than the raw numbers suggest.
--
-- Sold at the Bastion, and a sword, which is what settles it: the Cathedral consecrates the steel but it
-- does not carry it -- the faithful bear no edge (docs/classes.md), and a knight holding a holy blade is
-- a crusader. The rank-3 answer on a shelf whose other blades only answer back.
return {
    name = "Demon Bane",
    description = "Deals holy damage. Demonic flesh takes far more.",
    flavor = "Holy arms are the Cathedral's to forge, and somebody else's to carry.",
    sprite = "assets/items/demon_bane.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "holy", "melee" },
    hands = 1,
    traits = { "trait_parry" }, -- a sword, so it parries (docs/weapons.md) -- and the counter carries `holy` too
    class = "knight",
    price = 260,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 9 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target) -- inherits the item tags, so the hit carries `holy`
        end,
    },
}
