-- Apothecary -- priest x alchemist multiclass discipline.
-- Signature mechanic: Lent vitality -- elixirs that heal AND lend party stats (Ren's coveted-blood
-- line, whose damage stat is the rest of your party).
-- Exemplar: Ren (character_ren), met as a RECRUIT -- she mends before she strikes, which is what this
-- discipline already is; its unlock is her own companion quest.
-- Gate: earned advancement -- requires a priest subclass AND an alchemist subclass unlocked, which
-- opens apothecary_ren (pending). See docs/disciplines-plan.md.
return {
    name    = "Apothecary",
    classes = { "priest", "alchemist" },
    exemplar = "character_ren",
    requiredQuests = { "apothecary_ren" }, -- pending
}
