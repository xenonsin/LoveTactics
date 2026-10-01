-- THE PHOENIX: one of Pride's one-off elites, on the spire's seat ("Pride's Bestiary", 2026-09-30). It never
-- repents; it only returns.
--
--   NEVER REPENTS  felled, it burns down to an Ember on its tile (character_phoenix_ember), which rises again
--                  as the Phoenix in three turns at full health (trait_never_repents, status_rekindling)
--   ONLY RETURNS   every rising is +3 Damage for every time it has died (status_reborn)
--   EMBER TALONS   a fire bird's claws: a physical blow with fire on it, and Burn
--
-- THE COUNTERPLAY, STATED: kill it, then BREAK THE EMBER inside the three turns -- the Ember counts on its side,
-- so the fight is not won while one stands. A company that kills it and turns its back fights it again, angrier.
--
-- ALONE (encounter_pride_the_phoenix): its fight is the Ember race, and an escort standing over the Ember would
-- turn a race into a siege. Its feathers take fire and fold to ice. Tier 3 and `boss`.
return {
    name = "Phoenix",
    race = "beast",
    tier = 3,
    boss = true,
    sprite = "assets/chars/phoenix.png",
    stats = {
        health = 100, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 14, magicDamage = 0,
        defense = 6, magicDefense = 8,
        movement = 5,
        speed = 3,
        skill = 7, luck = 4,
    },
    resist = { fire = 4, ice = -4 },
    startingItems = {
        false,                false,                    false,
        "weapon_ember_talons", "utility_never_repents", false,
        false,                false,                    false,
    },
    defaultAction = "weapon_ember_talons",
    -- ITS OWN PIECE (docs/drops.md): one rising, for whoever carries it.
    drops = { "utility_phoenix_feather" },
    archetype = "aggressive",
}
