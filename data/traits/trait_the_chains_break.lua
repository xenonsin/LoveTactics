-- THE CHAINS BREAK: the Titan's second rule (data/items/utility/utility_the_chains_break.lua), and the half of
-- the Titan's Chain that is not the swing (data/items/weapon/weapon_titans_chain.lua). Approved 2026-09-30 on
-- Pride's bestiary review: below half health, +2 movement and +4 damage. The +4 sits one over the oni's Horn Out
-- (+3), and is the number the author wrote on the drop.
--
-- A LIVE PASSIVE (Trait.liveBonus), read off the bar as it stands: the rule is "below half", and a body healed
-- back over the line is under it no longer. On the Titan the chains (utility_the_gods_chains, -2 movement) hold
-- it to 1 tile a turn, so this +2 is the chains coming off; the first time it crosses, the log says so.
local function broken(unit)
    local hp = unit and unit.char and unit.char.stats and unit.char.stats.health
    return hp and hp.max and hp.max > 0 and (hp.current or 0) < hp.max / 2
end

return {
    name = "The Chains Break",
    description = "Below half health: +2 movement and +4 damage.",
    notAReaction = true,
    broken = broken,
    live = function(ctx)
        if not broken(ctx.unit) then return nil end
        return { movement = 2, damage = 4 }
    end,
    onDamaged = function(ctx)
        local u = ctx.unit
        if u._chainsBroken or not broken(u) then return end
        u._chainsBroken = true
        ctx.log("action", string.format("%s's chains break.", (u.char and u.char.name) or "Its"), u)
    end,
}
