-- Harrying Strike: the fighter half of the Skirmisher (fighter x hunter). Hit, then be somewhere else:
-- the blow lands and the striker immediately slips back a tile (fx.retreat). Never standing where you
-- swung is the whole hit-and-run doctrine -- wrath's aggression carried on the hunter's feet, so a
-- charge answered finds nothing where the charger was.
return {
    name = "Harrying Strike",
    description = "Strikes a foe, then slips back a tile out of reach.",
    flavor = "The Lodge does not teach the blow. It teaches the step after it.",
    sprite = "assets/items/ability_harrying_strike.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    discipline = "skirmisher", -- fighter x hunter; the Hit-and-run mechanic's first stock
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.retreat(fx.user, 1)
        end,
    },
}
