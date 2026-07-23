-- A shield, so it swaps Wait into Defend (docs/weapons.md). Its extra is that the knight gives the guard
-- AWAY: bracing hands status_lent_guard to every adjacent ally and takes status_given_guard for itself,
-- so the holder's own defense drops by exactly what the line gains.
--
-- Quest-only: `class` with no `price`.
--
-- The two statuses are a matched pair built for this -- Given Guard is a flat -6 and Lent Guard the same
-- number with the sign flipped -- so nothing is created and the ledger balances. What the shield sells is
-- the DIRECTION: the knight is the most armoured body in the party and is therefore the one whose armour
-- is worth the least, because nobody sensible is attacking it. This moves that surplus onto the people
-- being attacked.
--
-- It is the sharpest version of a question the whole shelf keeps asking. An Oathkeeper Shield shares the
-- brace and keeps its own; a Shared Bulwark lays it on the ground; the Martyr's Shield takes the wounds
-- outright. This one is the only one where the knight ends up WORSE than they started, which is what
-- makes it a real decision rather than a bigger number.
--
-- Note the loan spreads and the debt does not: two allies beside you get a full Lent Guard each and the
-- knight still pays one Given Guard. That asymmetry is intentional and is where the item's power lives --
-- it rewards planting inside the formation rather than at the edge of it.
--
-- It reads as the shield-shaped sibling of data/items/weapon/weapon_lending_blade.lua, which does the
-- same trade off a swing and takes the guard from an enemy instead of from itself.
return {
    name = "The Given Guard",
    description = "Replaces Wait with Defend: lend your guard to every ally beside you, and go without it yourself.",
    flavor = "A squire asks what the shield is for. The answer is that it was never especially for you.",
    sprite = "assets/items/given_guard.png",
    type = "armor",
    tags = { "shield", "holy" },
    class = "knight",
    bonus = { defense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
    resist = { physical = { 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5 } },
    waitBehavior = {
        kind = "defend",
        speed = 3,
        -- A buckler's brace, kept: the knight still braces, and then hands the guard over on top. Without
        -- that the stance would be a pure downgrade for the holder and nobody would ever plant it.
        defense = { 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11 },
        status = "status_given_guard",       -- the debt, on the holder
        coversStatus = "status_lent_guard",  -- ...and the loan, on everyone beside them
    },
}
