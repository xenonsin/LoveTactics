-- Aegis: a defensive blessing. Raises the warded unit's Defense AND Magic Defense by a flat amount
-- for a while (statBonus, summed into Combat's flatStat exactly like Defending's temporary +defense).
-- The shielding half of the priest's two field buffs -- granted in a 3x3 to allies by Aegis
-- (data/items/ability/ability_aegis.lua). A BUFF, so Cure leaves it be. Compare Blessing, its
-- offensive mirror (data/status/blessing.lua).
return {
    name = "Aegis",
    abbr = "Aeg",
    description = "Warded: raised Defense and Magic Defense.",
    color = { 0.55, 0.70, 0.95 }, -- badge tint (steel blue)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN, matching Blessing, its offensive mirror
    statBonus = { defense = 5, magicDefense = 5 },
}
