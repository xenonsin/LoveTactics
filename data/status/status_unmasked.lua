-- UNMASKED: a Faceless knocked out of the face it was wearing (trait_a_thousand_faces; models/faces.lua's
-- Faces.knockOff). Creature identity pass, 2026-11-19.
--
-- THE RACE'S CONSTANT TELL. A Faceless was a borrowed identity and nothing else: it put on whatever answered the
-- nearest of the company, and the player could only react to the face. Now an IMPACT blow that wounds it knocks
-- the face off, and it fights in its own grey body until the end of its next turn -- Reshape (status_faceless)
-- skips its read while this is on it. So "bring a club" is an answer that works under every face it can wear.
--
-- Ends at the close of the bearer's own turn rather than on the clock, as Shamed does: a slow body would
-- otherwise get its face back before it had ever stood without one. A debuff, so it reads as the company's win.
return {
    name = "Unmasked",
    abbr = "Unmk",
    description = "Unmasked: knocked out of its face. It cannot put on a face until its turn ends.",
    color = { 0.780, 0.760, 0.700 }, -- badge tint (bare clay)
    duration = math.huge,
    hideDuration = true, -- it ends with the turn, not on the clock
    debuff = true,
    onTurnEnd = function(ctx) ctx.expire() end,
}
