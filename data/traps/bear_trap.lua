-- Bear trap: steel jaws under the leaf litter. The one trap that does BOTH halves -- it bites the
-- first opponent across it and holds them there (data/status/status_root.lua), where
-- data/traps/spike_trap.lua only bites and data/traps/snare_trap.lua only holds.
--
-- That combination is the whole of what it costs more to set. A spike trap is damage the victim walks
-- away from; a snare is a tile lost. A bear trap turns one wrong step into a body that is both hurt
-- and standing exactly where you left it -- which is what makes it a SETUP rather than an attack, and
-- the reason it belongs on the Lodge's shelf: the hunter's shelf is setup and then payoff
-- (docs/classes.md), and this is the setup half sold on its own.
--
-- The damage is under a spike trap's, deliberately: what you are paying for is the root, and a trap
-- that did the most damage AND took the turn would simply retire the other two. Tougher than either of
-- them (health 6) because it is a machine rather than a hole -- a revealed bear trap takes real work
-- to clear off the path.
return {
    name = "Bear Trap",
    description = "Jaws under the leaves: bites the first enemy across it and roots them where they stand.",
    sprite = "assets/traps/bear_trap.png",
    health = 6,
    tags = { "trap", "pierce", "physical" },
    damage = 12, -- pre-mitigation; under a spike trap's 18, because the root is the rest of the price
    onTrigger = function(ctx)
        ctx.damage(ctx.victim, ctx.trap.amount or ctx.trap.def.damage, ctx.trap.tags)
        ctx.applyStatus(ctx.victim, "status_root")
    end,
}
