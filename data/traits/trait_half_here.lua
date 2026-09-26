-- HALF HERE: the barrow-wight is only half in the world, and a weapon goes through the half that is not.
-- A physical weapon blow has half its chance to hit (Combat.halfHere, asked inside Combat.hitChance so the
-- forecast shows it). Never a spell, never holy, and not while the body is LIT -- Witchlight, or a foe's
-- carried lantern (Status.lit). Settled on review 2026-09-25 ("The Dead Hand").
return {
    name = "Half Here",
    description = "Weapon blows have half the chance to hit this body, unless it is lit.",
    halfHere = true,
}
