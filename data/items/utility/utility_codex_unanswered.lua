-- Lifted off Sublimitas's body, and it kept her rule (data/traits/trait_perfect_recall.lua): carry the
-- Codex and a single-target spell aimed at you is answered and unravelled -- you become the thing you
-- killed, the shape every one of the seven relics takes (compare data/items/utility/
-- utility_reliquary_unbidden.lua).
--
-- It is a trap dressed as a reward, as it was on her: it answers only what is SHOWN, and it teaches the
-- bearer to believe that having the measure of every visible thing is the same as being unbeatable. The
-- one hand it can never answer is a mage who never shows it anything -- which is precisely the certainty
-- it quietly trains into you (docs/story.md, "The Arcanum").
--
-- SHIPPED FIDELITY: the trait it carries is a counter-magic reflex; the full "glance and cast it back,
-- then fill the board with copies of yourself" is deferred new work (see the trait and the chapter).
--
-- No `class`, no `price`, `noSteal`: there is one, and nothing takes it off you. The FLAVOR carries this
-- general's fragment of the Gate Below's location (docs/item-text.md: story, not a rule; the tooltip
-- prints it italic at the foot). The Gate is keyed off the QUEST finished, never off this item (questGate
-- in models/quest.lua), so stashing it, wearing it, or losing it can never cost the endgame.
return {
    name = "The Codex Unanswered",
    description = "A single-target spell aimed at you is answered and unravelled, for mana.",
    flavor = "Sublimitas's book, and it has never met a spell it did not already know. Tooled on the " ..
        "spine: \"where the shelves answer only themselves, and the readers were spent\".",
    sprite = "assets/items/codex_unanswered.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_perfect_recall" },
    bonus = { magicDefense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
}
