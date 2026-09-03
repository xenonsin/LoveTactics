-- COMMON. Speed is the initiative tie-break folded into starting initiative, so this is the company
-- acting sooner in every round of every fight -- the cheapest thing on the shelf that changes the ORDER
-- of a fight rather than its arithmetic, which in a tactics game is most of what winning is.
return {
    name = "The Early Bell",
    blurb = "+%d speed for the whole company.",
    tier = "common", mark = "Be",
    scale = { 1, 1 },
    bonus = { speed = 1 },
}
