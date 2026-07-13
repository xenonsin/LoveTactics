-- Frozen: encased in ice. Like Stun, it shoves the target down the turn order once on cast (onApply
-- adds `magnitude` ticks to its initiative) -- a frozen unit is a delayed unit. But ice is brittle:
-- while frozen the target takes extra damage from CRUSH and FIRE hits (`vulnerable`, folded into
-- Combat.mitigatedDamage just like Wet's lightning weakness) -- shatter the ice with a hammer, or
-- melt it with flame. A debuff, so Cure (data/items/ability/ability_cure.lua) strips it.
return {
    name = "Frozen",
    abbr = "Frz",
    description = "Iced over: delayed, and takes extra damage from crush and fire.",
    color = { 0.55, 0.80, 0.95 }, -- badge tint (glacier blue)
    magnitude = 5,                -- ticks added to the target's initiative (the freeze delay)
    -- A generous window so the crush/fire vulnerability actually survives the caster's own turn: a
    -- slow AoE freeze (Blizzard, speed 5) advances the clock several ticks the moment it resolves, and
    -- a 5-tick badge would wear off before anyone could exploit it. The delay above lands regardless
    -- (onApply is not undone by expiry) -- this is how long the ice stays brittle.
    duration = 12,
    debuff = true,                -- removable by Cure
    vulnerable = { crush = 6, fire = 6 }, -- bonus damage taken from crush- and fire-tagged hits
    onApply = function(ctx)
        ctx.unit.initiative = ctx.unit.initiative + (ctx.magnitude or 0)
    end,
}
