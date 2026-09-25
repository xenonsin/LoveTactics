-- ECHO's rule (data/items/utility/utility_echo.lua): an ally who hears the bearer (Combat.hears, turned
-- on its own side -- within four tiles, or Wet anywhere) casts an ability, and the bearer is lent a copy
-- of it for the fight (Combat.lendItem), its damage and healing halved, until the bearer uses it. One
-- echo held at a time; an echo is never echoed, and nothing bound or unstealable is copied.
--
-- The Copycat's loan (data/traits/trait_copycat.lua) pointed at your own side rather than at a foe's
-- weapon, and recalled the same way: the loan is swept at the end of the fight whatever happens.
local function halve(v)
    if type(v) == "number" and v > 0 then return math.max(1, math.floor(v / 2)) end
    return v
end

return {
    name = "Echo",
    description = "When an ally who hears you casts an ability, you get a copy of it at half power until you use it.",
    onAnyCast = function(ctx)
        local u, caster, item = ctx.unit, ctx.caster, ctx.castItem
        if not (u and u.alive and caster and item) or caster == u then return end
        if item.type ~= "ability" or item.echo or item.bound or item.noSteal or item.noCopy or item.onLoan then return end
        local Combat = require("models.combat")
        if not Combat.hears(u, caster, true) then return end
        local Character = require("models.character")
        for _, it in ipairs(Character.eachItem(u.char)) do
            if it.echo then return end
        end
        local copy = Combat.lendItem(ctx.combat, u, item.id, { echo = true })
        local ab = copy and copy.activeAbility
        if ab then
            ab.damage = halve(ab.damage)
            ab.heal = halve(ab.heal)
            ab.amount = halve(ab.amount)
        end
    end,
    onCast = function(ctx)
        if ctx.item and ctx.item.echo then
            require("models.combat").recallLoan(ctx.combat, ctx.unit, ctx.item)
        end
    end,
}
