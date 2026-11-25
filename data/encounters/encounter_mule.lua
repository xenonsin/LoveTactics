-- Encounter blueprint. THE RIFT MULE (2026-11-24): a pack animal standing loose on floor five.
--
-- Guaranteed on floor SendUp.MULE_FLOOR until the company finds it (models/descent.lua's
-- Descent.muleStops) and never rolled: weight 0 keeps it out of the random draw. Walking onto it is the
-- whole encounter: the company takes the mule, and from then on a "Send Mule" button on every floor's
-- map sends a few finds up to the stash, then the mule is away for a few fights (models/send_up.lua).
-- It never fights.
return {
    name = "A Stray Mule",
    kind = "mule",
    weight = 0,
    depth = 1,
}
