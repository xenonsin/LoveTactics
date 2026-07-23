-- A hulking brute that stands on FOUR tiles at once -- the reference multi-tile creature (see the
-- footprint system in models/combat.lua). `footprint = { w = 2, h = 2 }` makes its body a 2×2 block
-- anchored at its top-left cell: it blocks all four tiles, is struck from beside any of them, takes an
-- area blast once, and slides as one body when knocked back. Slow and armored, it fights physically
-- with its bare fists. Placed directly on an arena (authored enemy spawn), not summoned.
return {
    name = "Ogre",
    sprite = "assets/chars/ogre.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 90, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 18, magicDamage = 0,
        defense = 9, magicDefense = 3,
        movement = 4,
        speed = 1, -- ponderous: a big body comes around the initiative wheel slowly
    },
    startingItems = { "weapon_stone_fists" },
    -- Basic tactics (models/ai.lua): the brute wades in and presses whoever is closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
