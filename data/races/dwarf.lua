-- Dwarf: the folk of Greed's keep, and the second race authored onto the axis after the naga.
--
-- WHAT THEY ARE, in one table: forge-born, so fire runs off them; mail and beard turn a blade and a
-- point, and a hammer rings the whole helm. Said once here rather than five times across
-- data/characters/, which is the whole argument for the axis.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 slash, +1 pierce, -2 impact), the innate contract held: turning two
-- weapons aside costs them the third, so the counter to a dwarf line is in the fighter's hands. Every
-- value sits inside the rung-1 budget because the Delver and the Porter are rung 1 and wear this table
-- unchanged -- a race is written to the LOWEST rung that wears it.
--
-- THE STAT LINE is short legs and thick hide: a dwarf is slower to reach you than the men it fights and
-- harder to cut once it does. Movement -1 is also what Inheritance spends -- a Share is weight, and a
-- dwarf that has taken up two of them is close to standing still (data/status/status_inheritance.lua).
--
-- STOUT IS GRANTED rather than authored into five grids (utility_stout). It carries the three rules
-- that make a dwarf a dwarf -- it cannot be moved, it cannot be robbed, and it goes for loose gold --
-- plus Inheritance, the rule that passes a fallen dwarf's Share to the nearest of its kin. Bound and
-- unstealable: an organ, not kit. What the player takes off a dwarf is what it CARRIES, and dwarves are
-- bodied -- they carry real, made things (docs/bestiary.md's outfitting rule).
--
-- PLAYABLE (reviewed 2026-09-24): a company may hire one, and a player dwarf carries Stout and
-- Inheritance too -- so a player dwarf standing near a kinsman who falls takes up that Share.
return {
    name = "Dwarf",
    description = "Stout folk of the counting-house keep. You cannot move one, and you cannot rob one.",
    kind = "humanoid",
    resist = {
        fire = 2,     -- forge-born
        slash = 1,    -- mail and beard turn a blade...
        pierce = 1,   -- ...and a point...
        impact = -2,  -- ...and a hammer rings the whole helm. Sums to zero.
    },
    bonus = {
        movement = -1, -- short legs
        defense = 1,   -- thick hide
    },
    grants = { "utility_stout" },
}
