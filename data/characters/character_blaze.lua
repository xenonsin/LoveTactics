-- THE BLAZE: Wrath's fire elemental, on the Cinderfall Flows (reviewed 2026-09-27/28, "Fire, Lightning, and Dirty
-- Thunder"). The fire that will not stay where it was put.
--
-- NOT LUST'S FIRE ELEMENTAL, and a new body on purpose (the review's first pick). That one is a slow, frail
-- obstacle that burns whoever reaches for it and stands where it is; the summon shares its numbers. This one comes
-- at you, and it does it through the one barrier on this ground that nobody else crosses.
--
--   OF THE FLOWS  it walks the lava as ground and mends at the end of a turn in it: it comes up out of the gap on
--                 your side, and it goes back into the flow to heal
--   WILDFIRE      fire within 2 of it creeps a tile into plain ground at the end of its turn -- the board shrinks
--                 while it lives
--   KINDLE        its blows set the struck tile alight, so the Wildfire has a spark where the fight is
--   DOUSED        water puts it out for two turns: no spreading, no kindling, no mending, and fists without fire
--   STORM-KIN     ending a turn beside an Arc, the two fuse into the Thunderhead (models/storm.lua)
--
-- `gather`: it walks to an Arc to fuse when one is on the board, and at the company when none is.
--
-- Tier 2, 46 health (the review's line), just above the cinder slime it shares the approach with. Its fire resist is
-- 3, not the review's 4: a tier-2 hide is capped at 3 (Balance.INNATE_BUDGET), and the slash/impact pair is the
-- redistribution every creature's hide is.
return {
    name = "Blaze",
    race = "elemental",
    tier = 2,
    sprite = "assets/chars/blaze.png",
    archetype = "gather",
    stats = {
        health = 46, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 10, magicDamage = 12,
        defense = 4, magicDefense = 6,
        movement = 4,
        speed = 5,
        skill = 4, luck = 3,
    },
    --   Cutting a flame divides it. Smothering it works, and so does a flood.
    resist = { fire = 3, slash = 2, impact = -2, water = -6, ice = -4 },
    startingItems = { "weapon_blaze_fists", "utility_of_the_flows" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md): its three rules, each handed over on its own.
    drops = { "utility_flowwalkers_soles", "utility_heart_of_the_wildfire", "utility_coal_in_the_fist" },
    defaultAction = "weapon_blaze_fists",
}
