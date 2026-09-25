-- FORSAKEN: a kobold that saw its dragon destroyed (data/traits/trait_dragonkin.lua, models/devotion.lua).
-- Approved as pitched (2026-09-24): -3 Damage for two turns, and it cannot be rallied while it lasts --
-- Devotion.rally passes over a Forsaken body. Smash an egg in one blow, or kill the Godling, and the whole
-- line that saw it breaks at once.
return {
    name = "Forsaken",
    abbr = "Lost",
    description = "Saw its dragon destroyed: reduce damage. It cannot be driven to Fervor.",
    color = { 0.420, 0.400, 0.460 }, -- badge tint (ash)
    duration = 10, -- ~two turns
    debuff = true,
    statBonus = { damage = -3 },
}
