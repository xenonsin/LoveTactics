-- Reflect Magic: for a window, single-target spells aimed at the bearer are turned around and land on
-- the caster instead. Combat.dealDamage reads Status.reflectorAgainst with the incoming school, and on
-- a match the blow is thrown back at exactly the value it was thrown with -- the mage's own fireball,
-- mitigated by the mage's own magic defense on the way in.
--
-- A WINDOW, not a charge, which is the whole distinction from data/status/magical_barrier.lua sitting
-- next to it. A barrier is one hit and gone; this answers every single-target spell that comes at it
-- until the clock runs out. That is strictly stronger per-spell, so it is paid for in the two ways a
-- window can be: it is short, and it is single-target only -- an area spell has no one thread running
-- back to its caster, so a Fireball goes straight through a mirror and lands in full.
--
-- The counterplay is therefore real and legible: don't cast single-target magic at the mirror. Wait it
-- out, throw an area spell, or hit it with a sword. A mirror that answered EVERYTHING would not be a
-- ward, it would be an instruction to stop playing until it lapsed.
return {
    name = "Reflect Magic",
    abbr = "RefM",
    description = "Mirrored: single-target spells rebound onto the caster.",
    color = { 0.72, 0.60, 0.98 }, -- badge tint (arcane violet, mirror-bright)
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN. Short, as a window must be -- but a window
                   -- under one turn was not short, it was closed before anyone could cast into it.
    reflects = "magical",
}
