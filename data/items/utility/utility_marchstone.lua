-- Marchstone: the second hunter half of the Warden (knight x hunter). An incense charm -- ground that
-- WALKS (Combat.layIncense) -- laying Halting Ground on the bearer's tile and the eight around it.
--
-- It exists because the rest of the discipline reads against hazards, and a warden with no hazard spell
-- in its grid was a warden with no discipline. This is the answer that does not require buying a mage:
-- the border is wherever the warden is standing, and it moves with them.
--
-- Incense rather than a placed zone, which is the distinction Combat.layIncense's own header draws: a
-- banner STAYS, a trail is LEFT, incense WALKS. The Warden's other two items are both about ground that
-- sits still and waits -- the Writ stamps what you lay down, Beat the Bounds collects on what is already
-- there. This is the one that follows you, and it turns a march-warden from an emplacement into a patrol.
--
-- It reuses hazard_halting_ground, the zone written for the March-Warden's Standard, rather than
-- authoring a second one that does the same thing: the standard nails the line to a square and this
-- carries it, which is the same border held two different ways.
--
-- Note it needs no help from the Writ. The Writ stamps hazards placed through fx.placeHazard; incense
-- goes through Hazard.place directly, so a warden holding both is not double-dipping -- this ground
-- Halts because of what it IS, and the Writ is for everything else the warden owns.
return {
    name = "Marchstone",
    description = "Inflicts Halt on adjacent foes.",
    flavor = "The old stones marked the parish edge. This one was pried up and has been walking ever since.",
    sprite = "assets/items/utility_marchstone.png",
    type = "utility",
    tags = { "charm", "control" },
    class = "warden",
    unlockQuests = 5,
    dropTier = 4,
    incense = { hazard = "hazard_halting_ground", radius = 1 },
    -- it stops bodies moving, which is a wall's job
    bonus = { defense = 2 },
}
