-- THE SABERTOOTH: Gluttony's first-floor ambusher, and the first animal in the wood that picks its moment.
-- Wolves swarm, the boar charges, the bear stacks; this one is not there, and then it is beside you. Pitched
-- and reviewed in three rounds (2026-09-23, "The Sabertooth" artifact). Round one -- a pounce that pinned,
-- a bite only a pinned body could take, brittle fangs, a feed -- was denied almost whole ("too many root
-- variants", "needs to do damage"); round two took Rengar's Unseen Predator in its place.
--
-- THE LOOP, as reviewed:
--   Tawny Hide   draw no blood on a turn and it opens the next one Invisible, on any tile -- the Smoke
--                Mantle's own rule (data/traits/trait_smoke_mantle.lua)
--   Pounce       opened Invisible, its bite reaches three tiles, lands it beside the target, and is a
--                critical; and the pounce ends Invisible. Seen, a plain bite from beside you
--   Wood-Walker  rough ground costs it no more than open ground
-- So its rhythm is: hide a turn, pounce, stand exposed for the round, hide again.
--
-- THE COUNTERPLAY, STATED, and it is the review's own: hit it in the round after it pounces, when it is
-- standing beside somebody in plain sight; or reach it while it hides -- an area blast still lands
-- (Combat.aoeUnits does not ask), and Witchlight makes it targetable. And a Mark forbids the veil
-- outright, the ninja's own weakness.
--
-- Slower than every wolf (movement 4, speed 4): an ambusher, not a runner -- the pounce's three tiles are
-- how it closes. The hide turns an edge; a club knocks it flat (impact -3), as with most of the wood.
return {
    name = "Sabertooth",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/sabertooth.png",
    stats = {
        health = 46, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 17, magicDamage = 0, -- between the boar's 14 and the bear's 19; out of hiding it is x3
        defense = 6, magicDefense = 3,
        movement = 4,
        speed = 4,
        skill = 4, luck = 5,
    },
    resist = { slash = 3, impact = -3 },
    startingItems = {
        "weapon_pounce",          "utility_tawny_hide",    "utility_wood_walker",
        "utility_feral_instinct", false,                   false,
        false,                    false,                   false,
    },
    -- Its patience as a cloak, its crit as a charm, and its appetite as a cord. Shallow to deep
    -- (docs/drops.md): within one list the rung IS the rarity.
    drops = { "armor_stalkers_mantle", "utility_ambush_charm", "utility_trophy_cord" },
    defaultAction = "weapon_pounce",
    archetype = "aggressive",
    -- Nothing here names the hiding: the planner scores a blow by its forecast, and a pounce out of hiding
    -- forecasts a critical, so it is taken without being told to be. What the rule adds is the kill.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
