-- A conjured creature, not a recruitable one: reached only through a summon ability
-- (data/items/ability/ability_summon_fire_elemental.lua), which scales it by the item's upgrade level.
-- Frail and slow, but it hits hard through magicDefense and shrugs off spells. Like the beasts, it
-- carries a natural weapon rather than crafted gear, and no mana of its own -- its summoner already
-- paid for it. See data/characters/bandit.lua for the blueprint shape.
return {
    name = "Fire Elemental",
    kind = "elemental",
    tier = 1,
    sprite = "assets/chars/fire_elemental.png",
    stats = {
        health = 22, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 4, magicDamage = 14,
        defense = 2, magicDefense = 10,
        movement = 4,
        speed = 4,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Cutting a flame divides it into two flames. This has been tried.
    --   Smothering it works, and so does the whole of the Arcanum's cold shelf.
    resist = { fire = 2, slash = 2, impact = -2, water = -4, ice = -4 },
    startingItems = { "weapon_flame_fists" },
    -- Basic tactics (models/ai.lua): a summoned brawler earns its keep -- press the foe closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
