-- A restorative ability: channels light to mend an ally at range for a Power-scaled heal.
-- Reuses the shared fx.heal helper (see data/items/consumable/consumable_healing_potion.lua), but as a
-- repeatable mana spell rather than a one-shot consumable -- the priest's signature.
return {
    name = "Heal",
    description = "Mends a nearby ally.",
    flavor = "The Cathedral's whole reputation, restored one body at a time.",
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
        -- How a unit that isn't being driven by a player uses this (models/ai.lua). The rule travels
        -- WITH the item: drop Heal into any NPC's grid and it starts mending its friends, with no
        -- edit to that character's blueprint. `urgent` outranks the ordinary business of the turn,
        -- so a badly hurt ally is patched before a swing is taken -- but only once someone is
        -- actually under half, which is what stops a healer topping up scratches all battle.
        ai = { priority = "urgent", act = "support", targetPref = "lowest_hp",
               when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 } },
        effect = function(fx)
            fx.heal(fx.target, fx.amount) -- restore Power HP via the shared heal helper
        end,
    },
}
