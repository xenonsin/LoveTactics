-- WANTING: the Hollow Crown, worn (data/items/armor/armor_hollow_crown.lua; slice D). +3 Damage for each DIFFERENT
-- status on the bearer, good or bad -- two stacks of one Bleed are one want. A LIVE passive (Trait.liveBonus), read
-- off the badges the bearer carries right now, so it rises and falls with the fight.
--
-- The engine's own bookkeeping markers (`hideLog`: Channeling, Downed) are not wants -- they are the engine keeping
-- time, not something the fight hung on the body.
return {
    name = "Wanting",
    description = "+3 damage for each different status on you, good or bad.",
    per = 3,
    live = function(ctx)
        local seen, n = {}, 0
        for _, s in ipairs(ctx.unit.statuses or {}) do
            if s.def and not s.def.hideLog and not seen[s.id] then
                seen[s.id] = true
                n = n + 1
            end
        end
        if n == 0 then return nil end
        return { damage = n * require("models.trait").param(ctx.trait, "per", 3) }
    end,
}
