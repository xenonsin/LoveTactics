-- Beastmaster -- hunter subclass.
-- Signature mechanic: Bond -- a persistent summoned beast that acts each turn under your command.
-- Exemplar: a dedicated Beastmaster (character_beastmaster), met as a RECRUIT -- a houndmaster who calls
-- the pack. (Kaya embodies the same craft but stays a root companion; the "starred reuse" open call in
-- docs/disciplines-plan.md is resolved toward a fresh body.)
-- Gate: one quest in the hunter (Lodge) line -- the_starving_dark (slot 3).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Beastmaster",
    description = "The pack-caller. Keeps a bonded beast on the field that acts every turn under your command.",
    classes = { "hunter" },
    exemplar = "character_beastmaster", -- was character_kaya (a root companion); dedicated exemplar authored
    hire = "character_tola",
    requiredQuests = { "quest_hunters_lodge_slot_03" },
}
