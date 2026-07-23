-- Marksman's Lens: the payoff half of the hunter's signature verb. The shelf is "setup, then payoff"
-- (docs/classes.md, gluttony: `mark`), and until now everything on it did the SETUP -- Mark Target
-- applies the mark, the Executioner's Eye stacks a mark onto a stun, the Scent Marker paints a whole
-- ring of them. Nothing rewarded the shot that followed. This does: the bearer's RANGED attacks bite
-- for `bonus` extra against a Marked foe, so the mark that was only ever a defense-cut now also pulls
-- the trigger harder.
--
-- RANGED ONLY, and that gate is the identity, not a limiter. The whole shelf is "most of it gated on a
-- bow beside it in the grid" -- a hunter is the one who decided the kill before the shot, from range.
-- A Marked foe in the bearer's face is somebody else's problem; this charm is about the arrow already
-- in the air. It reads `ctx.hasTag("ranged")`, the tag every bow and longbow carries.
--
-- It reaches damage through the same `damageBonusVs` seam as the Cutpurse's Tally
-- (models/trait.lua -> Combat.dealDamage): a pure, preview-honest addition to the pre-mitigation base,
-- so armor still applies and the hover shows the extra before the shot lands. Flat rather than a forge
-- curve, like its rogue sibling -- the scaling is how many marks the party lands, not how honed the
-- lens is.
return {
    name = "Marksman's Lens",
    description = "Your ranged attacks deal extra damage against a Marked foe.",
    bonus = 6, -- flat, pre-mitigation, only on a ranged strike into a Marked target
    damageBonusVs = function(ctx)
        if not ctx.hasTag("ranged") then return 0 end
        if not ctx.hasStatus(ctx.target, "status_mark") then return 0 end
        return ctx.def.bonus or 6
    end,
}
