-- THE DEAD CELLS THAT ARE NOT A PLACEMENT MISTAKE, and what each one is actually waiting on.
--
-- tests/kit_adjacency_spec.lua sweeps every authored character grid for an ability that can never meet
-- its `requiresAdjacent` where it was placed. Most of what it found was a swap of two cells: the
-- weapon was already in the grid, one square out of reach, and moving the ability beside it is the
-- whole fix (the Sentinel's Single Combat, the rogue's Exploit, the ambusher's Snare Stake).
--
-- These two are not that. In both, the grid holds NOTHING that could meet the requirement from any
-- cell, so there is no placement that fixes them -- somebody has to decide what the body carries, and
-- that is a content decision rather than a bug with an obvious answer. Recorded here so the sweep can
-- be honest without being red, and so the debt is visible rather than forgotten. A row here is a
-- WAIVER WITH A REASON, not a verdict that the kit is fine: delete the row in the same change that
-- fixes the kit.
return {
    -- Closed Ring needs a `shield` beside it and this knight carries no shield at all -- and it is
    -- dead twice over, because the cast costs 18 mana against a pool of 15, so no placement in any
    -- grid would let this body pay for it. Either the ability does not belong on the Bulwark, or the
    -- Bulwark wants the shield its own drops table hands out (armor_bulwark_shield) and a bigger pool.
    -- The blueprint's own header already argues the movement budget that makes adding a plate hard.
    character_bulwark = { "ability_closed_ring" },

    -- The Warden is the knight x hunter crossing and Warding Line is its hunter half -- it declares an
    -- adjacent BOW, in its description as well as in its data. The exemplar carries a spear and no bow
    -- anywhere in the grid, so the crossing ships with half of itself switched off. The fix is a bow in
    -- the kit; which of the nine cells pays for it is the decision nobody has made.
    character_warden = { "ability_warding_line" },
}
