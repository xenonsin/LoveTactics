-- PIT IMP: the Crown's chaff demon ("The Crown's Bestiary", slice B, approved 2026-10-09). Named Pit Imp because
-- the prologue's tutorial demon is already the Imp (character_demon_imp_tutorial).
--
--   THE OFFER   its sting puts Blood Debt on the target: +5 damage for 2 turns, and when it ends the body takes a
--               third of all the damage it dealt under it (weapon_the_offer; data/status/status_blood_debt.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: spend the borrowed power fast and have a healer ready, or
-- Cure it off before it comes due. It is a real choice, not a pure debuff. A demon, so its sting burns and it takes
-- holy the harder.
--
-- Tier 1's band is 1-30 health (Balance.HEALTH_BANDS): it dies to one good blow, and is not there to.
return {
    name = "Pit Imp",
    race = "demon",
    tier = 1,
    sprite = "assets/chars/pit_imp.png",
    stats = {
        health = 26, mana = 0, stamina = 16,
        staminaRegen = 3,
        damage = 8, magicDamage = 0,
        defense = 2, magicDefense = 4,
        movement = 5,
        speed = 6,
        skill = 5, luck = 6,
    },
    -- Leathery and small: an edge skids off it and a point goes right through. Fire is what it is made of.
    resist = { slash = 2, pierce = -2, fire = 2 },
    startingItems = {
        "weapon_the_offer", false, false,
        false,              false, false,
        false,              false, false,
    },
    drops = { "ability_signed_in_blood" },
    defaultAction = "weapon_the_offer",
    archetype = "aggressive",
}
