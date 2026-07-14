-- Silenced: the mana pool is sealed. Any ability whose cost is drawn from mana is refused while
-- this lasts -- Combat.itemBlockReason reads `silencesMana` and greys the slot, refuses the arm, the
-- tooltip's red note, and the AI's item filter all at once, exactly as it does for an unaffordable
-- cost. Abilities that spend stamina or health (a sword swing, a potion) are untouched: silence
-- gags the caster, it does not disarm them.
return {
    name = "Silenced",
    abbr = "Sil",
    description = "Silenced: mana abilities cannot be cast.",
    color = { 0.55, 0.55, 0.62 }, -- badge tint (muted grey)
    duration = 8,
    debuff = true, -- removable by Cure
    silencesMana = true,
    interruptsChannel = "mana", -- gags an in-progress mana channel; a stamina channel is untouched
}
