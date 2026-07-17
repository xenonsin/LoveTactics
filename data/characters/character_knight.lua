return {
    name = "Knight",
    sprite = "assets/chars/knight.png",
    portrait = "assets/portraits/knight.png", -- large VN portrait for conversations (falls back if missing)
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
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. The
    -- build-around is the Sworn Aegis relic in the center (data/items/armor/armor_sworn_aegis.lua):
    -- a bound item -- never moved, stowed, sold, or stolen, only forged -- that carries the Knight's
    -- Oathward guard. Frontline steel around it: sword for the melee strike, chainmail for all-round
    -- defense (only -1 movement so it keeps pace), a potion to self-mend under fire, and the party's
    -- torch (its overworld vision -- see Player.visionRadius).
    startingItems = {
        "weapon_iron_sword", "armor_chainmail",       "consumable_healing_potion",
        "utility_torch",      "armor_sworn_aegis", false,
        false,        false,             false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_sword",
}
