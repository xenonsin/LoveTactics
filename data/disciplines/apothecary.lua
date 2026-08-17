-- Apothecary -- priest x alchemist multiclass discipline.
-- Signature mechanic: Lent vitality -- elixirs that heal AND lend party stats (Ren's coveted-blood
-- line, whose damage stat is the rest of your party).
-- Exemplar: a dedicated Apothecary (character_apothecary), met as a RECRUIT -- a field-medic who heals
-- before she strikes, which is what this discipline already is. (Ren embodies the same virtue but stays a
-- root companion; the "starred reuse" open call in docs/disciplines-plan.md is resolved toward a fresh body.)
-- Gate: earned advancement -- requires a priest subclass AND an alchemist subclass unlocked, which
-- opens quest_alchemist_apothecary_ren (pending). See docs/disciplines-plan.md.
return {
    name    = "Apothecary",
    description = "The field medic who reaches for a dose before a blade. Elixirs that heal and lend party stats, so what your column is carrying is what the dose is worth.",
    classes = { "priest", "alchemist" },
    exemplar = "character_apothecary", -- was character_ren (a root companion); dedicated exemplar authored
    hire = "character_ansel",
    requiredQuests = { "quest_alchemist_apothecary_ren" }, -- pending
}
