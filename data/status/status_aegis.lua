-- Aegis: a defensive blessing. Raises the warded unit's Defense AND Magic Defense by a flat amount
-- for a while (statBonus, summed into Combat's flatStat exactly like Defending's temporary +defense).
-- The shielding half of the priest's two field buffs -- granted in a 3x3 to allies by Aegis
-- (data/items/ability/ability_aegis.lua). A BUFF, so Cure leaves it be. Compare Blessing, its
-- offensive mirror (data/status/blessing.lua).
return {
    name = "Aegis",
    abbr = "Aeg",
    description = "Warded: raised Defense, Magic Defense and Luck.",
    color = { 0.564, 0.689, 0.896 }, -- badge tint (steel blue)
    fx = { field = true },    -- draws ground under whoever is guarded (a buff: the rising-chevron look, ui/field_fx.lua)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN, matching Blessing, its offensive mirror
    -- LUCK IS THE THIRD TERM, and this is the game's luck buff rather than a new status beside it.
    --
    -- It belongs here on the merits: luck raises Avoid and blunts an attacker's crit (docs/accuracy.md),
    -- which is precisely what a DEFENSIVE benediction is for. Defense decides what a landed blow costs
    -- you; luck decides whether it lands at all, and whether it lands badly. A ward that answered the
    -- first question and not the second was only ever half a ward -- it just had no way to say so until
    -- accuracy existed.
    --
    -- Deliberately not a fourth status of its own. A separate "Fortune" would need its own deliverer,
    -- its own badge and its own slot on a shelf, to say a thing the priest's existing pair already has
    -- the shape for -- and it would leave Aegis still answering half the question. Everything that
    -- grants Aegis today (ability_aegis, the Sacred Banner's twin, the armour that carries it) grants
    -- the luck too, for free.
    --
    -- 4 rather than 5: luck is worth slightly more per point than a point of guard (Grade.STAT_VALUE
    -- prices it at 0.25 against defense's 0.9 -- but a point of luck denies a whole crit point, where a
    -- point of defense stops one point of one blow).
    statBonus = { defense = 5, magicDefense = 5, luck = 4 },
}
