-- THE GHOUL: the floor's grave-robber -- Greed's verb, done by the dead. Flesh, not bone, so it wants a
-- BLADE where the skeletons want a hammer and the wights want light. Reviewed 2026-09-25 ("The Dead Hand").
--
--   PARALYTIC CLAWS  every hit a small Stun, a critical one a hard one (weapon_ghoul_claws).
--   GRAVE-ROBBER     beside a body that is down, it takes a piece off it and wears it -- a loan the fight
--                    gives back (ability_grave_rob). The downed window is the whole counterplay.
--   IT HUNTS THE LYING-DOWN FIRST  the sleeping, before anybody else (`targetPref = "sleeping"`).
return {
    name = "Ghoul",
    race = "undead",
    tier = 1,
    sprite = "assets/chars/ghoul.png",
    archetype = "aggressive",
    stats = {
        health = 30, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 4,
        speed = 5,
        skill = 4, luck = 2,
    },
    -- Rubbery dead flesh rolls with a hammer and stops a point; an edge opens it. Sums to zero.
    resist = { impact = 2, pierce = 2, slash = -4, fire = -2, holy = -2 },
    startingItems = {
        "weapon_ghoul_claws", "ability_grave_rob", false,
        false,                false,               false,
        false,                false,               false,
    },
    drops = { "consumable_ghoul_nail_paste", "ability_ghouls_bite" },
    defaultAction = "weapon_ghoul_claws",
    signatureWeapon = "weapon_ghoul_claws",
    ai = {
        { priority = "high", act = "attack", targetPref = "sleeping",
          when = { subject = "any_foe", test = "has_status", value = "status_sleep" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "exists" } },
    },
}
