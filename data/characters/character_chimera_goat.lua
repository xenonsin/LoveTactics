-- THE CHIMERA'S GOAT: a head, not a body (Combat.spawnHeads). Grown at the bell off utility_chimera_goat on
-- the chimera's grid -- or off utility_goat_head on a Beastmaster's -- it stands on no tile, reads its
-- position through the body it grows from, and dies when that body does. Its whole kit is its breath.
--
-- THE SLOW HEAD, and the slowness is the pacing: a breath at speed 9 comes round about once for every two
-- of the lion's bites, which is what took the pitched 10-tick cooldown off it on review. Its card on the
-- strip is the warning -- spread out before it comes round. Unfed (nobody in reach of the cone) it comes
-- round sooner (utility_unfed_mouth).
--
-- ~32 health, which is the break: kill it and it is BROKEN, the lion eats it, and its drop can fall.
return {
    name = "Chimera's Goat",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/chimera_goat.png",
    -- No fists: a head has one mouth and one thing to do with it, and a goat that punched on the turns
    -- it had nothing to breathe on would never go hungry (status_starving).
    unarmed = false,
    stats = {
        health = 32, mana = 0, stamina = 22,
        staminaRegen = 4,
        damage = 6, magicDamage = 0, -- a light fire hit: the Burn it leaves is the point
        defense = 5, magicDefense = 6,
        movement = 0, -- it goes where the lion goes
        speed = 3,
        skill = 4, luck = 3,
    },
    resist = { fire = 3 }, -- the fire is its own; the tier-2 budget is 3
    startingItems = {
        "ability_goats_breath", "utility_unfed_mouth", false,
        false, false, false,
        false, false, false,
    },
    defaultAction = "ability_goats_breath",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "cast", item = "ability_goats_breath" },
    },
}
