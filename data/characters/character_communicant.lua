-- THE COMMUNICANT, rung 2 (Wrath's vampires, 2026-09-26). A human priest, and a vampire, who keeps the brood out of
-- Bloodlust with its own blood. BLOOD COMMUNION: it loses 15% of its max health, and every other vampire within 2
-- drinks it -- Thirst reset, a feeding heal (ability_blood_communion). Kill it first and the Fledglings around it
-- go thirsty in two turns; leave it and they never do.
--
-- Drops the Communion Chalice (a company's version: a small heal each turn to every adjacent ally that even the
-- undead can take).
return {
    name = "Communicant",
    race = "human",
    tier = 2,
    class = "priest",
    vampire = true,
    sprite = "assets/chars/communicant.png",
    archetype = "support",
    stats = {
        health = 46, mana = 30, stamina = 14,
        staminaRegen = 3,
        damage = 7, magicDamage = 8,
        defense = 2, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_censer",     "ability_blood_communion", "ability_wing_swap",
        "ability_feed",      false,                     false,
        false,               false,                     false,
    },
    drops = { "utility_communion_chalice" },
    defaultAction = "weapon_censer",
    signatureWeapon = "weapon_censer",
}
