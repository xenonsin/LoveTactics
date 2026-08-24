return {
    name = "Archer",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/archer.png",
    -- No portrait: retired from the player's party (data/player.lua). Only ever an enemy/ally/test
    -- stand-in now, so it owes no painted VN portrait -- it falls back to the letter token if it speaks.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    -- The archer is a hunter (the bow's shelf), so an unused archer grows toward ranged stats.
    class = "hunter",
    -- A bow is only a bow at range: closed down, she is a light-armored body holding a stick. Left to
    -- herself she kites (models/ai.lua), giving up ground to keep the shot she is built around.
    archetype = "skirmish",
    stats = {
        health = 52, mana = 15, stamina = 23, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 16, magicDamage = 3,          -- flat stats
        defense = 4, magicDefense = 5,
        movement = 4, -- number of spaces this character can move
        speed = 5,    -- nimble
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. This is the
    -- RELIC-FREE generic hunter: NO Wolfsong Horn in the center (that bound relic is Kaya's signature --
    -- see character_kaya.lua -- and what makes a companion a companion). Around the empty center: the
    -- trap kit (spike-trap ability + detector) that makes it the party's trapper, and the bow set
    -- adjacent to Rain of Arrows so that combo fires from the start (Rain needs a bow in an adjacent
    -- cell -- see ability_rain_of_arrows.lua). Summon Wolf stays as a plain hunter ability (an ACTIVE
    -- cast, not the horn's opening-bell wolf) -- it reserves a quarter of the small mana pool while the
    -- wolf stands.
    startingItems = {
        "armor_leather_armor",       "ability_spike_trap",     "utility_trap_sense",
        "armor_buckler",             "weapon_iron_bow",        "ability_rain_of_arrows",
        "consumable_healing_potion", "ability_summon_wolf",    false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_bow",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_rain_of_arrows",
    -- Basic tactics (models/ai.lua): a hunter picks off the wounded. From the `skirmish` posture's
    -- kept distance, spend the shot on the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
