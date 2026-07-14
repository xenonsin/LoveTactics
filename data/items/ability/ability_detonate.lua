-- Detonate: set off the poison or fire already eating a foe. If the target is Burned or Poisoned, the
-- affliction erupts into a small blast -- everything around it takes double, and the target's DoT is
-- consumed in the blast. With no affliction to touch off it is only a weak bolt. Rewards a party that
-- has stacked its damage-over-time first.
return {
    name = "Detonate",
    description = "Detonate the poison or fire on a foe into an area blast, consuming it. Weak with no affliction to set off.",
    sprite = "assets/items/ability_detonate.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mage",
    price = 280,
    repRank = 3,
    activeAbility = {
        name = "Detonate",
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        damage = { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if fx.hasStatus(t, "burn") or fx.hasStatus(t, "poison") then
                for _, u in ipairs(fx.aoeUnits()) do
                    fx.damage(u, { amount = fx.amount * 2 })
                end
                fx.clearStatus(t, "burn")
                fx.clearStatus(t, "poison")
            else
                fx.damage(t) -- nothing to set off: a single weak bolt
            end
        end,
    },
}
