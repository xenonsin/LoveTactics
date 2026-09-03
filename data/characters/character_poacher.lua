-- Poacher exemplar (rogue x hunter multiclass). Snare-execute: traps set up the blink-kill, with a
-- bonus against the Rooted. Met as a bounty-jumping trapper, a recruit. Home shelf is rogue
-- (Poacher's Kris). Kit from data/disciplines/poacher.lua.
return {
    name = "Poacher",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/poacher.png",
    class = "rogue",
    discipline = "poacher",
    -- Roots them in a trap first, then cuts the throat; holds ground to let them step wrong (defensive).
    archetype = "defensive",
    stats = {
        health = 64, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 16, magicDamage = 4,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 6, luck = 7,
    },
    startingItems = {
        "weapon_poachers_kris", "ability_bolas",         "ability_throatcut",
        "utility_quarrys_due",  "utility_the_long_wait", "armor_leather_armor",
        "consumable_healing_potion", "utility_quarrys_end",             false,
    },
    defaultAction = "weapon_poachers_kris",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_poachers_kris",
    signatureAbility = "ability_bolas",
    -- 1. Something is already rooted: execute it -- the bonus lands on the Rooted, and the opening
    -- does not come round again. 2. Nothing rooted yet: net one. The payoff has to be asked about
    -- BEFORE the setup, or the poacher nets a second foe while the first stands pinned and
    -- unexecuted -- which is what `urgent` says. Written in that order too: priority decides, but a
    -- list whose declaration order disagrees with its priorities reads as a bug to the next person.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_throatcut", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
        { priority = "high", act = "cast", item = "ability_bolas",
          when = { subject = "any_foe", test = "lacks_status", value = "status_root" } },
    },
}
