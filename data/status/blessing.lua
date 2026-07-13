-- Blessing: an offensive benediction. Raises the blessed unit's Damage AND Magic Damage by a flat
-- amount for a while (statBonus, folded into Combat's flatStat so it lifts both a sword swing and a
-- spell). The striking half of the priest's two field buffs -- granted in a 3x3 to allies by Blessing
-- (data/items/ability/ability_blessing.lua). A BUFF, so Cure leaves it be. Compare Aegis, its
-- defensive mirror (data/status/aegis.lua).
return {
    name = "Blessing",
    abbr = "Bls",
    description = "Blessed: raised Damage and Magic Damage.",
    color = { 0.95, 0.85, 0.45 }, -- badge tint (gilded gold)
    duration = 12,
    statBonus = { damage = 5, magicDamage = 5 },
}
