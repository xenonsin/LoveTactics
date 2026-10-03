-- THE DOPPELGANGER, rung 2 and tier 3: a Faceless of Envy's seat (reviewed 2026-10-01..03, "Envy's Bestiary").
--
-- AT THE OPENING BELL IT BECOMES AN EXACT COPY OF THE NEAREST OF THE COMPANY: that body's stats, every item in its
-- grid, and the tactics it fights with -- its posture and its rule list, your own overlay included -- and it keeps
-- the copy until it dies (Exact Copy, models/masks.lua). Locked, so Reshape never takes it off again. Its own
-- health pool is the one thing that does not change: a face is a transform, and a transform never brings a second
-- health bar.
--
-- So who stands nearest when the fight opens decides what you are fighting, and you choose the deployment.
--
-- Its own kit below is what it carries before the bell, and never what it fights with. It drops Doppel-Step, on
-- the ninja's shelf: the same trick, worn for a turn and on a cooldown.
return {
    name = "Doppelganger",
    race = "faceless",
    tier = 3,
    sprite = "assets/chars/doppelganger.png",
    stats = {
        health = 92, mana = 20, stamina = 24,
        staminaRegen = 3,
        damage = 11, magicDamage = 6,
        defense = 6, magicDefense = 6,
        movement = 3,
        speed = 4,
        skill = 5, luck = 5,
    },
    startingItems = {
        "utility_exact_copy", "weapon_iron_dagger", "armor_leather_armor",
        false,                false,                false,
        false,                false,                false,
    },
    drops = { "ability_doppel_step" },
    defaultAction = "weapon_iron_dagger",
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
