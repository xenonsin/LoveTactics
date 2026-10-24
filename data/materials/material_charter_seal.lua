-- The Charter Seal: what makes a class a body's own (Class.unlock, models/class.lua). Not forging
-- stock -- no class, never billed at the Forge -- but a material all the same, because a material is
-- exactly the thing this is: a counted resource the company holds rather than a piece in a grid.
--
-- WHERE ONE COMES FROM: the FIRST time the company beats each elite (player.elitesBeaten, stamped in
-- EncounterBattle.spoils), and nowhere else. Spent one per unlock, in town. (Rowan used to hand one over
-- at Novice 1; the avatar's first class is her recommendation instead -- Class.pickOwed.)
return {
    name = "Charter Seal",
    description = "A guild's wax seal, pressed and unclaimed. Spend it to make a class yours.",
    sprite = "assets/materials/charter_seal.png",
    tier = 3,
    seal = true, -- not forging stock: nothing at the Forge bills it
}
