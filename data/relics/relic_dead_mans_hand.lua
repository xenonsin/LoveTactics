-- RARE. A body brought to 0 does not fall yet. It stays on its feet at 0 health and keeps acting for two
-- of its own turns, then falls where it stands -- and is carried out with two injuries instead of one.
--
-- THE RULE FIRES ONCE; THE LADDER IS THE TIME. A second copy does not make the fall cheaper, it makes
-- the borrowed time longer: three turns, then four. The price never moves.
--
-- What the hand refuses (models/combat.lua, "THE DEAD MAN'S HAND"): a blow on a borrowing body does
-- nothing more, no heal reaches it, and a fight that ends while it is still standing calls the hand in
-- anyway. What it never covers: a summon, and any body an objective names as its charge -- a protectee
-- falling is what ends that fight, and the relic is about the company, not about the objective.
return {
    name = "The Dead Man's Hand",
    blurb = "A body brought to 0 keeps acting for %d turns at 0 health, then falls.",
    tier = "rare", mark = "Dm",
    cost = "It cannot be healed while it stands, and the fall costs 2 injuries instead of 1.",
    scale = { 2, 1 },
    rules = { deadMansHand = true },
    ruleScale = { deadMansHand = { 2, 1 } },
}
