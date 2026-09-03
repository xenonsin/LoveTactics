-- UNCOMMON. The plainest possible trade, and the line every other one on this rung is measured against:
-- three times a common's gift, for a real hole in the company's guard.
--
-- WHY THE TWO HALVES CAN BE COMPARED AT ALL. Mitigation here is subtractive, so a point of damage and a
-- point of defense are the same quantity moving in opposite directions -- +3/-3 is a genuine wash on
-- paper and a real decision in practice, because you choose it knowing whether this floor's stock hits
-- once hard or many times lightly. The step deepens both halves, so a second copy stays a decision.
return {
    name = "The Keen Edge",
    blurb = "+%d damage for the whole company.",
    tier = "uncommon", mark = "Ke",
    cost = "-%d defense.",
    costScale = { 3, 2 },
    scale = { 3, 2 },
    bonus = { damage = 3, defense = -3 },
    bonusStep = { damage = 2, defense = -2 },
}
