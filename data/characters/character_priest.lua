return {
    name = "Priest",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/priest.png",
    -- No portrait: retired from the player's party (data/player.lua). Only ever an enemy/ally/test
    -- stand-in now, so it owes no painted VN portrait -- it falls back to the letter token if it speaks.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "priest",
    -- Reads his allies before his enemies (models/ai.lua): healing outranks swinging, and he keeps
    -- out of reach while he does it. The Heal in his grid carries its own rule, so most of this
    -- posture's work is the footwork rather than the choice of spell.
    archetype = "support",
    stats = {
        health = 50, mana = 70, stamina = 10, -- resource stats
        staminaRegen = 1, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 5, magicDamage = 12,          -- flat stats
        defense = 6, magicDefense = 11,
        movement = 4, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 6,
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. This is the
    -- RELIC-FREE generic priest: NO Hallowed Censer in the center (that bound Sanctified-Presence relic is
    -- Amana's signature -- see character_amana.lua -- not a template's). It carries the PLAIN censer
    -- instead, the way the other templates carry their `weapon_iron_<family>`: the censer is the priest's
    -- own arm and belongs to this shelf and no other (data/items/weapon/weapon_censer.lua), so a body that
    -- fought with a staff was borrowing the mage's. Around it, a support caster's kit: Heal at
    -- range, Jolt to delay a pressing threat, silk robes for spell resistance, a potion as a fallback
    -- heal, and the focus stone (Wait -> Focus) to refuel the non-regenerating mana pool.
    --
    -- Trading the parasitic staff for the censer costs the second mana-refuel route (the staff siphoned
    -- on hit) and buys the family's real verb: walking smoke that Blesses whoever stays beside him. That
    -- is the more priestly bargain, and it makes mana upkeep a gear decision rather than a given.
    startingItems = {
        "ability_heal",              "ability_minor_shock",     "armor_silk_robes",
        "consumable_healing_potion", "weapon_censer",    "utility_focus_stone",
        "ability_sanctuary",         false,              false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. Jolt (an offensive zap) keeps click-to-
    -- attack intuitive; the player can re-pin the heal or any other ability.
    defaultAction = "ability_minor_shock",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_censer",
    signatureAbility = "ability_heal",
    -- Basic tactics (models/ai.lua): heal the moment healing matters. The `support` posture already
    -- reads allies before enemies; this reaches for Heal specifically once someone slips below
    -- two-thirds, ahead of any swing.
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
