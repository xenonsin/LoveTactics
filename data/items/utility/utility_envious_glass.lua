-- Lifted off Livia's body, and it kept her rule (data/traits/trait_covetous_reflection.lua): carry the
-- Glass and you open every fight wearing a copy of your strongest foe -- you become the thing you killed,
-- the shape every one of the seven relics takes (compare data/items/utility/utility_codex_unanswered.lua).
--
-- It is a mirror (Snow White's -- fairest of them all, poison rather than be second), and it differs in
-- TYPE from the armor, spear, mail, reliquary, bow and tome of the other relics, as the seven keys
-- require. It is the completed Great Work the Crucible only ever sold you a fragile imitation of
-- (data/items/utility/utility_philosophers_stone.lua): the copy it conjures is not fragile.
--
-- A trap dressed as a reward, as it was on her: you fight in borrowed shapes and never your own, and it
-- teaches the bearer that being able to wear anyone is the same as being someone. It is not.
--
-- SHIPPED FIDELITY: the trait it carries is the phase-one copy. The Host, the Pall, Covet and Grudge are
-- deferred new work (see the trait and the chapter).
--
-- No `class`, no `price`, `noSteal`. The FLAVOR carries this general's fragment of the Gate Below's
-- location (docs/item-text.md: story, not a rule). The Gate is keyed off the QUEST finished, never off
-- this item (questGate in models/quest.lua), so stashing it, wearing it, or losing it can never cost the
-- endgame.
return {
    name = "The Envious Glass",
    description = "At the opening bell, a copy of your strongest foe stands and fights at your side.",
    flavor = "Livia's mirror, and it has never once shown her own face. Etched around the rim: " ..
        "\"below the vats, where the shapeless envy the shaped\".",
    sprite = "assets/items/envious_glass.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_covetous_reflection" },
    bonus = { magicDefense = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } },
}
