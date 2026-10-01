-- THE LIONESS: Pride's huntress, and half of the pride's one question. Approved 2026-09-30 on Pride's bestiary
-- review. She does the hunting; he does the eating.
--
-- THE KING EATS FIRST (utility_the_king_eats_first): while a Lion of her side stands, her blows cannot take a
-- foe below 1 health, and a foe she brings to 1 is Rooted. She holds the prey for him, and his planner goes for
-- held prey first (character_lion.lua). Fell him and she kills like any cat; leave him and your bodies live, but
-- stand Rooted at 1 waiting for him.
--
-- Not the sabertooths of the wood (character_sabertooth.lua): those hide and pounce. These run in the open, fast
-- (movement 5) and quick to bite (Fangs, speed 2), and their whole threat is what they leave standing.
return {
    name = "Lioness",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/lioness.png",
    stats = {
        health = 46, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 5, magicDefense = 3,
        movement = 5,
        speed = 4,
        skill = 5, luck = 5,
    },
    -- A short coat over a runner's frame: an edge slides off the hide, and a club finds the ribs.
    resist = { slash = 2, impact = -2 },
    startingItems = {
        "weapon_fangs",  "utility_the_king_eats_first", false,
        false,           false,                         false,
        false,           false,                         false,
    },
    drops = { "utility_hold_the_quarry" },
    defaultAction = "weapon_fangs",
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
