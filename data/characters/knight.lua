return {
    name = "Knight",
    sprite = "assets/chars/knight.png",
    -- Innate growth class: the fallback (and tie-break) for the level-up growth system when this
    -- character has no cast history yet. See models/growth.lua and data/growth/<class>.lua.
    class = "knight",
    stats = {
        health = 100, mana = 20, stamina = 60, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 14, magicDamage = 4,          -- flat stats
        defense = 10, magicDefense = 6,
        movement = 3, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Innate: sworn to shield the weak -- soaks the first blow each turn on an adjacent ally
    -- (data/traits/oathward.lua).
    traits = { "oathward" },
    -- Frontline tank: sword for the melee strike, chainmail for solid all-round steel
    -- (only -1 movement so it still keeps pace), and a potion to self-mend under fire.
    startingItems = { "iron_sword", "chainmail", "healing_potion" }, -- item ids
}
