-- A non-combatant escortee. Spawned on the party's side under AI control via a quest's
-- `objective.allies` (see Arena.build), and named by a `protect` objective: if he falls, the
-- battle is lost however it was otherwise going.
--
-- Deliberately fragile and slow. He carries nothing, so he swings the default unarmed weapon.
--
-- `defensive` (models/ai.lua) is the difference between a liability and a farce: he holds where he
-- stands until something comes for him, rather than trotting off toward the nearest raider to punch
-- it. Escorting him is still a real problem -- he does not flee, he cannot fight, and he is slow --
-- but it is now the problem of covering ground he is standing on instead of chasing him into it.
return {
    name = "Caravan Master",
    archetype = "defensive",
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
