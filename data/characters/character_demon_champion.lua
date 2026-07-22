-- The demon that leads the raiding party on the flight leg -- the mini-boss the road ends on
-- (states/prologue.lua's FLIGHT_QUEST objective, won by `assassinate`: cut the champion down and the
-- fight is over). A step above the Demon Grunt (66 health, the horde's heavy) and well below the
-- Demon Lord it serves (420, the finale) -- the first foe the game frames as a BOSS without being the
-- last thing you fight.
--
-- `boss = true` marks it a quest objective: immune to instant execution (Coup de Grace) and to Charm,
-- so the assassinate win is earned by fighting it down rather than skipped by a lucky finisher --
-- exactly why the objective points at it by name. Reusable as a mid-tier demon in later content.
return {
    name = "Demon Champion",
    boss = true,
    sprite = "assets/chars/demon_grunt.png",
    stats = {
        health = 92, mana = 0, stamina = 60,
        damage = 14, magicDamage = 0,
        defense = 8, magicDefense = 4,
        movement = 3,
        speed = 3,
    },
    -- Heavier claws than the grunt's, so the mini-boss hits like one. Its body is its weapon, as with
    -- every demon that isn't carrying something borrowed.
    startingItems = { "weapon_great_claws" },
    defaultAction = "weapon_great_claws",
    -- Basic tactics (models/ai.lua): a mini-boss hunts the kill. Press the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
