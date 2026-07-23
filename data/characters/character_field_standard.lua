-- A March Standard: a Warden drives it into the ground and it holds a stretch of field closed. Like the
-- Banner (data/characters/character_banner.lua) it is a standing object, not a fighter -- summoned
-- control-"none" AND timeless, so it never moves, never strikes, and takes no turns. Its whole effect is
-- the ground it holds: a Halting zone (data/hazards/hazard_halting_ground.lua) that stops whoever
-- crosses. Real health so an enemy must spend a turn cutting it down to pass freely.
return {
    name = "March Standard",
    sprite = "assets/chars/march_standard.png",
    stats = {
        health = 30, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 5, magicDefense = 5,
        movement = 0, -- planted
        speed = 0,    -- takes no turns; the zone answers to the clock
    },
    startingItems = {},
}
