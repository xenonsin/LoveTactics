-- A non-combatant escortee. Spawned on the party's side under AI control via a quest's
-- `objective.allies` (see Arena.build), and named by a `protect` objective: if he falls, the
-- battle is lost however it was otherwise going.
--
-- Deliberately fragile and slow. He carries nothing, so he swings the default unarmed weapon
-- and will wander toward the nearest foe on his own -- escorting him is a real problem.
return {
    name = "Caravan Master",
    sprite = "assets/chars/caravan_master.png",
    stats = {
        health = 55, mana = 0, stamina = 30,
        staminaRegen = 1,
        damage = 4, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 3,
        speed = 2,
    },
}
