-- Frozen: encased in ice. Like Stun, it shoves the target down the turn order once on cast (onApply
-- adds `magnitude` ticks to its initiative) -- a frozen unit is a delayed unit. But ice is brittle:
-- while frozen the target takes extra damage from IMPACT and FIRE hits (`vulnerable`, folded into
-- Combat.mitigatedDamage just like Wet's lightning weakness) -- shatter the ice with a hammer, or
-- melt it with flame. A debuff, so Cure (data/items/ability/ability_cure.lua) strips it.
--
-- The blunt tag is `impact`, not `crush`. Both words were in the tree at once, and the split made this
-- vulnerability unreachable: every mace, hammer and censer in the game tags `impact`, so a hammer could
-- never shatter the ice it had just made. `crush` lost -- it named two items against `impact`'s twenty --
-- and the two holdouts (ability_shatter_strike, weapon_stone_fists) were retagged rather than this line
-- being written to match them.
return {
    name = "Frozen",
    abbr = "Frz",
    description = "Iced over: delayed, and takes extra damage from impact and fire.",
    color = { 0.55, 0.80, 0.95 }, -- badge tint (glacier blue)
    magnitude = 5,                -- ticks added to the target's initiative (the freeze delay)
    shovesInitiative = "magnitude", -- the delay the aim preview quotes (Status.initiativeShove); == onApply's shove
    -- A generous window so the impact/fire vulnerability actually survives the caster's own turn: a
    -- slow AoE freeze (Blizzard, speed 5) advances the clock several ticks the moment it resolves, and
    -- a 5-tick badge would wear off before anyone could exploit it. The delay above lands regardless
    -- (onApply is not undone by expiry) -- this is how long the ice stays brittle.
    duration = 12,
    debuff = true,                -- removable by Cure
    interruptsChannel = true,     -- ice locks the caster mid-incantation, breaking a channel
    disablesReactions = true,     -- encased in ice: it cannot counter, dodge or otherwise react
    vulnerable = { impact = 6, fire = 6 }, -- bonus damage taken from impact- and fire-tagged hits
    onApply = function(ctx)
        ctx.unit.initiative = ctx.unit.initiative + (ctx.magnitude or 0)
    end,
}
