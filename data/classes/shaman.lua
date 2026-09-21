-- Shaman -- hunter x mage multiclass discipline.
-- Signature mechanic: BINDING -- a spirit put into a thing and made to stay there.
-- Exemplar: a spirit-caller (character_shaman, NEW -- pending), met as a MENTOR.
-- Gate: earned advancement -- requires a hunter subclass AND a mage subclass unlocked, which opens
-- quest_hunters_lodge_the_spirit_wood (pending). See docs/disciplines-plan.md.
--
-- THE PREMISE WIDENED ON 2026-09-20 AND NOTHING WAS UNWOUND. It read "Spirit totems -- summon elemental
-- spirits bound to hazards", and the seven items that shelf already ships (Call Spirit, Bind Spirit,
-- Spirit Fetish, Ancestor Mask, Ghost-Wind, Old Wind, Yoked Company) are untouched by the change --
-- every one of them is still exactly what it was. What changed is which WORD the discipline is named by.
--
-- THE OLD WORD WAS THE WRONG HALF OF ITS OWN MECHANIC. "Summon" describes Call Spirit and describes
-- nothing else on the shelf: Bind Spirit's whole trick is that the squall belongs to the spirit rather
-- than to the ground, the Ancestor Mask binds an element to what you called, Ghost-Wind binds a spirit
-- to the weather it walks through. The verb those share is BINDING -- a spirit put into a thing and made
-- to stay there -- and the summoning was only ever the first thing bound into.
--
-- WHICH IS ALSO WHY THE HEXES BELONG HERE (models/curse.lua, 2026-09-20) rather than on a discipline of
-- their own. A curse is a spirit bound into somebody's gear. It is the same verb, the same craft and the
-- same counterplay -- bindings can be undone, by a spirit's throat or by a priest's rite -- pointed at an
-- object instead of at a patch of ground. A separate Hexer would have been a second set of names for one
-- idea, which is the trade docs/class-fold.md exists to refuse.
--
-- AND IT SEPARATES THIS FROM THE TOTEMIST, which the old word did not. Totemist (hunter x priest) plants
-- stakes that project fields; a Shaman under "spirit totems" was a stake that walked. Two neighbouring
-- disciplines with one silhouette between them is the drift; binding is what tells them apart.
return {
    name    = "Shaman",
    description = "Binds spirits into things and makes them stay. Into the ground, where each one fights "
        .. "on its own -- or into a body's gear, where it becomes a curse.",
    exemplar = "character_shaman", -- NEW, pending
    requires = { hunter = 9, mage = 9 },
}
