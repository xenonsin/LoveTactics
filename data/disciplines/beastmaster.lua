-- Beastmaster -- hunter subclass.
-- Signature mechanic: Bond -- a persistent summoned beast that acts each turn under your command.
-- Exemplar: Kaya (character_kaya), met as a RECRUIT -- the hunter companion learning to call the
-- pack; her unlock is a companion quest. (Reuse flagged in docs/disciplines-plan.md.)
-- Gate: one quest in the hunter (Lodge) line -- the_starving_dark (slot 3).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Beastmaster",
    classes = { "hunter" },
    exemplar = "character_kaya",
    requiredQuests = { "quest_hunters_lodge_slot_03" },
}
