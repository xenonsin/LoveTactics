-- THE SNOW QUEEN: Sloth's approach elite ("Sloth's Bestiary", 2026-10-04, approved), after Andersen -- the mirror
-- whose splinters freeze a heart, and the palace of ice at the top of the world. An ELEMENTAL with an escort of ice
-- elementals (encounter_sloth_the_snow_queen).
--
--   SPLINTER          a body her Shard-Bolt strikes becomes Cold-Hearted: it cannot target an ally with anything --
--                     no heal, no buff, no swap -- until fire strikes it or 3 turns pass (weapon_shard_bolt,
--                     status_cold_hearted).
--   THE GLASS PALACE  each of her turns she raises a 3-tile ice wall, telegraphed a turn ahead, through the company,
--                     cutting the board into rooms; fire melts a wall (utility_glass_palace, trait_glass_palace).
--   COUNTER           bring fire: it thaws the heart and the walls. Spread the company's support, so one splinter
--                     cannot cut off the whole company's healing.
--
-- Tier 4 by the review's tag, beside Medusa; `boss`, off the execute and Charm tables like every elite. She is met
-- again on later trips, so every rule reads the board in front of it.
--
-- AN ICE ELEMENTAL'S HIDE, larger: a blade skates, a hammer cracks her, and fire is the review's own answer.
return {
    name = "The Snow Queen",
    race = "elemental",
    tier = 4,
    boss = true,
    sprite = "assets/chars/snow_queen.png",
    archetype = "aggressive",
    stats = {
        health = 165, mana = 60, stamina = 20,
        staminaRegen = 2, manaRegen = 5,
        damage = 4, magicDamage = 13,
        defense = 5, magicDefense = 11,
        movement = 4,
        speed = 4,
        skill = 6, luck = 6,
    },
    resist = { ice = 5, slash = 2, impact = -2, fire = -8 },
    startingItems = {
        false, "weapon_shard_bolt",   false,
        false, "utility_glass_palace", false,
        false, false,                  false,
    },
    drops = { "ability_splinter_of_the_mirror" },
    defaultAction = "weapon_shard_bolt",
    signatureWeapon = "weapon_shard_bolt",
}
