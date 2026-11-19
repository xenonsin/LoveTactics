-- Shattered: a chilled coat broken by a heavy blow (status_chilled's payoff). Its bearer's DEFENSE
-- reads 0 while it lasts, whatever the coat, the charms and the ground say -- Combat's flatStat floors
-- the stat there (Engine.zeroesDefense, models/engine.lua). Two turns, and then the plates are plates.
-- Magic defense is untouched: what broke is the metal.
return {
    name = "Shattered",
    abbr = "Shd",
    description = "Shattered: its defense is 0.",
    color = { 0.80, 0.90, 1.00 }, -- badge tint (broken ice)
    duration = 10, -- ~2 turns
    debuff = true, -- removable by Cure
    zeroesDefense = true,
}
