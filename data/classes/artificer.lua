-- Artificer -- mage x alchemist multiclass discipline.
-- Signature mechanic: Constructs -- deploy autonomous sentries/turrets that act on their own each
-- turn. (ability_emplace_sentry is the first legitimate stock, per docs/classes.md.)
-- Exemplar: a sentry-engine builder (character_artificer, NEW -- pending), met as a BOSS/MENTOR.
-- Gate: earned advancement -- requires a mage subclass AND an alchemist subclass unlocked, which
-- opens quest_alchemist_the_automaton_foundry (pending). See docs/disciplines-plan.md.
return {
    name    = "Artificer",
    description = "Builds machines that fight for you. Sentries and turrets are placed on the board and "
        .. "take a turn of their own each round without orders.",
    exemplar = "character_artificer", -- NEW, pending
    requires = { mage = 10, alchemist = 10 },
}
