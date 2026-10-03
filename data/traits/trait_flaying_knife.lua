-- THE FLAYING KNIFE's second half (data/items/weapon/weapon_flaying_knife.lua): the Skin-Thief's trick worn small
-- (reviewed 2026-10-01..03, "Envy's Bestiary", round 2). The knife's own effect Halts what it cuts for 1 turn;
-- this lends the bearer one of that body's abilities ON LOAN (Combat.lendItem) and one more action to cast it
-- with, this turn only. The loan comes back the moment it is used, or when the turn ends, whichever is first --
-- the Copycat's leash (data/traits/trait_copycat.lua), held to one turn.
local function lendable(target)
    local Character = require("models.character")
    for _, it in ipairs(Character.eachItem(target.char)) do
        if it.type == "ability" and it.activeAbility and not it.bound and not it.noCopy and not it.onLoan then
            return it
        end
    end
    return nil
end

local function recall(ctx)
    local Character = require("models.character")
    local Combat = require("models.combat")
    for _, it in ipairs(Character.eachItem(ctx.unit.char)) do
        if it.flayed then Combat.recallLoan(ctx.combat, ctx.unit, it) end
    end
end

return {
    name = "Flaying Knife",
    description = "A hit lets you cast one of the target's abilities this turn.",
    onCast = function(ctx)
        local u, combat, item = ctx.unit, ctx.combat, ctx.item
        if not (u and u.alive and combat and item) then return end
        if item.flayed then recall(ctx) return end
        if item.id ~= "weapon_flaying_knife" or (ctx.damageDealt or 0) <= 0 or not ctx.tx then return end
        local Combat = require("models.combat")
        local target = Combat.unitAt(combat, ctx.tx, ctx.ty)
        if not (target and target.alive and target.side ~= u.side) then return end
        local ability = lendable(target)
        if not ability then return end
        recall(ctx) -- one borrowed ability at a time
        if Combat.lendItem(combat, u, ability.id, { flayed = true }) then Combat.grantExtraAction(u, 1) end
    end,
    onTurnEnd = recall,
}
