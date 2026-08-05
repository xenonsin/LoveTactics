-- The Jealous Resin's standing rule: nothing in the bearer's grid can be lifted.
--
-- Flag-shaped rather than hook-shaped, for the reason models/trait.lua gives: the interesting code is
-- already written -- Combat.steal knows who is being robbed and what it was about to take -- and the
-- charm only has to answer one yes/no question at that seam. Every theft vector in the game runs
-- through Combat.steal (Pickpocket, and any enemy thief), so warding it there covers all of them.
--
-- The ward is PERSONAL, not a party rule: it protects the grid it sits in and no other. That is the
-- whole cost of the item -- a cell spent on the one character carrying something worth keeping, while
-- the rest of the company stays robbable -- and it is why a single charm cannot switch off the greed
-- line's signature mechanic.
--
-- Sundered gags it, like every other flag charm (Trait.flag returns nil under status_sundered): strip
-- the bearer's relics and the resin lets go with them.
return {
    name = "Jealous Resin",
    description = "Nothing can be stolen from the bearer's grid.",
    wardsTheft = true,
}
