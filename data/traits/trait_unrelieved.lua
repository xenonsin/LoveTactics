-- Acedia's rule, and the fourth general's whole fight (docs/story.md, "The Bastion: sloth, designed").
--
-- She does not fight to win. She fights to be RIGHT. At combat start she swears the player's party
-- into pairs nobody chose, and every unit that ends its turn away from the partner it was given takes
-- the bite (data/status/status_sworn.lua). That is a rigged demonstration -- she is producing evidence
-- that people abandon each other under pressure, on your units, because she needs the board to say
-- what she needs to be true.
--
-- The tactical shape is deliberately the opposite of Wrath's. Ira punishes you for trading blows and
-- wants you to burst her down; Acedia punishes you for SPREADING OUT and pins the party into a huddle,
-- which is exactly where her company's polearms want it. Sloth is not a damage race. It is being stuck.
--
-- Pairs are struck once, at combat start, and never re-cut: a partner who falls leaves the survivor
-- sworn to a corpse and taking the bite forever (see the status). An oath she imposed does not release
-- anyone for dying, and un-pairing on death would quietly reward killing your own.
--
-- The relic lifted off her carries the same rule for whoever wears it
-- (data/items/weapon/weapon_forsworn_pike.lua) -- kill a sin, wear it.
return {
    name = "The Unrelieved",
    description = "Swears the enemy party into pairs. Each one that ends its turn apart from its partner is bitten.",
    magnitude = 6, -- damage per turn ended apart; handed to the status as its magnitude
    onCombatStart = function(ctx)
        -- The side to swear is whoever is NOT hers. Read off the bearer so the relic works the same
        -- way when a player wears it: it always swears the other side.
        local foes = {}
        for _, u in ipairs(ctx.combat.units) do
            if u.alive and u.side ~= ctx.unit.side then foes[#foes + 1] = u end
        end
        if #foes < 2 then return end -- nobody to swear to anybody

        -- Pair them off in turn order: 1-2, 3-4, ... An odd body out is sworn to the FIRST unit, so
        -- everyone carries the oath and nobody is quietly exempt.
        for i = 1, #foes, 2 do
            local a, b = foes[i], foes[i + 1] or foes[1]
            if a ~= b then
                local sa = ctx.applyStatus(a, "status_sworn", { magnitude = ctx.def.magnitude })
                local sb = ctx.applyStatus(b, "status_sworn", { magnitude = ctx.def.magnitude })
                -- Status.instantiate keeps only its own declared fields, so the partner is stamped
                -- onto the live instance afterwards. It is a unit reference, not an id: two copies of
                -- the same blueprint must be able to be sworn to different people.
                if sa then sa.partner = b end
                if sb then sb.partner = a end
            end
        end
        ctx.log("system", "\"You will leave each other. You always do.\"")
    end,
}
