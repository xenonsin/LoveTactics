-- UNCOMMON. The Braced Stance's cousin, spread across both armours rather than piled on one: a company
-- carrying everything it owns on its back turns blades AND spells, and is a step slower for it.
--
-- THE STEP DEEPENS ONLY THE GAIN, for the reason The Braced Stance gives: a second step off the walk
-- per copy would root a company at three, and a trade that can delete the movement system has stopped
-- being a trade. The price is paid once.
return {
    name = "The Heavy Pack",
    blurb = "+%d defense and magic defense for the whole company.",
    tier = "uncommon", mark = "Hp",
    cost = "-1 movement. (Paid once, however many are held.)",
    scale = { 2, 1 },
    bonus = { defense = 2, magicDefense = 2, movement = -1 },
    bonusStep = { defense = 1, magicDefense = 1, movement = 0 },
}
