return {
    name = "Rogue",
    sprite = "assets/chars/rogue.png",
    -- No portrait: the GENERIC rogue template, not a companion. Clem (the rogue companion) is the named
    -- specialization built on this base. Only ever an enemy / ally / test body -- it falls back to the
    -- letter token if it speaks.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "rogue",
    -- Guile: conditional multipliers and return-to-origin blinks. A light body that darts in on the
    -- wounded and slips back out (models/ai.lua's `skirmish` posture), giving up ground to keep the
    -- opening its multipliers need. No bound relic -- the template is the base a companion sharpens.
    archetype = "skirmish",
    stats = {
        health = 55, mana = 8, stamina = 22, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 15, magicDamage = 3,          -- flat stats
        defense = 6, magicDefense = 5,
        movement = 4, -- number of spaces this character can move
        speed = 5,    -- nimble
    },
    -- Starting loadout (row-major; false = empty). The dagger opens a wound (Bleed), Shadow Step is the
    -- rogue's return-to-origin blink, Exploit is the conditional multiplier the shelf is built on,
    -- leather and a potion keep the glass body standing.
    startingItems = {
        "weapon_iron_dagger", "ability_shadow_step", "ability_exploit",
        "armor_leather_armor", "consumable_healing_potion", false,
        false,                false,                 false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so its
    -- range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_dagger",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_shadow_step",
    -- Basic tactics (models/ai.lua): from the kept distance, spend the strike on the foe already
    -- closest to falling -- guile finishes, it does not trade.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
