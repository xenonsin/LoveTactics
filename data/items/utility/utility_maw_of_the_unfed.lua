-- Lifted off Gula's body, and it kept her rule -- the new one. Carry the Maw and it BECOMES the thing you
-- last killed: land the killing blow on a wolf and this cell holds the wolf's fangs for the rest of the
-- fight; kill a spider next and it holds Silk Shot. The shape every one of the seven relics takes -- you
-- become the thing you killed (compare data/items/utility/utility_codex_unanswered.lua) -- here with no
-- metaphor left in it (data/traits/trait_palate.lua, models/palate.lua's Palate.morph).
--
-- REWORKED ON REVIEW 2026-09-23 ("the item morphs depending on the last kill"). It carried Ravenous --
-- heal on every landed blow -- which was Gula's old rule, and it goes with it: the heal-on-hit hide
-- (armor_raveners_hide) still carries that for anybody who wants it. This one trades a flat sustain for
-- a question every kill asks: WHICH body do you take last, since that is what you will be holding?
--
-- A body that gives nothing (a hawk, a demon) turns it back into the Maw. The bell always does: what it
-- borrowed is ephemeral and the relic is kept on the borrowed piece's `morphOf` and put back in this same
-- cell (Combat.releaseClaims), so nothing it turns into ever leaves the fight.
--
-- No `price`, `noSteal`: there is one, and nothing takes it off you -- and nothing takes what it has turned
-- into either, since the borrowed piece is the only way back to the relic. The FLAVOR carries this general's
-- fragment of the Gate Below's location (docs/item-text.md: story, not a rule). The Gate is keyed off the
-- QUEST finished, never off this item (questGate in models/quest.lua), so stashing it, wearing it, or
-- losing it can never cost the endgame.
return {
    name = "Maw of the Unfed",
    description = "Becomes the power of the last body you killed, until the fight ends.",
    flavor = "A trophy taken from the warden she killed first, and it has never once been full. Cut into " ..
        "the horn: \"at the heart of the wood the hunt hollowed out\".",
    sprite = "assets/items/maw_of_the_unfed.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_palate" },
}
