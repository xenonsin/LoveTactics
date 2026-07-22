-- Lifted off Gula's body, and it kept her rule (data/traits/trait_ravenous.lua): carry the Maw and your
-- own strikes feed you -- you heal on the hit, and you become the thing you killed, the shape every one
-- of the seven relics takes (compare data/items/utility/utility_codex_unanswered.lua).
--
-- It is the trophy she took from the warden she killed to begin her fall, now the vessel of her
-- appetite. It is a trap dressed as a reward, as it was on her: the heal rewards the long trade, and the
-- long trade is exactly the losing line against anything that grows on it. It teaches the bearer to
-- linger, to grind, to never stop -- which is the fall it was cut from.
--
-- SHIPPED FIDELITY: the trait it carries is the heal-on-hit half. The DEVOUR-THE-FALLEN finale mechanic
-- (any downed unit adjacent to her consumed toward full) is deferred new work (see the trait and the
-- chapter).
--
-- No `class`, no `price`, `noSteal`: there is one, and nothing takes it off you. The FLAVOR carries this
-- general's fragment of the Gate Below's location (docs/item-text.md: story, not a rule). The Gate is
-- keyed off the QUEST finished, never off this item (questGate in models/quest.lua), so stashing it,
-- wearing it, or losing it can never cost the endgame.
return {
    name = "Maw of the Unfed",
    description = "Your strikes feed you: heal on every blow you land.",
    flavor = "A trophy taken from the warden she killed first, and it has never once been full. Cut into " ..
        "the horn: \"at the heart of the wood the hunt hollowed out\".",
    sprite = "assets/items/maw_of_the_unfed.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_ravenous" },
    bonus = { health = { 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16 } },
}
