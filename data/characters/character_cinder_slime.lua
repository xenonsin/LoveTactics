-- THE CINDER SLIME: Wrath's slime (floors 7-8, the volcanic pit). Each circle's slime line carries one rule of
-- its own; this one's is CINDER TRAIL (data/traits/trait_cinder_trail.lua) -- every tile it steps through
-- catches Fire, and the fire does not touch it. Proof against steel like the fen's slime.
--
-- ITS LEVER IS POSITION (the creature identity pass, 2026-11-19). It used to Boil Over -- every hit charged it
-- and the fifth erupted -- which was the Asura line's "chipping it charges it" on a sixth body. Now the board
-- shows what it does: a burning line behind it, walking at you. Meet it before it crosses your ground, or bring
-- water, which douses the trail and which it is soft to.
--
-- Wrath's charge: it goes for the nearest body, straight through whatever it has to burn to get there.
return {
    name = "Cinder Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/cinder_slime.png",
    stats = {
        health = 44, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 3,
        speed = 4,
        skill = 4, luck = 2,
    },
    resist = { fire = 3, water = -3 },
    startingItems = {
        false,              false,               false,
        "weapon_pseudopod", "utility_cinder_body", false,
        false,              false,               false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN PIECES, and only its own (docs/drops.md).
    drops = { "utility_seething_core" },
    archetype = "aggressive",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
