-- High Wind: the Highwing riding the air over the glade, which is the one wyvern that can STAY up there.
--
-- The line's Take Wing is a hiding place -- untargetable, and it must come down next turn. This is the
-- opposite trade: still on the board, still a target, but +30 Avoid on top of its Tailwind, a tile more
-- reach on its Wind Shear, and no Root takes hold of it. The only way to hurt it up here is to aim well
-- (Mark cuts Luck, and Luck is Avoid), and the rest of the fight is waiting for it to come down -- which
-- it does in a Stoop (ability_stoop spends this status), or when the three turns run out.
--
-- `avoid` and `range` are read by Combat.avoid and Combat.abilityRange respectively, through
-- Status.statBonus; `grantsImmunity` is the buff-lent immunity Heroism uses (Status.isImmune).
return {
    name = "High Wind",
    abbr = "High",
    description = "Riding high: +30 Avoid, +1 range, and immune to Root.",
    color = { 0.72, 0.84, 0.90 }, -- badge tint (high air)
    duration = 15, -- three turns at Status.TICKS_PER_TURN
    statBonus = { avoid = 30, range = 1 },
    grantsImmunity = { "status_root" },
}
