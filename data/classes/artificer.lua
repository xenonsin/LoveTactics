-- Artificer -- mage x alchemist multiclass discipline.
-- Signature mechanic: Constructs -- deploy autonomous sentries/turrets that act on their own each
-- turn. (ability_emplace_sentry is the first legitimate stock, per docs/classes.md.)
-- Exemplar: a sentry-engine builder (character_artificer, NEW -- pending), met as a BOSS/MENTOR.
-- Gate: earned advancement -- requires a mage subclass AND an alchemist subclass unlocked, which
-- opens quest_alchemist_the_automaton_foundry (pending). See docs/disciplines-plan.md.
return {
    name    = "Artificer",
    description = "The engine-builder. Deploys autonomous sentries and turrets that take a turn of their own each round and fight without orders.",
    exemplar = "character_artificer", -- NEW, pending
    requires = { mage = 7, alchemist = 7 },
}
