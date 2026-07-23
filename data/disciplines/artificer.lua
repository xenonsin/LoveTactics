-- Artificer -- mage x alchemist multiclass discipline.
-- Signature mechanic: Constructs -- deploy autonomous sentries/turrets that act on their own each
-- turn. (ability_emplace_sentry is the first legitimate stock, per docs/classes.md.)
-- Exemplar: a sentry-engine builder (character_artificer, NEW -- pending), met as a BOSS/MENTOR.
-- Gate: earned advancement -- requires a mage subclass AND an alchemist subclass unlocked, which
-- opens the_automaton_foundry (pending). See docs/disciplines-plan.md.
return {
    name    = "Artificer",
    classes = { "mage", "alchemist" },
    exemplar = "character_artificer", -- NEW, pending
    requiredQuests = { "the_automaton_foundry" }, -- pending
}
