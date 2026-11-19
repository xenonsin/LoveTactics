-- Oiled: a body slick with lamp oil (the alchemist's Oil Flask). On its own it does nothing at all --
-- the setup half of a REACTION (docs/engines.md, Reactions). The next blow carrying FIRE that lands on
-- an oiled body sets it off: the oil is spent, everything within two tiles takes fire, and the ground
-- around the body burns (Engine.ignite, models/engine.lua). A blast that finds more oil sets that off
-- too, so oiling a crowd and then lighting one of them is the whole play.
--
-- A debuff anybody can carry the setup for and anybody can light, which is what makes it a PARTY
-- engine: the alchemist throws the flask, the mage or the fire-bomb or the burning ground pays it off.
return {
    name = "Oiled",
    abbr = "Oil",
    description = "Oiled: the next fire that touches it explodes, burning everything within 2 tiles.",
    color = { 0.62, 0.48, 0.22 }, -- badge tint (lamp oil)
    fx = { field = true },
    duration = 25, -- ~5 turns: long enough for somebody else on the line to bring the fire
    debuff = true, -- removable by Cure
    lingers = true,
}
