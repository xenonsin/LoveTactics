return {
    name = "Fighter",
    sprite = "assets/chars/fighter.png",
    -- No portrait: the GENERIC fighter template, not a companion. Saber (the fighter companion) is the
    -- named specialization built on this base; like the other generic stand-ins (Knight, Rogue, Mage,
    -- Archer, Priest, Alchemist) this one is only ever an enemy / ally / test body and owns no VN
    -- portrait -- it falls back to the letter token if it speaks.
    -- Innate growth class: the fallback/tie-break for the level-up growth system (models/growth.lua).
    class = "fighter",
    -- Wrath is what happens directly in front of you: it walks at the enemy and hits the best thing it
    -- can reach (models/ai.lua's `aggressive` posture). A plain frontline body with no bound relic --
    -- that is what separates a generic template from a companion.
    archetype = "aggressive",
    stats = {
        health = 72, mana = 5, stamina = 25, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 18, magicDamage = 3,          -- flat stats
        defense = 9, magicDefense = 5,
        movement = 4, -- number of spaces this character can move
        speed = 3,    -- initiative tie-break; folded into starting initiative
    },
    -- Starting loadout (row-major; false = empty). The axe cleaves the rank in front (the fighter's
    -- own `front` aoe), the hammer trades reach for a Stun, leather and a potion keep it upright. No
    -- relic and no discipline gear -- the template is the base, not the build-around, so Fury (a
    -- barbarian cut now, data/items/ability/ability_fury.lua) is bought into a build, never issued here.
    startingItems = {
        "weapon_iron_axe",   "weapon_iron_hammer", false,
        "armor_leather_armor", "consumable_healing_potion", false,
        false,               false,                false,
    },
    -- The go-to action pinned by default (Combat.defaultAction): armed at the start of its turn so its
    -- range shows, and driving the basic click-to-use. The player can re-pin any ability.
    defaultAction = "weapon_iron_axe",
    -- The one item that IS this unit. Draft mode strips a bought body down to it
    -- (models/draft_chassis.lua); a plain class template owns no signature verb, which is
    -- exactly what makes it the legible round-one pick.
    signatureWeapon  = "weapon_iron_axe",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
