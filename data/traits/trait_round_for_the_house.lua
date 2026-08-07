-- Round for the House: the standing rule of the Warbrewer's charm. When the bearer drinks, the allies
-- standing beside them get a share of it.
--
-- Hangs on onCast and fires only for a `consumable`, so it attaches to the whole shelf rather than to any
-- one potion -- a Warbrewer who buys a new draught next week gets it splashed automatically, and this
-- file never learns its name.
--
-- A FAITHFUL APPROXIMATION, said out loud the way this codebase expects. The author's note asked for
-- "draughts affecting adjacent allies", and the honest version of that would re-run the drink's own
-- effect against each neighbour -- which the engine has no shape for: an effect closure is written
-- against one fx context bound to one caster, and re-entering it with a substituted user would run every
-- self-targeted clause on the wrong body. What this does instead is restore each neighbour a share of
-- the two pools a draught actually moves, which covers the restoratives (most of the shelf) honestly and
-- under-delivers on the exotic ones. The alternative was a second effect field on every consumable in
-- the game.
return {
    name = "Round for the House",
    description = "When you drink a draught, the allies standing beside you get a share of it.",
    magnitude = 8, -- health and stamina handed to each neighbour when the bearer drinks
    onCast = function(ctx)
        local item = ctx.item
        if not (item and item.type == "consumable") then return end
        local Combat = require("models.combat")
        local share = ctx.def.magnitude or 8
        local poured = 0
        for _, u in ipairs(Combat.unitsNear(ctx.combat, ctx.unit.x, ctx.unit.y, 1)) do
            if u.alive and u.side == ctx.unit.side and u ~= ctx.unit then
                Combat.applyHeal(ctx.combat, u, share)
                Combat.restoreResource(u.char, "stamina", share)
                poured = poured + 1
            end
        end
        if poured > 0 then
            ctx.log("action", string.format("%s pours a round for the house.",
                (ctx.unit.char and ctx.unit.char.name) or "The brewer"), ctx.unit)
        end
    end,
}
