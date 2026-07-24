-- Mark: a hunter's quarry-sign. Defense and magic defense are cut, so every follow-up hit lands
-- harder. Mechanically identical to Acid (a statBonus armor cut), but themed as a target painted for
-- the kill rather than armor eaten -- and it pairs with abilities that key a bonus off `hasStatus(t,
-- "status_mark")` (Called Shot, Executioner's Eye).
return {
    name = "Mark",
    abbr = "Mrk",
    description = "Marked: defense and magic defense are reduced, inviting a finishing blow.",
    color = { 0.85, 0.30, 0.30 }, -- badge tint (crimson)
    duration = 10, -- ~2 turns at Status.TICKS_PER_TURN: a mark someone can still act on
    debuff = true,                -- removable by Cure
    statBonus = { defense = -5, magicDefense = -5 },
    -- A marked body cannot vanish. The rule belongs to the DEBUFF, not to an item: the first draft of
    -- the Inquisitor shelf sold a lamp that did this, which made "painted for the kill" mean something
    -- different depending on who had been shopping. Here it holds for every Mark in the game -- the
    -- hunter's quarry-sign, the Mark of Heresy, a trap's -- and it gives Cure a real decision to make,
    -- since cleansing the Mark is now also how you get your rogue out of sight again.
    forbids = "status_invisible",
}
