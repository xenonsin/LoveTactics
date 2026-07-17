-- Disarmed: the crafted weapon is struck from the hand. Any weapon the unit tries to use is refused
-- while this lasts -- Combat.itemBlockReason reads `disablesWeapon` (via Status.disarmed) and greys
-- the weapon slot, refuses the swing, reddens the tooltip, and filters the AI all at once, exactly as
-- `silencesMana` does for a mana cast. The bare `unarmed` fallback is exempt (see the gate in
-- Combat.itemBlockReason), so a disarmed unit can still throw a punch -- disarm takes the blade, not
-- the fists, which is what keeps it from being a strictly-better Stun. Abilities and potions are
-- untouched: it disarms the hand, it does not silence the caster.
--
-- Inflicted by the alchemist's Disarm ability (data/items/ability/ability_disarm.lua).
return {
    name = "Disarmed",
    abbr = "Dis",
    description = "Disarmed: weapons cannot be used (bare fists still can).",
    color = { 0.72, 0.55, 0.30 }, -- badge tint (rusted bronze)
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN: long enough to actually cost a swing
    debuff = true, -- removable by Cure / Panacea
    disablesWeapon = true,
}
