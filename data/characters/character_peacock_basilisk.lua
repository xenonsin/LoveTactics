-- THE PEACOCK-BASILISK: Pride's vanity with a beak, and a reverse taunt. Approved 2026-09-30 on Pride's bestiary
-- review.
--
-- THE GAZE THAT IS ADMIRED (utility_the_admired_gaze): any foe within 3 that ENDS its turn without having attacked
-- it is Stunned. A taunt makes you hit the taunter; this makes everything else you do cost you the next turn. So
-- its fight is a question of tempo: spend a blow on the bird every turn you stand near it, or kill it first, or
-- stay out of 3 -- which the gilded rank it walks with is built to make awkward.
--
-- Soft (40 health) because it is not the threat: the gaze is. It pecks with the hawk's Talons, which rake and
-- fly back, so it keeps its distance after each blow -- and a body standing off it is a body inside the gaze.
return {
    name = "Peacock-Basilisk",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/peacock_basilisk.png",
    stats = {
        health = 40, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 7, magicDamage = 0,
        defense = 4, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 5, luck = 6,
    },
    -- A fan of quills over a serpent's hide: a point catches in the feathers, an edge goes through them.
    resist = { pierce = 2, slash = -2 },
    startingItems = {
        "weapon_talons", "utility_the_admired_gaze", false,
        false,           false,                      false,
        false,           false,                      false,
    },
    drops = { "utility_peacocks_train" },
    defaultAction = "weapon_talons",
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
