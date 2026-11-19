-- SEAM OPEN: a Faceless Colossus that has just used its second face's kit (trait_two_faces). Creature identity
-- pass, 2026-11-19.
--
-- The heap wears two faces at once -- the one Reshape picks as its body, and the runner-up's kit lent into the
-- cells the first leaves free (models/masks.lua). It had no counter. Now the seam between the two shows the moment
-- it reaches for the lent kit: the next blow that lands on it while this badge stands tears the second face off
-- for the rest of the fight. So the counter is a timing -- wait for it to use what it borrowed, then hit it.
--
-- Open until the start of its next turn: one round of the company's turns to answer it.
return {
    name = "Seam Open",
    abbr = "Seam",
    description = "Seam Open: it just used its second face's kit. The next blow that lands on it tears that kit off for the rest of the fight.",
    color = { 0.820, 0.560, 0.420 }, -- badge tint (a raw edge)
    duration = math.huge,
    hideDuration = true, -- it closes at its next turn, not on the clock
    debuff = true,
    onTurnStart = function(ctx) ctx.expire() end,
}
