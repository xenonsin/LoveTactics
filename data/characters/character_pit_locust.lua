-- PIT LOCUST: the Crown's swarm ("The Crown's Bestiary", slice C, approved 2026-10-09). Revelation's locusts, out of
-- the smoke of the bottomless pit: they were not given to kill, only to torment, and men sought death and did not
-- find it.
--
--   SEEK DEATH    its sting can't take a body below 1 health. A sting on a body that ANOTHER locust stands beside
--                 adds Torment (status_torment: -3 Damage and -1 Movement a stack, until Cured) (trait_seek_death)
--
-- MOVED OFF THE HEALTH BAR (the creature identity pass, 2026-11-19). The Torment used to land on a body already at 1,
-- which made three bottom-floor bodies about your wounded (the Lioness's hold, the Reaper's line, this). The locust is
-- the swarm, so its Torment now reads the swarm: one locust on a body is a nuisance, two on the same body is Torment.
--
-- THE COUNTERPLAY, STATED: they can't kill anyone, so they matter because of what fights beside them. Never let two
-- of them reach the same body -- fight from a wall, a corner or a shoulder -- Cure your tormented bodies, and clear
-- the swarm before the heavy hitters arrive. TARGETING: the nearest body, so a swarm floods the front of the company
-- together rather than spreading out after the weak -- which is what lets two of them land on the same body.
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
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
