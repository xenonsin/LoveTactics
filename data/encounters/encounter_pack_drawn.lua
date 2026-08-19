-- Encounter blueprint. DRAWN: the small things of the circle, nesting in what you dropped.
--
-- The guard on a modest pack (models/descent.lua's Descent.packGuard). Whatever a company was carrying
-- when it went down is a warm heap of worked metal in a place that has none, and the floor's own
-- vermin -- the gorge flies, the coin chitters, the cinder kin -- are on it long before anyone walks
-- back. Not the circle's lieutenant: a named body does not scavenge.
--
-- THIS IS THE ONE AN EARLY DEATH MEETS, and that is the reason the two guards are split by pile size
-- rather than by depth. The pack a company leaves on its first bad night is four or five things, and
-- what stands over it should be something a stripped, wounded company can walk back into. The full
-- warband is the answer to losing a lot, not to losing early.
--
-- `kind = "pack"` and `weight = 0`: see data/encounters/encounter_pack_scavengers.lua, which explains
-- both, and why neither of these blueprints carries a composition of its own.
return {
    name = "Drawn to It",
    kind = "pack",
    weight = 0,
    minDay = 1,
    description = "Nothing down here has ever seen worked metal that was not swinging. The heap has " ..
        "been found, and the finders have settled into it.",
}
