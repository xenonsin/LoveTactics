-- COPYCAT's rule (data/items/utility/utility_copycat.lua): the mimic slime's Mimicry, worn small. When a
-- foe's weapon hits the bearer, the bearer gets a copy of that weapon ON LOAN until they use it (one at a
-- time) -- Combat.lendItem / Combat.recallLoan. A loan never reaches a save or the loadout.
return {
    name = "Copycat",
    description = "When a foe's weapon hits you, you get a copy of it until you use it.",
    onDamaged = function(ctx)
        local u, foe = ctx.unit, ctx.attacker
        if not (u and u.alive and foe and foe.char) or foe.side == u.side or (ctx.amount or 0) <= 0 then return end
        local Character = require("models.character")
        for _, it in ipairs(Character.eachItem(u.char)) do
            if it.copycat then return end
        end
        for _, it in ipairs(Character.eachItem(foe.char)) do
            if it.type == "weapon" and not it.bound and not it.noCopy and not it.noSteal then
                require("models.combat").lendItem(ctx.combat, u, it.id, { copycat = true })
                return
            end
        end
    end,
    onCast = function(ctx)
        if ctx.item and ctx.item.copycat then
            require("models.combat").recallLoan(ctx.combat, ctx.unit, ctx.item)
        end
    end,
}
