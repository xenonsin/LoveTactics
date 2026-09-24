-- KEPT SUITORS's rule (data/items/utility/utility_kept_suitors.lua): the Velvet Queen wore everybody's
-- clothes; the bearer wears their admirers'. While a foe is Charmed by the bearer (status_charm stamped
-- with them as its `charmer`), the bearer adds that foe's armour Defense to their own. Live -- read on
-- every stat read -- so it is there exactly as long as the charm holds and not a tick longer.
--
-- NO KILL IN IT, on purpose: Gula's Maw already pays a body for what it has killed, and this is Lust's
-- version of having something off somebody -- they are still standing there, wanting you.
local function armourDefense(char)
    local Character = require("models.character")
    local total = 0
    for _, item in ipairs(Character.eachItem(char)) do
        local d = item.type == "armor" and item.bonus and item.bonus.defense
        if type(d) == "number" and d > 0 then total = total + d end
    end
    return total
end

return {
    name = "Kept Suitors",
    description = "While a foe is Charmed by you, add its armour's Defense to your own.",
    live = function(ctx)
        local combat = ctx.combat
        if not combat then return nil end
        local Status = require("models.status")
        local total = 0
        for _, u in ipairs(combat.units or {}) do
            if u ~= ctx.unit and u.alive and u.char then
                local charm = Status.get(u, "status_charm")
                if charm and charm.charmer == ctx.unit then total = total + armourDefense(u.char) end
            end
        end
        if total == 0 then return nil end
        return { defense = total }
    end,
}
