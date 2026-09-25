-- HER COURT: the Reliquary of the Unbidden's rule since the rework (settled on review 2026-09-25,
-- data/items/utility/utility_reliquary_unbidden.lua). Luxuria's strength was never her own -- it was the
-- army standing around her -- and the relic hands that over as a number: a tenth again of the bearer's own
-- damage and defense for every body it is holding right now.
--
-- "Holding" is read off each charm's own `charmer` stamp (the same reading Trait.shareTargets makes), so a
-- flat-out ally never counts and a body only counts while the charm lasts. Live, not banked: the bonus
-- rises the moment a charm lands and falls the moment one breaks, which is what makes it a relic about
-- keeping them rather than about having once taken them.
local PER = 0.10

return {
    name = "Her Court",
    description = "+10% damage and defense for each foe you currently have Charmed.",
    live = function(ctx)
        local combat, me = ctx.combat, ctx.unit
        if not combat then return nil end
        local Status = require("models.status")
        local n = 0
        for _, u in ipairs(combat.units or {}) do
            if u ~= me and u.alive then
                local st = Status.get(u, "status_charm")
                if st and st.charmer == me then n = n + 1 end
            end
        end
        if n == 0 then return nil end
        local stats = me.char and me.char.stats or {}
        local function base(stat)
            local v = stats[stat]
            if type(v) == "table" then v = v.current end
            return v or 0
        end
        return {
            damage = math.floor(base("damage") * PER * n + 0.5),
            defense = math.floor(base("defense") * PER * n + 0.5),
        }
    end,
}
