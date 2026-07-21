return {
    name = "Archer",
    sprite = "assets/chars/archer.png",
    portrait = "assets/portraits/archer.png", -- large VN portrait for conversations (falls back if missing)
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    -- The archer is a hunter (the bow's shelf), so an unused archer grows toward ranged stats.
    class = "hunter",
    -- A bow is only a bow at range: closed down, she is a light-armored body holding a stick. Left to
    -- herself she kites (models/ai.lua), giving up ground to keep the shot she is built around.
    archetype = "skirmish",
    stats = {
        health = 52, mana = 15, stamina = 90, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 16, magicDamage = 3,          -- flat stats
        defense = 7, magicDefense = 5,
        movement = 4, -- number of spaces this character can move
        speed = 5,    -- nimble
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. The
    -- build-around is the Wolfsong Horn relic in the center (data/items/utility/utility_wolfsong_horn.lua):
    -- a bound item -- never moved, stowed, sold, or stolen, only forged -- that fields her wolf free at
    -- the opening bell. Around it: the trap kit (spike-trap ability + detector) that makes her the
    -- party's trapper, and the bow set adjacent to Rain of Arrows so that combo fires from the start
    -- (Rain needs a bow in an adjacent cell -- see ability_rain_of_arrows.lua). Summon Wolf reserves a
    -- quarter of her small mana pool for as long as the wolf stands. (The torch was dropped to fit the
    -- relic into the nine cells.)
    startingItems = {
        "armor_leather_armor", "ability_spike_trap",    "utility_trap_sense",
        "armor_buckler",       "utility_wolfsong_horn",     "consumable_healing_potion",
        "weapon_iron_bow",           "ability_rain_of_arrows", "ability_summon_wolf",
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_bow",
}
