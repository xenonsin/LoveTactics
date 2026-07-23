-- Zealous Charge: the fighter half of the Crusader. A holy rush that heals harder the deeper into the
-- mob it lands -- the faith that mends by wading in, not by standing back. The heal scales with the
-- number of enemies adjacent to the Crusader after the blow, so it rewards being surrounded, which is
-- exactly where wrath wants a holy warrior to be.
return {
    name = "Zealous Charge",
    description = "A holy strike that heals you more for every enemy adjacent to you.",
    flavor = "The saints did not retreat to pray. They prayed with their backs to nothing.",
    sprite = "assets/items/ability_zealous_charge.png",
    type = "ability",
    tags = { "holy", "slash" },
    class = "fighter",
    discipline = "crusader", -- fighter x priest; the Smite mechanic's first stock
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        healing = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, -- fx.amount: healed PER adjacent enemy
        effect = function(fx)
            fx.damage(fx.target)
            local enemies = 0
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.alive and u.side ~= fx.user.side then enemies = enemies + 1 end
            end
            if enemies > 0 then fx.heal(fx.user, fx.amount * enemies) end
        end,
    },
}
