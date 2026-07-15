-- Spike trap: a one-shot hazard that stabs the first opponent to cross its tile. Deals flat
-- damage (mitigated by the victim's defense + tag resist, like any hit). See models/trap.lua for
-- the hook contract; ctx.damage / ctx.victim / ctx.trap are provided.
return {
    name = "Spike Trap",
    description = "Stabs the first enemy to cross its tile, then breaks.",
    sprite = "assets/traps/spike_trap.png",
    health = 6,                            -- HP: how much damage a revealed trap soaks before it breaks
    tags = { "trap", "pierce", "physical" },
    damage = 18,                           -- pre-mitigation damage dealt on trigger (base; the placing
                                           -- ability scales it up by its own upgrade level via trap.amount)
    onTrigger = function(ctx)
        ctx.damage(ctx.victim, ctx.trap.amount or ctx.trap.def.damage, ctx.trap.tags)
    end,
}
