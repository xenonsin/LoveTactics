-- BLIGHT: the same tiles, afterwards.
--
-- This is not a hazard the Vengeful Spirit lays on top of the board. It IS the board -- every square
-- of New Growth the stag laid while it was running away from the company, turned in one instant at
-- the threshold (models/hazard.lua's convert, driven by trait_boss_phases' `ground` response). Same
-- count, same places, same tiles the party has spent the whole first half of the fight standing on
-- because standing on them was free healing.
--
-- UNSIDED, LIKE THE GROUND IT WAS. Whatever is left of the wood the stag brought with it dies here
-- too. A blight that spared the spirit's own escort would read as a spell being cast at the party; one
-- that kills the wolves it spent twenty turns mending reads as a place going wrong, which is the only
-- thing this fight is about. The symmetry is also why it was worth leaving the allegiance check off
-- New Growth in the first place -- the pair are one statement made twice.
--
-- IT HURTS ONLY WHILE YOU ARE ON IT (status_blighted, which unlike poison does not `linger`). So the
-- reversal denies ground rather than billing bodies: nobody takes a lump at the threshold, they lose
-- the floor they were standing on and have to move. That is what lets the turn arrive with no warning
-- at all -- a surprise you can walk out of is a decision, and a surprise you cannot is an ambush.
--
-- IT DOES NOT SPREAD, and the missing `spread` field is load-bearing rather than an omission. Fire
-- creeps into burnable ground and this easily could (Hazard.spread is tag-driven and would need one
-- line), but the spirit's ammunition is a COUNT -- it detonates these tiles one at a time and can run
-- out (data/items/ability/ability_swailing.lua). Ground that made more of itself would refill the
-- magazine forever, and the whole loop the fight is built on -- how far you let it run is how much it
-- has to throw at you -- would stop closing.
--
-- `disposition = "hostile"` so the enemy AI routes around it, which matters for exactly one body and
-- not for the spirit: the spirit is immune and walks it freely, and anything else the floor still has
-- standing now has to go the long way round. The party is on foot and can read the marks.
return {
    name = "Blight",
    description = "Takes from whatever stands on it, and stops when you leave.",
    tags = { "nature", "poison" },
    duration = 60,          -- the same clock New Growth ran: these are the same tiles, still there
    disposition = "hostile", -- the AI paths around it; the one body immune to it does not care
    onEnter = function(ctx)
        -- No allegiance check, for the reason the header gives and the same reason New Growth has none.
        ctx.applyStatus(ctx.unit, "status_blighted", { magnitude = ctx.amount })
    end,
}
