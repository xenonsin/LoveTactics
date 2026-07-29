return {
    name = "Priest",
    sprite = "assets/chars/priest.png",
    -- No portrait: retired from the player's party (data/player.lua). Only ever an enemy/ally/test
    -- stand-in now, so it owes no painted VN portrait -- it falls back to the letter token if it speaks.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "priest",
    -- Reads his allies before his enemies (models/ai.lua): mending outranks swinging, and he keeps
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
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. This is the
    -- RELIC-FREE generic priest: NO Hallowed Censer in the center (that bound Sanctified-Presence relic is
    -- Amana's signature -- see character_amana.lua -- not a template's). Around the empty center, a support
    -- caster's kit: the Heal spell to mend at range, Jolt to delay a pressing threat, silk robes for spell
    -- resistance, a potion as a fallback mend, and the two ways to refuel the non-regenerating mana pool --
    -- the focus stone (Wait -> Focus) and the parasitic staff (siphons mana on hit).
    startingItems = {
        "ability_heal",              "ability_jolt",           "armor_silk_robes",
        "consumable_healing_potion", "weapon_parasitic_staff", "utility_focus_stone",
        "ability_sanctuary",         false,                    false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. Jolt (an offensive zap) keeps click-to-
    -- attack intuitive; the player can re-pin the heal or any other ability.
    defaultAction = "ability_jolt",
    -- Basic tactics (models/ai.lua): mend the moment mending matters. The `support` posture already
    -- reads allies before enemies; this reaches for Heal specifically once someone slips below
    -- two-thirds, ahead of any swing.
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
    },
}
