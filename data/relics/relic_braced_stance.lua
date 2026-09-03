-- UNCOMMON. Movement is the expensive currency in a tactics game -- it is how a body chooses its fight
-- at all -- so one point of it buys a great deal of armour.
--
-- THE STEP ONLY DEEPENS THE GAIN, and that asymmetry is deliberate rather than generous. A second copy
-- taking a second point of movement would root a company at three, and a relic that can accidentally
-- delete the movement system has stopped being a trade. The price is paid once; the armour keeps
-- climbing.
return {
    name = "The Braced Stance",
    blurb = "+%d defense for the whole company.",
    tier = "uncommon", mark = "Bs",
    cost = "-1 movement. (Paid once, however many are held.)",
    scale = { 4, 3 },
    bonus = { defense = 4, movement = -1 },
    bonusStep = { defense = 3, movement = 0 },
}
