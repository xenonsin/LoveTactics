-- THE MIRROR-KNIGHT, rung 2 and tier 3: a Faceless of Envy's seat (reviewed 2026-10-01..03, "Envy's Bestiary";
-- approved in round 2 as "Mirrored, and the first single-target attack each round rebounds").
--
-- MIRRORED. It starts each of its turns wearing both mirrors -- Reflect Steel and Reflect Magic, the statuses
-- already in the game -- and the first single-target attack on it in a round rebounds onto whoever threw it. Then
-- the mirror is down until its next turn (Mirrored, utility_mirrored). An area blow never had a thread to run
-- back along, so it goes straight in.
--
-- It still Reshapes like any Faceless, and the mirror rides every face it puts on: the organ is carried.
--
-- It drops the Polished Shield, on the sentinel's shelf: a foe that strikes you in melee is Rattled.
return {
    name = "Mirror-Knight",
    race = "faceless",
    tier = 3,
    sprite = "assets/chars/mirror_knight.png",
    stats = {
        health = 104, mana = 10, stamina = 26,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 9, magicDefense = 7,
        movement = 3,
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "utility_mirrored", "weapon_iron_sword", "armor_polished_shield",
        false,              false,               false,
        false,              false,               false,
    },
    drops = { "armor_polished_shield" },
    defaultAction = "weapon_iron_sword",
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
