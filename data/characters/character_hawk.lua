-- The hawk fielded by the Falconer's Glove (data/traits/trait_falconers_hawk.lua). A spotter, not a
-- fighter: fast, fragile, and armed only with Talons. Its job was done the instant it marked the
-- quarry at the opening bell; everything after is harassment. See data/characters/character_wolf_grunt.lua
-- for the beast-summon shape this follows.
return {
    name = "Hawk",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/hawk.png",
    stats = {
        health = 14, mana = 0, stamina = 16,
        damage = 6, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 7, -- the fastest thing on the field: it goes where the eye needs to be
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 5,
    },
    startingItems = { "weapon_talons" },
    -- Basic tactics (models/ai.lua): a raptor stoops on the weakest -- press the foe closest to falling,
    -- the same pack instinct the wolf runs on.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
