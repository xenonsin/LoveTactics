return {
    name = "Priest",
    sprite = "assets/chars/priest.png",
    stats = {
        health = 70, mana = 70, stamina = 40, -- resource stats
        staminaRegen = 1, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 5, magicDamage = 12,          -- flat stats
        defense = 6, magicDefense = 11,
        movement = 3, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Innate: walks on consecrated ground -- adjacent allies (and the priest) mend each tick
    -- (data/traits/sanctified_presence.lua).
    traits = { "sanctified_presence" },
    -- Support caster: the signature Heal spell to mend allies at range, Jolt to delay a
    -- pressing threat, silk robes for spell resistance, and a potion as a fallback mend. The
    -- focus stone swaps Wait -> Focus (recover mana) and the parasitic staff siphons mana on
    -- hit -- the priest's two ways to refuel the non-regenerating mana pool.
    startingItems = {
        "ability_heal", "ability_jolt", "silk_robes", "healing_potion",
        "focus_stone", "parasitic_staff", "ability_sanctuary",
    }, -- item ids
}
