-- THE HOARD: Greed's apex, a 2x2 body, and a fight with a clock made of its own reward.
--
-- It does not chase and barely moves. What it does is come apart as you open it: every threshold sheds a
-- pair of coin-chitters, and a chitter runs for the dark carrying as much as it can hold
-- (data/items/utility/utility_the_hoard.lua). So the pile is worth more the FASTER you get through it,
-- and being careful costs you the thing you were being careful about.
--
-- Which is the sharpest reading of the sin available, and the reason this is the apex rather than the
-- Wyrm: the Wyrm is a dragon on a hoard, and this is the hoard, which turns out to be the worse of the
-- two things to meet.
--
-- Tier 3's band is 81-154 health. High -- there has to be enough of it to lose.
return {
    name = "The Hoard",
    kind = "object",
    tier = 3,
    sprite = "assets/chars/the_hoard.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 150, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 13, magicDefense = 6,
        movement = 1, -- it is a pile. Piles do not commute
        speed = 2,
    },
    startingItems = { "weapon_gilt_maw", "utility_the_hoard" },
    defaultAction = "weapon_gilt_maw",
    -- Basic tactics (models/ai.lua): it swings at whatever comes to it and never goes looking. The whole
    -- fight is the player choosing to approach.
    archetype = "defensive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
