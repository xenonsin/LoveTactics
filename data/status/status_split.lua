-- SPLIT: one of several bodies standing on ONE health pool (Summon's `sharePool`: the same pool table, by
-- reference, so a blow on any of them is a blow on all and a heal on any heals all). Worn by the Many Faced One's
-- copies of the company and by the double Splitting Image makes (models/many_faced.lua).
--
-- What this badge adds is the other half of one pool: ONE DEATH. A body that falls on an empty pool takes every
-- other body on that pool down with it, so no copy is left standing on nothing.
--
-- Not a debuff and never stripped: losing it would leave a body alive on an empty bar.
return {
    name = "Split",
    abbr = "Split",
    description = "Split: shares one health pool with its other bodies. When the pool empties, every one of them falls.",
    color = { 0.560, 0.600, 0.700 }, -- badge tint (a cold mirror-grey)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    onDeath = function(ctx)
        require("models.many_faced").onSplitDeath(ctx.combat, ctx.unit)
    end,
}
