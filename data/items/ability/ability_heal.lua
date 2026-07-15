-- A restorative ability: channels light to mend an ally at range for a Power-scaled heal.
-- Reuses the shared fx.heal helper (see data/items/consumable/healing_potion.lua), but as a
-- repeatable mana spell rather than a one-shot consumable -- the priest's signature.
return {
    name = "Heal",
    description = "Channel restorative light to mend a nearby ally.",
    sprite = "assets/items/ability_heal.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    price = 140,
    repRank = 2,
    activeAbility = {
        target = "ally", -- includes the caster (a unit is its own ally)
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 10 },
        healing = { 24, 26, 29, 31, 34, 36, 38, 41, 43, 46, 48 }, -- HP restored; Power is the balance knob for the heal
        effect = function(fx)
            fx.heal(fx.target, fx.amount) -- restore Power HP via the shared heal helper
        end,
    },
}
