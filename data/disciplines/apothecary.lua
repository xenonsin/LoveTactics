-- Apothecary -- priest x alchemist multiclass discipline.
-- Signature mechanic: Lent vitality -- elixirs that heal AND lend party stats (Ren's coveted-blood
-- line, whose damage stat is the rest of your party).
-- Exemplar: a dedicated Apothecary (character_apothecary), met as a RECRUIT -- a field-medic who mends
-- before she strikes, which is what this discipline already is. (Ren embodies the same virtue but stays a
-- root companion; the "starred reuse" open call in docs/disciplines-plan.md is resolved toward a fresh body.)
-- Gate: earned advancement -- requires a priest subclass AND an alchemist subclass unlocked, which
-- opens quest_alchemist_apothecary_ren (pending). See docs/disciplines-plan.md.
return {
    name    = "Apothecary",
    classes = { "priest", "alchemist" },
    exemplar = "character_apothecary", -- was character_ren (a root companion); dedicated exemplar authored
    requiredQuests = { "quest_alchemist_apothecary_ren" }, -- pending
}
