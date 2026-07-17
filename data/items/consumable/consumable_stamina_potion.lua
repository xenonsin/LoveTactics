-- A bitter cordial that puts the wind back in a spent body. The cheapest flask on the shelf,
-- because stamina is the kindest pool in the game -- it comes back on its own every tick
-- (`staminaRegen`), so buying it back is buying TIME rather than a resource you had lost for good.
--
-- Which is exactly when it is worth carrying: the fighter who has emptied their bar into an Omnislash
-- and wants to swing again THIS turn, or the duelist whose parry has priced itself out of the exchange
-- mid-flurry. Nothing here is unavailable to patience; all of it is unavailable to urgency.
return {
    name = "Stamina Potion",
    description = "Restores stamina to an ally.",
    flavor = "Nothing it buys is unavailable to patience. All of it is unavailable to urgency.",
    sprite = "assets/items/stamina_potion.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 30,
    repRank = 1,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        support = true,
        range = 1,
        speed = 2,
        consumesItem = true,
        restore = { 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45 }, -- the stamina returned
        restoreStat = "stamina",
        effect = function(fx)
            fx.restore(fx.target, "stamina", fx.amount)
        end,
    },
}
