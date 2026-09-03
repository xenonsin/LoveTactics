-- Necromancer -- mage subclass.
-- Signature mechanic: Corpse-raise -- enemies that die on the field rise as your undead.
-- Exemplar: an Adept of the inner circle (character_necromancer, NEW -- pending), met as a BOSS --
-- the gate quest already fields the raised dead as the Arcanum's own working material, so the
-- exemplar walks into a fight that is demonstrating her mechanic before she arrives.
-- Gate: one quest in the mage (Arcanum) line -- the_inner_circle (slot 4).
-- A subclass opens no earlier than slot 3: a discipline handed over on a line's first or
-- second quest is not earned advancement, it is a welcome gift.
-- See docs/disciplines-plan.md.
return {
    name    = "Necromancer",
    description = "The raiser. Enemies that die on the field get back up as yours.",
    exemplar = "character_necromancer", -- NEW, pending
    requires = { mage = 4 },
}
