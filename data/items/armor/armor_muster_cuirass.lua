-- The Muster Cuirass: a knight's breastplate cut with the old company marks, which does two opposite
-- things at once to the ground around it -- allies standing beside its wearer are braced, and enemies
-- standing beside its wearer are Exposed (data/hazards/hazard_muster.lua).
--
-- The double reading is what makes it worth a whole item rather than two smaller ones. A pure buff
-- aura rewards clumping up, which this game already rewards plenty; a pure debuff aura rewards shoving
-- into the enemy, which is the knight's job anyway. Doing BOTH means the cuirass wants the two lines
-- TOUCHING -- your people inside the square, theirs inside it too -- which is a genuinely uncomfortable
-- place to want to be, and exactly where a knight is supposed to want to be.
--
-- It also quietly makes the party's piercing weapons better, which is the part that changes a loadout
-- rather than a turn: Exposed amplifies `pierce` and nothing else (see the status's own comment on why
-- narrowness is the design), so a cuirass in a company of spears and bows is worth roughly double what
-- it is worth in a company of axes. The knight's item is an argument about what everyone ELSE brought.
--
-- Ground that walks, so the square is wherever its wearer is standing and the wearer is by definition
-- in the middle of it. There is no version of this item that is safe to use.
return {
    name = "The Muster Cuirass",
    description = "Braces allies beside its wearer, and leaves enemies beside them open to piercing.",
    flavor = "The marks are a roll of names. The Bastion has never told anyone whose.",
    sprite = "assets/items/armor_muster_cuirass.png",
    type = "armor",
    tags = { "heavy" },
    class = "knight",
    price = 440,
    repRank = 4,
    incense = { hazard = "hazard_muster", radius = 1 },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
}
