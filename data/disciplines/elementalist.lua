-- Elementalist -- mage subclass. The first Tier-A shelf: its stock already exists (the sigils).
-- Signature mechanic: Sigils -- aura tiles that reshape spells cast beside them (careful / twin /
-- range / speed).
-- Exemplar: a dedicated Elementalist (character_elementalist), met as a MENTOR -- a sigil-adept who
-- reshapes a spell by where it is cast. (Gyeom / the generic mage stays a root; the "starred reuse" open
-- call in docs/disciplines-plan.md is resolved toward a fresh body.)
-- Gate: one quest in the mage (Arcanum) line -- the_praised_working (slot 3).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Elementalist",
    description = "The sigil-adept. Lays aura tiles that reshape any spell cast beside them. Careful, twinned, farther, faster.",
    classes = { "mage" },
    exemplar = "character_elementalist", -- was character_mage (the generic root body); dedicated exemplar authored
    requiredQuests = { "quest_arcanum_slot_03" },
}
