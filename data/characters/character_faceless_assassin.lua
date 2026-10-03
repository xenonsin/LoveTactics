-- THE FACELESS ASSASSIN, rung 2: a face for every kill, after the Faceless Men (approved 2026-10-02, "Envy's
-- Bestiary", round 2: the author asked for an assassin wearing "faces from past kills like game of thrones").
--
-- Its hand is not dealt: it is the faces of what it has killed. It walks in wearing a common face -- a glass-thing,
-- or whatever else its side brought -- and stands among the pack as one of them until it strikes. Its first blow
-- out of any face is a critical. When it downs one of the company it takes that face at once, kit and all, and
-- THE SAVE REMEMBERS: that companion is in its hand the next time it is met (models/stolen_faces.lua).
--
-- The counter is the review's: never let it finish anyone, guard the low bodies and revive fast, and watch for
-- the one monster in the pack that has not acted yet. It drops Hall of Faces, on the assassin's rack.
return {
    name = "Faceless Assassin",
    race = "faceless",
    tier = 3,
    class = "rogue",
    sprite = "assets/chars/faceless_assassin.png",
    archetype = "aggressive",
    stats = {
        health = 82, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 3, magicDefense = 4,
        movement = 4,
        speed = 5,
        skill = 7, luck = 6,
    },
    startingItems = {
        "weapon_iron_dagger",  "utility_a_face_for_every_kill", "ability_shadow_step",
        false,                 false,                           false,
        false,                 false,                           false,
    },
    drops = { "utility_hall_of_faces" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
