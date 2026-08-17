-- TORPOR: Sloth's rule, one rank down, and the mechanic the tundra circle is built on.
--
-- Acedia's Unrelieved swears the whole enemy party into PAIRS at the opening bell, and each body that
-- ends its turn away from its partner is bitten (data/traits/trait_unrelieved.lua). It is a standing tax
-- on moving independently, applied to everyone at once, before anybody has taken a turn.
--
-- Torpor is the same idea taught one body at a time: it swears ONE pair, and only when it acts. So the
-- lesson arrives in the middle of a fight, on two units the player can watch, instead of as an opening
-- announcement about the whole company.
--
-- WHY SLOTH TAKES TURNS RATHER THAN HEALTH. The tundra's floor is `ice` -- the one terrain in the game
-- that does not tax a step (data/biomes/tundra.lua) -- so this is the board where crossing is free and
-- both lines close as fast as they like. A circle whose stratum charges nothing for movement has to
-- charge for something else, and what it charges is the clock.
--
-- Fires on onCast: it does this by doing it, which is what makes the pairing attributable to a body you
-- can kill rather than to the weather.
return {
    name = "Torpor",
    description = "Swears two foes together as it acts. Each one that ends its turn apart is bitten.",
    magnitude = 5,
    onCast = function(ctx)
        if (ctx.trait.stacks or 0) > 0 then return end -- one oath, so a long fight is not a lock

        local foes = {}
        for _, u in ipairs(ctx.combat.units) do
            if u.alive and u.side ~= ctx.unit.side then foes[#foes + 1] = u end
        end
        if #foes < 2 then return end

        local a, b = foes[1], foes[2]
        local sa = ctx.applyStatus(a, "status_sworn", { magnitude = ctx.def.magnitude })
        local sb = ctx.applyStatus(b, "status_sworn", { magnitude = ctx.def.magnitude })
        -- Status.instantiate keeps only its own declared fields, so the partner is stamped onto the live
        -- instance afterwards -- and it is a unit reference rather than an id, because two copies of one
        -- blueprint must be able to be sworn to different people.
        if sa then sa.partner = b end
        if sb then sb.partner = a end
        ctx.trait.stacks = 1
        ctx.log("system", "\"Stay together. It is easier that way, and it will not help.\"")
    end,
}
