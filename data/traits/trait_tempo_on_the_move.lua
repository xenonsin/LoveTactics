-- Tempo on the Move: walking no longer forfeits the Tempo pool (Engine.onWalk, models/engine.lua). The
-- Skirmisher's twist on the fighter's engine: the base rule is "plant your feet", and the Skirmisher is
-- the class whose whole doctrine is never standing where it swung.
return {
    name = "Tempo on the Move",
    description = "Walking does not reset your Tempo.",
    tempoOnTheMove = true,
}
