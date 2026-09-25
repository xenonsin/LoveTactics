-- EMBERWALK: fire ground and molten gold do not touch you (reviewed 2026-09-25, round 3, "Avaritia, the
-- Unspent"). Carried by the Emberwalk Greaves (data/items/armor/armor_emberwalk_greaves.lua).
--
-- A FLAG rather than an immunity, on purpose: it is the GROUND that leaves you alone. Fire and Molten Gold
-- (data/hazards/hazard_fire.lua, hazard_molten_gold.lua) read `emberwalk` and neither set Burn nor gild the
-- wearer, and their `welcomes` hands the wearer's planner the burning as open floor. A Fireball to the face
-- still burns: that is not the ground. Answers her last third, and pays off anywhere fire is laid --
-- including your own Dragonfire's.
return {
    name = "Emberwalk",
    description = "Fire and molten gold on the ground do not harm you.",
    emberwalk = true,
}
