-- TURNED TO GOLD: the Gilded King's curse, as a rule (2026-09-26, the Gilded King). He starved because his
-- bread turned to gold in his mouth, and it still does: every heal aimed at him becomes a COIN HEAP on the
-- tile beside him and restores nothing -- a potion, a priest, a Regeneration tick, his own side's mending
-- and the company's alike. The gold is loose on the floor for whoever walks over it.
--
-- A FLAG, not a hook (Trait.flag), for Grave-Cold's reason: the interesting code is already written at the
-- one funnel every heal runs through (Combat.applyHeal), and what he adds is one clause there. It is asked
-- AHEAD of the inversion, so the undead tag's Grave-Cold never gets to burn him with the same heal -- the
-- curse is older than the death. The preview asks it too, so a heal aimed at him forecasts nothing.
--
-- Sundered gags it like every flag, and for one break a heal would reach him as Grave-Cold's wound: the
-- flag contract applied evenly, and a strange thing to spend a cast buying.
return {
    name = "Turned to Gold",
    description = "Every heal aimed at this body turns to a coin heap beside it and restores nothing.",
    healsTurnToGold = true,
}
