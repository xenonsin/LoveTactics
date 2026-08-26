-- A non-combatant escortee. Spawned on the party's side under AI control via a quest's
-- `objective.allies` (see Arena.build), and named by a `protect` objective: if he falls, the
-- battle is lost however it was otherwise going.
--
-- Deliberately fragile. He carries nothing, so he swings the default unarmed weapon.
--
-- `holdGround` (models/ai.lua) is the difference between a liability and a farce: he never leaves the
-- tile he lands on. He swings at whatever walks into reach and lets everything else past, so escorting
-- him is the problem of covering ground he is standing on rather than chasing him into it.
--
-- NOT `defensive`, which is the posture that READS like a hold and does not behave like one here. A
-- defender is leashed to its post -- the body or ground it was assigned (AI.post) -- and the body this
-- map assigns is HIM: he is the `protect` clause, so AI.post hands him himself. His post is then his
-- own tile, his leash is the two tiles around wherever he is standing, and it re-anchors every turn:
-- a treadmill that walks him into the breach two squares at a time the moment anything scratches him.
-- `defensive` is the posture of a unit posted to something ELSE. A body that IS the post holds ground.
--
-- The same fiction as character_caravan_driver with the opposite footwork: the driver `escort`s,
-- because on the road the column is trying to leave and its arrival is the win condition. The master
-- is rooted at the gate, because by then the climb is over and there is nowhere further up to go.
return {
    name = "Caravan Master",
    kind = "humanoid",
    tier = 0,
    archetype = "holdGround",
    sprite = "assets/chars/caravan_master.png",
    stats = {
        health = 38, mana = 0, stamina = 8,
        staminaRegen = 1,
        damage = 4, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 4,
        speed = 2,
    },
}
