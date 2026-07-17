-- A heavy blunt weapon: it hits, then it SHOVES. fx.knockback drives the target two tiles straight
-- back along the line from the wielder; if a wall, the board edge, or another unit stops it short,
-- everything involved in the collision takes the Power as impact damage. Slow (speed 4) and dear in
-- stamina -- you buy the displacement, not the damage.
return {
    name = "Iron Mace",
    description = "Drives the target back two tiles. A collision hurts everyone in it.",
    flavor = "You are not buying the damage. You are buying where they end up.",
    sprite = "assets/items/mace.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight", -- the Bastion's: displacement is the wall's trade, not wrath's (docs/classes.md)
    price = 190,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.knockback(fx.target, 2, { amount = fx.amount })
        end,
    },
}
