-- Graven: standing inside a circle you cut yourself. Every ability the unit uses and every step it
-- takes costs less of the timeline -- the same `costMultiplier` knob Haste sets to 0.5 and Mired to 2,
-- folded into Combat.abilityCost and Combat.moveInitiative, so the discount shows up in the model, the
-- AI, the grayed-out slot and the tooltip at once.
--
-- Read it as the third point on that line and the mildest: Haste is a buff somebody spent a spell on and
-- it follows you anywhere; this is weaker AND it is nailed to nine tiles. What it sells is not the size
-- of the discount but that a mage can hand it to ITSELF, on its own turn, at a time of its choosing --
-- and then has to stand still to keep it.
--
-- ZONE-BOUND: it declares no `lingers`, so the grant is stamped with the circle as its `source`, never
-- ages, and lasts exactly as long as the mage stands on its own graven ground -- lifting the instant it
-- steps off, or the instant the circle's own duration runs out. That is the entire tension of the item:
-- the cheapest casting in the game is available only to a caster who has agreed not to reposition.
--
-- A BUFF, so Cure leaves it be. It cannot be dispelled off a mage either -- what an enemy has to do is
-- make standing there untenable, which is a board problem rather than a status problem, and that is the
-- counterplay the item is designed around.
return {
    name = "Graven",
    abbr = "Grv",
    description = "Inside your own circle: ability and movement costs are reduced.",
    color = { 0.62, 0.55, 0.92 }, -- badge tint (arcane violet, the Arcanum's own)
    -- Never reached while the circle holds: a zone-bound status does not age (Status.tick skips it), so
    -- this is only the backstop for a Graven handed out by something that is not a zone.
    duration = 8,
    -- Three quarters, not a half. Haste is the party's big tempo swing and it is bought with a whole
    -- ability and a duration; this is permanent for as long as you hold a tile, and something you can
    -- re-cut whenever it lapses. Pitching it at Haste's 0.5 would make a mage that never moves strictly
    -- better than one that was hasted, forever, which is not a choice -- it is an instruction.
    costMultiplier = 0.75,
}
