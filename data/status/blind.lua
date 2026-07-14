-- Blind: the unit's ability range is cut -- it strikes and casts as if half-sighted. Range is per
-- ability, not a flat stat, so this can't ride statBonus the way Cripple's movement cut does; the
-- `rangeMalus` field is read by Status.rangeMalus and folded into Combat.abilityRange, which floors
-- the reach at 1 so a blinded unit can still hit an adjacent foe.
return {
    name = "Blind",
    abbr = "Bln",
    description = "Blinded: ability range is reduced (never below adjacent).",
    color = { 0.35, 0.33, 0.45 }, -- badge tint (dim slate)
    duration = 4,
    debuff = true,                -- removable by Cure
    rangeMalus = 2,
}
