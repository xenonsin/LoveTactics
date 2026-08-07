return {
    name = "Knight",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/knight.png",
    -- No portrait: this is the GENERIC knight template, not a companion. Rowan (the knight companion)
    -- lives in character_rowan.lua and specializes from this base by adding her bound relic (the Sworn
    -- Aegis). Like the other generic class stand-ins (Mage, Archer, Priest), this one is only ever an
    -- enemy / ally / test body and owns no painted VN portrait -- it falls back to the letter token.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "knight",
    -- The wall. It does not kill you, it decides where you stand. It takes the post the objective
    -- names -- the boss on an assassination, the node on a control map -- and then holds it, fighting
    -- what comes and refusing to be baited off (models/ai.lua's `defensive` posture). On a killAll,
    -- which names nothing to defend, it falls back to holding until the fight comes to it: a knight is
    -- the shape a map is authored around, a quiet corner the player chooses when to open.
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
    -- companion. The spear and buckler are the pair the class is actually about (see the signatures
    -- below); the sword keeps its free Parry as the close-in answer, chainmail holds the line, and a
    -- potion self-heals.
    startingItems = {
        "weapon_iron_spear", "weapon_iron_sword", "armor_chainmail",
        "armor_buckler",     "consumable_healing_potion", false,
        false,               false,               false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so
    -- its range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_spear",
    -- The two items that ARE this unit. Draft mode strips a bought body down to exactly these
    -- (models/draft_chassis.lua), so what a drafted knight arrives as is spear-and-shield: reach that
    -- skewers the two tiles in front at once, and the brace behind it, since the buckler swaps this
    -- unit's Wait into Defend. That pair is the whole class thesis -- it does not kill you, it decides
    -- where you stand -- stated in two items a round-one player can read at a glance. The spear being
    -- `hands = 2` is no obstacle: `hands` is read only by Dual Wield (models/item.lua), never as a
    -- shield gate. The shield takes the "verb" slot because Defend genuinely is one -- a signature
    -- need only be an item the blueprint carries, not one of `type = "ability"`.
    signatureWeapon  = "weapon_iron_spear",
    signatureAbility = "armor_buckler",
    -- Basic tactics (models/ai.lua): the wall still knows a kill when it sees one -- it swings on the
    -- foe already closest to falling, from the `defensive` posture's held ground.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
