-- THE GODLING, rung 2 elite: a young dragon the kobolds have raised as a god. Approved in round 1 (2026-09-24)
-- and re-fed in round 2 (2026-09-25): its Hoard-Crust fed on coin heaps, and "Kobolds don't care about gold"
-- took that away. It feeds on its worshippers instead. A SPARE elite on Greed's seat, not the lieutenant (as
-- picked on the page), in the Nest (encounter_greed_the_nest).
--
--   THE TITHE (utility_godlings_hunger)   a kobold that ends its turn beside it gives itself up: heal a
--                                         tenth, and a stack of Glut -- +2 Damage, +2 Defense, no cap
--   THE BARE PATCH                        a critical hit strips every stack of Glut at once
--   DRAGON'S BREATH                       a wind-up cone, telegraphed a turn early, that leaves fire
--   A DRAGON                              kobolds within 3 fight under the Dragon's Eye; striking it rallies
--                                         them; killing it leaves every kobold that sees it Forsaken
--
-- The Hoard-Thane turned round: every dwarf the company kills feeds the Thane, and every kobold it DOESN'T
-- kill before it reaches the Godling feeds this. His Mithril Shirt refuses criticals; the Godling's belly
-- is bare to them. The crit build that does nothing in the Counting Hall is the answer here.
--
-- THE HIDE is on the body (the bestiary reads it there): +1 slash, +1 impact, -2 pierce -- the black arrow.
return {
    name = "The Godling",
    race = "dragon",
    tier = 3,
    boss = true, -- off the execute and Charm tables, as an elite is
    sprite = "assets/chars/the_godling.png",
    archetype = "aggressive",
    stats = {
        health = 124, mana = 10, stamina = 30,
        staminaRegen = 3,
        damage = 17, magicDamage = 14,
        defense = 6, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    resist = { slash = 1, impact = 1, pierce = -2 },
    startingItems = {
        "weapon_great_claws", "ability_dragons_breath", "utility_godlings_hunger",
        false,                false,                    false,
        false,                false,                    false,
    },
    -- Its own trophy first; then the line's.
    drops = { "utility_godlings_scale", "ability_borrowed_breath", "utility_scurry" },
    defaultAction = "weapon_great_claws",
    signatureWeapon = "weapon_great_claws",
    ai = {
        { priority = "high", act = "attack", item = "ability_dragons_breath",
          when = { subject = "nearest_foe", test = "within", value = 3 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
