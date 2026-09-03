-- COMMON. The armoured twin of the Whetstone Tithe, and priced identically because mitigation here is
-- SUBTRACTIVE: a point of defense takes a point off every blow that lands, so it is the same quantity a
-- point of damage is and the two can sit on the same rung without either being the obvious pick.
return {
    name = "The Weight of Plate",
    blurb = "+%d defense for the whole company.",
    tier = "common", mark = "Pl",
    scale = { 1, 1 },
    bonus = { defense = 1 },
}
