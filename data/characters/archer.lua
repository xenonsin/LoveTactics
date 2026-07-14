return {
    name = "Archer",
    sprite = "assets/chars/archer.png",
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    -- The archer is a hunter (the bow's shelf), so an unused archer grows toward ranged stats.
    class = "hunter",
    stats = {
        health = 75, mana = 15, stamina = 90, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 16, magicDamage = 3,          -- flat stats
        defense = 7, magicDefense = 5,
        movement = 4, -- number of spaces this character can move
        speed = 5,    -- nimble
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. The
    -- build-around is the Wolfsong Horn relic in the center (data/items/utility/sig_wolfsong_horn.lua):
    -- a bound item -- never moved, stowed, sold, or stolen, only forged -- that fields her wolf free at
    -- the opening bell. Around it: the trap kit (spike-trap ability + detector) that makes her the
    -- party's trapper, and the bow set adjacent to Rain of Arrows so that combo fires from the start
    -- (Rain needs a bow in an adjacent cell -- see ability_rain_of_arrows.lua). Summon Wolf reserves a
    -- quarter of her small mana pool for as long as the wolf stands. (The torch was dropped to fit the
    -- relic into the nine cells.)
    startingItems = {
        "leather_armor", "ability_spike_trap",    "trap_sense",
        "buckler",       "sig_wolfsong_horn",     "healing_potion",
        "bow",           "ability_rain_of_arrows", "ability_summon_wolf",
    },
}
