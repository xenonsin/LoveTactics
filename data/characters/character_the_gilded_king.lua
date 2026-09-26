-- THE GILDED KING: Greed's rung-2 spare elite, on the seat (approved over review rounds on 2026-09-26). A
-- king who wished that everything he touched would turn to gold, and starved when his bread did. He is what
-- is left: a dead man crusted in the gold that killed him, one tile, in a gold crown.
--
-- A MAN, AND DEAD. Race human, TAGGED undead (models/character.lua), as Vesh is: the dead keep what they
-- were (the skeletons' rule), and he was a man. No class -- he was a king, and a king is not a shelf -- so
-- he grows on the classless fallback. The tag seeds Grave-Cold, and his curse is asked ahead of it.
--
-- HIS DEFENCE IS THE GOLD, AND IT PAYS OUT (utility_gilded_flesh):
--   GOLD PLATE        six plates, +2 Defense each; ANY blow knocks one off as a coin heap beside him. He
--                     never eats one back and nothing re-plates him, so he gets softer as the fight pays.
--   TURNED TO GOLD    he cannot be healed: a heal aimed at him is a coin heap instead
--   THE GILDED GUARD  the dwarves he hired to dig his vault, and kept, open the fight Gilded
-- And he wears the Gilded Crown, so a real fight opens him Gilded too: slower still, and harder at the bell.
--
-- SLOW AND WEAK IN THE ARM: a sceptre, a short walk and a late turn. What makes him an elite is the shell
-- and the guard, and the answer is many blows rather than big ones -- every one of them is a heap.
--
-- `boss`, as every elite body is, and never an `assassinate` mark (encounter_greed_the_gilded_king).
return {
    name = "The Gilded King",
    race = "human",
    undead = true,
    tier = 3,
    boss = true, -- off the execute and Charm tables, as an elite is
    sprite = "assets/chars/the_gilded_king.png",
    archetype = "aggressive",
    stats = {
        health = 150, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 8, -- 16 defense with his six plates on
        movement = 3,
        speed = 2,
        skill = 4, luck = 0,
    },
    startingItems = {
        "weapon_gold_sceptre",       "utility_gilded_flesh", "utility_the_gilded_crown",
        false,                       false,                  false,
        false,                       false,                  false,
    },
    -- His two trophies: the crown he wears, and the bread that starved him.
    drops = { "utility_the_gilded_crown", "ability_gilded_bread" },
    defaultAction = "weapon_gold_sceptre",
    signatureWeapon = "weapon_gold_sceptre",
    ai = {
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
