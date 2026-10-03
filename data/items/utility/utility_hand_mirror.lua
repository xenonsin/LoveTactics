-- HAND-MIRROR: an artificer's polished glass (approved in "Envy's Bestiary" round 1 as a drop, row lt_drops, and
-- kept when the Looking-Glass it came off was cut; Medusa drops it now). While you hold more blessings than any
-- ally, a single-target attack on you rebounds onto the attacker -- answered in Combat's tryWardSpell beside
-- Reflect Magic and Reflect Steel (models/gorgon.lua's Gorgon.handMirror). It needs at least one blessing to
-- answer anything: "more than any ally" on a bare body is no reason to be looked at.
--
-- PERSEUS (`perseus = true`): carry it into Medusa's sight and her gaze turns back on her (models/gorgon.lua).
-- The Polished Shield answers the same way. An unstocked trophy on the approach's rung.
return {
    name = "Hand-Mirror",
    description = "While you hold more blessings than any ally, single-target attacks on you rebound onto the attacker.",
    flavor = "Whoever looks into it first sees themselves. Whoever looks second sees what the first one did.",
    sprite = "assets/items/utility_hand_mirror.png",
    type = "utility",
    tags = { "charm" },
    class = "artificer",
    unlockLevel = 11,
    unstocked = true,
    perseus = true,
    traits = { "trait_hand_mirror" },
}
