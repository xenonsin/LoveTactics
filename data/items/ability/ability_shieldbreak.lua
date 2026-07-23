-- Shieldbreak: the Vanguard (knight x rogue) does not hold a line, it breaks one. A shoving blow that
-- knocks a foe back two tiles and leaves it Sundered (data/status/status_sundered.lua) -- every guard,
-- reflex and trait it carries goes quiet -- punching a hole the party pours through. The knight half of
-- Breach: sloth's wall mechanics turned outward, against someone else's wall.
return {
    name = "Shieldbreak",
    description = "Knocks a foe back and Sunders it: its guards, reflexes and traits fall silent.",
    flavor = "A shield is only worth what the arm behind it still believes. This unteaches the belief.",
    sprite = "assets/items/ability_shieldbreak.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "knight",
    discipline = "vanguard", -- knight x rogue; the Breach mechanic's first stock
    price = 280,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.knockback(fx.target, 2, { amount = 0 })
            fx.applyStatus(fx.target, "status_sundered")
        end,
    },
}
