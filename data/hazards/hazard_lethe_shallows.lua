-- LETHE SHALLOWS: the underworld's signature ground ("The Crown's Bestiary", slice C, approved 2026-10-09). Pools of
-- grey water on the fight board. A body that ENDS ITS TURN in one forgets every status it carries, good and bad: Burn,
-- Poison and Root go, and so do Blessed and Hasted.
--
-- It replaced the Spoil Heap, which was Greed's ground left standing on the Crown's floor when the circles were
-- dealt their own (data/hazards/hazard_spoil_heap.lua is untouched; nothing seeds it now).
--
-- WHY THE TURN'S END AND NOT THE STEP IN. A pool you could walk through to shed a Root would be a free Cure on the
-- way past; one you have to stop in costs the turn's position, and the forgetting takes the blessings you were
-- standing there to use. It is read where the turn ends (Hazard.onTurnEnd), so wading across costs nothing.
--
-- WHAT IT LEAVES: an injury's badge, a pending channel and what a body is (models/gate_and_pit.lua's forgettable).
-- Unsided, as all terrain is: the hounds' fire-born rule is not a status, so the water does not put it out -- Wet
-- does that, and this is not Wet.
return {
    name = "Lethe Shallows",
    description = "Whoever ends a turn here forgets every status, good and bad.",
    tags = { "water" },
    duration = 9999, -- the ground does not expire
    -- Hostile to the planner: a body on the far side of the board is usually standing in what it was blessed with.
    disposition = "hostile",
    onTurnEnd = function(ctx)
        require("models.gate_and_pit").forget(ctx.combat, ctx.unit)
    end,
}
