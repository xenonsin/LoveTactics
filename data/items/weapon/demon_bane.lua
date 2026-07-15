-- Demon Bane: a consecrated blade that carries the `holy` tag on every swing. Holy is routed like
-- physical damage -- it scales off the wielder's Damage stat and is mitigated by Defense -- so any
-- fighter can carry it; the tag only matters where something is written to take (or shrug off) holy.
-- Demonic flesh resists it in the negative (data/items/utility/demonic_essence.lua), so against the
-- Hollow Crown and its shades this cuts far deeper than the raw numbers suggest.
--
-- Sold at the Cathedral: holy arms are the priesthood's to forge, whoever ends up wielding them.
return {
    name = "Demon Bane",
    description = "A consecrated sword. Its blows are holy -- and the damned feel them tenfold.",
    sprite = "assets/items/demon_bane.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "holy", "melee" },
    class = "priest",
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
