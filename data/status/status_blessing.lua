-- Blessing: an offensive benediction. Raises the blessed unit's Damage AND Magic Damage by a flat
-- amount for a while (statBonus, folded into Combat's flatStat so it lifts both a sword swing and a
-- spell). The striking half of the priest's two field buffs -- granted in a 3x3 to allies by Blessing
-- (data/items/ability/ability_blessing.lua). A BUFF, so Cure leaves it be. Compare Aegis, its
-- defensive mirror (data/status/aegis.lua).
return {
    name = "Blessing",
    abbr = "Bls",
    description = "Blessed: raised Damage, Magic Damage and Skill.",
    color = { 0.880, 0.798, 0.472 }, -- badge tint (gilded gold)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN: the "while" a turn spent casting is worth
    -- SKILL IS THE THIRD TERM, and it is the exact mirror of the luck Aegis now carries.
    --
    -- The pair was already an argument about the two halves of a fight: Blessing makes your blows worth
    -- more, Aegis makes theirs worth less. Accuracy added a second half to each of those -- whether the
    -- blow lands at all -- and the two statuses each take the half that matches what they already were.
    -- An offensive benediction that raised the damage of a swing while saying nothing about whether it
    -- connected was answering half its own question.
    --
    -- 4 rather than 5, and lower than the damage beside it, because skill is the cheaper of the two
    -- accuracy stats per point (Grade.STAT_VALUE: 0.2 against luck's 0.25 -- skill adds half a crit
    -- point where luck denies a whole one).
    statBonus = { damage = 5, magicDamage = 5, skill = 4 },
}
