-- Hasted: quickened. Every ability the unit uses costs half as much while this lasts, and so does
-- every step it takes -- the `costMultiplier` is folded into Combat.abilityCost and into
-- Combat.moveInitiative, the single prices the model, the AI, the grayed-out slot and the tooltip
-- all read, so a hasted unit's discount shows up everywhere at once. A cheaper walk buys TIME, not
-- ground: Combat.reachable still spends the raw path cost against the movement budget, so a hasted
-- unit goes exactly as far, it just comes back around the turn order sooner.
--
-- It does NOT discount a RESERVATION (Combat.abilityReserve). A reservation is spent at the moment
-- of casting like a cost is, but it stays locked away for as long as the summon lives, and its size
-- is set by that creature rather than by the caster's tempo.
--
-- The Haste ability (data/items/ability/ability_haste.lua) also cuts the target's current
-- initiative in half, which is a one-off shove up the turn order rather than anything this status
-- has to keep track of.
return {
    name = "Hasted",
    abbr = "Hst",
    description = "Quickened: ability and movement costs are halved.",
    color = { 0.95, 0.85, 0.45 }, -- badge tint (gold, matching the initiative accent)
    duration = 12,
    costMultiplier = 0.5,
}
