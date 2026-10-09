-- MANA EDGE: the Battlemage's piece cut from the Lesser Archon's blade (data/items/utility/utility_mana_edge.lua;
-- "The Crown's Bestiary", slice A, 2026-10-09). The Archon's blade is mana and lands on Magic Defense; carried out,
-- the edge learns to land on whichever of the two defenses is lower, and to bite +3.
--
-- A BLOW is a weapon swing: the defense swap reads a hit tagged melee or ranged (models/archon_court.lua's
-- defenseStat, asked by Combat.mitigatedDamage and its receipt), and the bite reads the weapon that threw it. A
-- battlemage's spells land where their school says.
return {
    name = "Mana Edge",
    description = "Your blows strike whichever of the foe's defense or magic defense is lower, and deal +3 damage.",
    strikesLowerDefense = true,
    bite = 3,
    damageBonusVs = function(ctx)
        if ctx.blow and ctx.blow.type == "weapon" then return ctx.param("bite", 3) end
        return 0
    end,
}
