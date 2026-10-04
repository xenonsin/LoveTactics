-- STIR: how close Desidia is to waking ("Sloth's Bestiary", slice G, 2026-10-04; models/desidia.lua). Every attack
-- or ability used anywhere on the board while she sleeps adds one, and at 10 she wakes and takes every turn she has
-- banked at once. The badge is the clock the company reads: the fight's own noise is what wakes her.
--
-- WHY A NEW WORD. Nothing else in the game counts the board's noise toward a wake; Drowsy counts the other way (a
-- body sinking toward sleep) and Banked is what she will DO when she wakes, not how near it is.
--
-- Not a debuff and undispellable: it is on her by her own design, and a strip that reset it would be a free answer.
-- Cleared whenever she wakes or goes back to sleep.
return {
    name = "Stir",
    abbr = "Stir",
    description = "Stir: every attack or ability on the board adds one. At 10, she wakes.",
    color = { 0.700, 0.760, 0.860 }, -- badge tint (thin ice)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    magnitude = 1,
    stacks = 10,
}
