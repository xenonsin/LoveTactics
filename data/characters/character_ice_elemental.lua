-- A conjured creature, reached only through a summon ability
-- (data/items/ability/ability_summon_ice_elemental.lua), which scales it by the item's upgrade level.
-- Slow and hardy, a wall of ice: high magic defense, steady magic damage through its Frost Fists.
-- See data/characters/fire_elemental.lua for the blueprint shape.
return {
    name = "Ice Elemental",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/ice_elemental.png",
    stats = {
        health = 30, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 4, magicDamage = 12,
        defense = 5, magicDefense = 12,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   A blade skates. It has always skated, and it always will.
    --   Ice under a hammer is the oldest answer there is, and heat is the other one.
    resist = { ice = 2, slash = 2, impact = -2, fire = -4 },
    startingItems = { "weapon_frost_fists" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
