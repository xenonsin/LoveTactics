-- A villager who got out of the valley alive but not far -- the person the flight leg's rescue
-- fights are fought over (data/encounters/encounter_survivors_defend.lua). It is not a combatant: it
-- has no weapon, so it swings the default unarmed fist only at whatever is already on top of it, and
-- `archetype = "holdGround"` roots it where it stands (models/ai.lua) -- a cornered survivor cowering
-- in the middle of the road, not a unit that fights its way out.
--
-- Rooted is the whole point of the defend lesson: the survivor cannot save itself, so the objective
-- is the party reaching it and holding the ring of demons off (a `defend` win + a `protect` loss).
-- The same blueprint, given nothing to swing, also reads as the inert "thing" a defend objective can
-- be pointed at -- a body to guard rather than a body that helps.
--
-- Fragile on purpose: a few blows end it, so the clock the fight runs on is real. Modeled on
-- character_caravan_driver (a clock, not a combatant) but rooted where the driver walks.
return {
    name = "Survivor",
    archetype = "holdGround",
    sprite = "assets/chars/caravan_master.png",
    stats = {
        health = 24, mana = 0, stamina = 5,
        staminaRegen = 1,
        damage = 3, magicDamage = 0,
        defense = 2, magicDefense = 1,
        movement = 2,
        speed = 2,
    },
}
