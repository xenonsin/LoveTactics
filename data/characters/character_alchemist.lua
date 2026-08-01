return {
    name = "Alchemist",
    sprite = "assets/chars/alchemist.png",
    -- No portrait: the GENERIC alchemist template, not a companion. Ren (the alchemist companion) is the
    -- named specialization built on this base. Only ever an enemy / ally / test body -- it falls back to
    -- the letter token if it speaks.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "alchemist",
    -- Envy: covets others' power rather than casting its own -- consumables and grid auras. Keeps its
    -- distance and lobs into a cluster (models/ai.lua's `skirmish` posture). No bound relic -- the
    -- template is the base a companion sharpens.
    archetype = "skirmish",
    stats = {
        health = 52, mana = 45, stamina = 14, -- resource stats
        staminaRegen = 1, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 6, magicDamage = 12,          -- flat stats
        defense = 6, magicDefense = 9,
        movement = 4, -- number of spaces this character can move
        speed = 4,
    },
    -- Starting loadout (row-major; false = empty). The lancet is the envenomed blade for when a body
    -- closes; the Fire Bomb is the thrown consumable the shelf is built on; the Fire Stone is a coating
    -- that infuses an adjacent weapon/ability with Burn; a potion and leather keep it upright.
    startingItems = {
        "weapon_apothecarys_lancet", "consumable_fire_bomb", "consumable_fire_stone",
        "armor_leather_armor",       "consumable_healing_potion", false,
        false,                       false,                 false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so its
    -- range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "consumable_fire_bomb",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_apothecarys_lancet",
    signatureAbility = "consumable_fire_bomb",
    -- Basic tactics (models/ai.lua): from the kept distance, spend the throw on the foe already closest
    -- to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
