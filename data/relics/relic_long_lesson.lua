-- COMMON. Skill raises Hit and Crit (docs/accuracy.md). The offensive half of the accuracy pair, and the
-- reason it is a common rather than an uncommon is that it buys consistency rather than power: a company
-- that misses less is not a company that hits harder, it is one whose plan survives contact.
return {
    name = "The Long Lesson",
    blurb = "+%d skill for the whole company -- blows land, and land keener.",
    tier = "common", mark = "Le",
    scale = { 1, 1 },
    bonus = { skill = 1 },
}
