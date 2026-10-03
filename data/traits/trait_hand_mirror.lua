-- THE HAND-MIRROR's rule (data/items/utility/utility_hand_mirror.lua): while the bearer holds more blessings than
-- any ally, a single-target attack on it rebounds onto the attacker. Answered in Combat's tryWardSpell beside
-- Reflect Magic and Reflect Steel (models/gorgon.lua's Gorgon.handMirror), which is the one place a blow is
-- turned back; this file is only the flag that asks it.
return {
    name = "Hand-Mirror",
    description = "While it holds more blessings than any ally, single-target attacks on it rebound onto the attacker.",
    mirrorWhileFairest = true,
}
