-- Hasted: quickened. Every ability the unit uses costs half as much while this lasts -- the
-- `costMultiplier` is folded into Combat.abilityCost, the single price the model, the AI, the
-- grayed-out slot and the tooltip all read, so a hasted unit's discount shows up everywhere at
-- once. It does NOT discount a RESERVATION (Combat.abilityReserve): a reservation is resource
-- committed for as long as a summon lives, not a price paid at the moment of casting.
--
-- The Haste ability (data/items/ability/ability_haste.lua) also cuts the target's current
-- initiative in half, which is a one-off shove up the turn order rather than anything this status
-- has to keep track of.
return {
    name = "Hasted",
    abbr = "Hst",
    description = "Quickened: ability costs are halved.",
    color = { 0.95, 0.85, 0.45 }, -- badge tint (gold, matching the initiative accent)
    duration = 12,
    costMultiplier = 0.5,
}
