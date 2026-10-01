-- THE LION: Pride's king of the beasts, and the other half of the pride's question. Approved 2026-09-30 on
-- Pride's bestiary review.
--
-- THE LION'S SHARE (utility_the_lions_share): he goes for held prey first -- a foe his lionesses have Rooted at 1
-- (targetPref "held", models/ai.lua) -- and when he makes a kill he ROARS: every lioness of his side heals 20%,
-- and every foe within 2 of him is Rattled.
--
-- THE TENSION THE AUTHOR APPROVED: while he stands the lionesses cannot kill anybody (trait_the_king_eats_first),
-- so killing him first is what lets them start. Leave him and your bodies live, Rooted, waiting for him.
--
-- Tier 3 on the approach: heavier than his lionesses, slower than them, and the mane turns an edge.
return {
    name = "Lion",
    race = "beast",
    tier = 3,
    sprite = "assets/chars/lion.png",
    stats = {
        health = 92, mana = 0, stamina = 28,
        staminaRegen = 4,
        damage = 16, magicDamage = 0,
        defense = 7, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    -- The mane: a blade bites into a yard of hair. A spear goes under it.
    resist = { slash = 3, pierce = -3 },
    startingItems = {
        "weapon_rending_maw", "utility_the_lions_share", false,
        false,                false,                     false,
        false,                false,                     false,
    },
    drops = { "armor_golden_mane" },
    defaultAction = "weapon_rending_maw",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "held",
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
