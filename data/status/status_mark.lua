-- Mark: a hunter's quarry-sign. Defense and magic defense are cut, so every follow-up hit lands
-- harder. Mechanically identical to Acid (a statBonus armor cut), but themed as a target painted for
-- the kill rather than armor eaten -- and it pairs with abilities that key a bonus off `hasStatus(t,
-- "status_mark")` (Called Shot, Executioner's Eye).
return {
    name = "Mark",
    abbr = "Mrk",
    description = "Marked: defense, magic defense and Luck are reduced, inviting a finishing blow.",
    color = { 0.769, 0.331, 0.331 }, -- badge tint (crimson)
    duration = 10, -- ~2 turns at Status.TICKS_PER_TURN: a mark someone can still act on
    debuff = true,                -- removable by Cure
    -- THE LUCK CUT IS WHAT "PAINTED FOR THE KILL" ACTUALLY MEANS. Before accuracy this status was, in
    -- its own words, "mechanically identical to Acid" and told apart only by theme -- both ate armour.
    -- A marked body should be easier to HIT, not merely softer once hit, and luck is the stat that says
    -- so: it lowers the quarry's Avoid and hands every attacker back the crit chance its luck was
    -- denying them (docs/accuracy.md). The two halves of "finish this one" in one status.
    --
    -- This is also what finally makes the Lodge's whole setup-then-payoff shelf pay into accuracy at
    -- once: Mark Target, the Executioner's Eye, the Scent Marker, the Falconer's hawk and the Mark of
    -- Heresy all apply this, and the hunter house is the roster's aiming house (skill 8).
    statBonus = { defense = -5, magicDefense = -5, luck = -4 },
    -- A marked body cannot vanish. The rule belongs to the DEBUFF, not to an item: the first draft of
    -- the Inquisitor shelf sold a lamp that did this, which made "painted for the kill" mean something
    -- different depending on who had been shopping. Here it holds for every Mark in the game -- the
    -- hunter's quarry-sign, the Mark of Heresy, a trap's -- and it gives Cure a real decision to make,
    -- since cleansing the Mark is now also how you get your rogue out of sight again.
    forbids = "status_invisible",
}
