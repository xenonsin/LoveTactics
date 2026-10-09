-- PIT LOCUST: the Crown's swarm ("The Crown's Bestiary", slice C, approved 2026-10-09). Revelation's locusts, out of
-- the smoke of the bottomless pit: they were not given to kill, only to torment, and men sought death and did not
-- find it.
--
--   SEEK DEATH    its sting can't take a body below 1 health. Against a body already at 1, each sting adds Torment
--                 (status_torment: -3 Damage and -1 Movement a stack, until Cured) (trait_seek_death)
--
-- THE COUNTERPLAY, STATED, and it is the review's own: they can't kill anyone, so they matter because of what fights
-- beside them. Cure your tormented bodies, or rotate them out of the line and clear the swarm before the heavy
-- hitters arrive.
--
-- SELF-CONTAINED ON PURPOSE: the Hollow Crown's last phase spawns these, so nothing about the body reads its fight.
-- A demon, chosen over a beast: they come up out of the pit, and the pit is the Host's. Tier 1 chaff, in numbers.
return {
    name = "Pit Locust",
    race = "demon",
    tier = 1,
    sprite = "assets/chars/pit_locust.png",
    stats = {
        health = 20, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 6, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 5,
        speed = 6,
        skill = 6, luck = 5,
    },
    -- A shell of plates: an edge skids off it, and it breaks under anything heavy.
    resist = { slash = 2, impact = -2 },
    startingItems = {
        "weapon_pit_locust_sting", "utility_seek_death", false,
        false,                     false,                false,
        false,                     false,                false,
    },
    drops = { "ability_torment" },
    defaultAction = "weapon_pit_locust_sting",
    archetype = "aggressive",
}
