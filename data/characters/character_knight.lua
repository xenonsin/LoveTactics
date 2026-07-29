return {
    name = "Knight",
    sprite = "assets/chars/knight.png",
    -- No portrait: this is the GENERIC knight template, not a companion. Rowan (the knight companion)
    -- lives in character_rowan.lua and specializes from this base by adding her bound relic (the Sworn
    -- Aegis). Like the other generic class stand-ins (Mage, Archer, Priest), this one is only ever an
    -- enemy / ally / test body and owns no painted VN portrait -- it falls back to the letter token.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "knight",
    -- The wall. It does not kill you, it decides where you stand. Left to itself it holds until the
    -- fight comes to it, then commits (models/ai.lua's `defensive` posture) -- a knight is the shape a
    -- map is authored around, a quiet corner the player chooses when to open.
    archetype = "defensive",
    stats = {
        health = 68, mana = 15, stamina = 18, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 13, magicDamage = 4,          -- flat stats
        defense = 11, magicDefense = 6,
        movement = 4, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Starting loadout as the 3x3 grid the player sees (row-major); false = an empty cell. A plain
    -- frontline kit with NO bound relic -- that is exactly what separates a generic template from a
    -- companion. The sword keeps its free Parry (the answer to an adjacent blow the mace trades away),
    -- a spear reaches the second rank, a buckler and chainmail hold the line, and a potion self-mends.
    startingItems = {
        "weapon_iron_sword", "weapon_iron_spear", "armor_chainmail",
        "armor_buckler",     "consumable_healing_potion", false,
        false,               false,               false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_sword",
    -- Basic tactics (models/ai.lua): the wall still knows a kill when it sees one -- it turns its
    -- blade on the foe already closest to falling, from the `defensive` posture's held ground.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
