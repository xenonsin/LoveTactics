-- THE SKIN-THIEF, rung 2: Envy's jealousy (approved 2026-10-02, "Envy's Bestiary", round 2). Round 1 had it take
-- a body's resists; the author's note was "taking resists is a weak concept", so it takes the face itself.
--
-- A Faceless with a dealt hand like any other, and one rule of its own (The Flaying): its hit flays one of the
-- company -- that body is Halted for 2 turns, no abilities at all, and the thief wears its face for the same 2,
-- casting the company's own abilities back at it. The face comes back when the 2 turns end or the thief dies.
--
-- The counter is the review's: keep the casters away from it, and kill it while it wears a face you can handle.
-- It drops the Flaying Knife, on the thief's rack.
return {
    name = "Skin-Thief",
    race = "faceless",
    tier = 3,
    class = "rogue",
    sprite = "assets/chars/skin_thief.png",
    archetype = "aggressive",
    stats = {
        health = 81, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 3, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_iron_dagger", "utility_the_flaying", "ability_pickpocket",
        false,                false,                 false,
        false,                false,                 false,
    },
    drops = { "weapon_flaying_knife" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
