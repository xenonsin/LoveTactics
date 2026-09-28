-- THE ARC: Wrath's lightning elemental, on the Cinderfall Flows (reviewed 2026-09-27/28, "Fire, Lightning, and
-- Dirty Thunder"). A strike with no aim but everything nearby.
--
-- A NEW BODY, not the conjured Lightning Elemental (the review's pick): its bolt hits its own side, and handing that
-- to a player's summon would change the Arcanum's summon shelf, which is a separate decision.
--
--   FORKING      its bolt forks to the nearest other body within 2 of the one it struck, friend or foe, for half,
--                and again from there (weapon_arc_bolt, Storm.fork)
--   THUNDERCLAP  the first body its lightning strikes each turn is Blinded
--   STATIC       every tile it walks stores a charge, to 5, spent at +3 each on its next bolt; Root, Stun or
--                Grounding wastes it
--   STORM-KIN    ending a turn beside a Blaze, the two fuse into the Thunderhead (models/storm.lua)
--
-- IT AIMS AT THE NEAREST BODY (round 2's pick, after "strikes the tallest" was struck): what an uncontrolled strike
-- would do, and Forking does the rest. `gather`: it walks to a Blaze to fuse when one is on the board.
--
-- Tier 2, 34 health, the fastest body on Wrath's floors. Range 4 on a board whose lava hides nobody. Its lightning
-- resist is 3, not the review's 4 (the tier-2 cap, Balance.INNATE_BUDGET).
return {
    name = "Arc",
    race = "elemental",
    tier = 2,
    sprite = "assets/chars/arc.png",
    archetype = "gather",
    stats = {
        health = 34, mana = 0, stamina = 20,
        staminaRegen = 4,
        damage = 2, magicDamage = 16,
        defense = 2, magicDefense = 8,
        movement = 5,
        speed = 7,
        skill = 5, luck = 5,
    },
    --   An arc has no edges for an edge to work on. It has a path, and a heavy blow interrupts one; so does water.
    resist = { lightning = 3, slash = 2, impact = -2, water = -4 },
    startingItems = { "weapon_arc_bolt", "utility_the_arc" },
    -- WHAT IT IS KNOWN FOR (docs/drops.md): its three rules, each handed over on its own.
    drops = { "weapon_forked_rod", "utility_flashpan", "utility_static_coil" },
    defaultAction = "weapon_arc_bolt",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
