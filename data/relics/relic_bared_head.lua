-- UNCOMMON. The mirror of The Thin Blade: the same price in maximum health, spent on DOING more rather
-- than hitting harder. Two deeper pools is more actions per fight and more casts before the well runs
-- dry, which is a different kind of power from a bigger number and wants its own entry.
return {
    name = "The Bared Head",
    blurb = "+%d maximum mana and stamina for the whole company.",
    tier = "uncommon", mark = "Bh",
    cost = "-%d maximum health, for the run.",
    costScale = { 8, 6 },
    scale = { 4, 4 },
    maxBonus = { mana = 4, stamina = 4, health = -8 },
    maxBonusStep = { mana = 4, stamina = 4, health = -6 },
}
