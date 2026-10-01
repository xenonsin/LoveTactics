-- THE TITAN: a rebel in the gods' chains, walking Pride's spire on the end of them. Approved 2026-09-30 on Pride's
-- bestiary review, as a one-off giant (data/races/giant.lua says why it is a record of its own).
--
-- CHAINED. It moves 1 tile a turn (the Gods' Chains: -2 on a body of 3) but its Hanging Chain reaches 2, and every
-- blow shoves the target 2 tiles -- the mace's folded knockback, so a body driven into another body or a wall
-- takes the collision. Below half health the chains BREAK (The Chains Break, a live passive): +2 movement, which
-- undoes the chains, and +4 damage, one over the oni's Horn Out.
--
-- So it is a slow wall that throws you away from it until you have hurt it, and then it is not slow. Bring it to
-- half only when you are ready to finish it.
return {
    name = "Titan",
    race = "giant",
    tier = 3,
    sprite = "assets/chars/titan.png",
    stats = {
        health = 124, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 16, magicDamage = 0,
        defense = 8, magicDefense = 4,
        movement = 3, -- 1 in the chains
        speed = 5,
        skill = 4, luck = 3,
    },
    -- Skin like a cliff face: a club finds nothing to break, and a point finds the cracks.
    resist = { impact = 3, pierce = -3 },
    startingItems = {
        "weapon_hanging_chain", "utility_the_gods_chains", "utility_the_chains_break",
        false,                  false,                     false,
        false,                  false,                     false,
    },
    drops = { "weapon_titans_chain" },
    defaultAction = "weapon_hanging_chain",
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
