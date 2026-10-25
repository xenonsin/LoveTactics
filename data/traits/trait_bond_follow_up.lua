-- Bond: Follow-up -- what an A-rank bond with the avatar is worth on the board (models/bond.lua). When the
-- AVATAR lands a blow on a foe standing next to this partner, the partner adds one of its own: Fire
-- Emblem's dual strike, with the avatar as the only hub.
--
-- It is trait_follow_up's rule narrowed to one striker and paid for by the bond instead of by stamina:
-- no ctx.pay(), so it is free, and once a round instead -- latched on the AVATAR's turn flags
-- (Combat.firstThisTurn), which clear when the avatar's next turn starts. The author pointed at the
-- Pincer Banner as the item that already carries the open version for anyone.
--
-- Never authored on a blueprint: Trait.attach hands it to an A-rank partner for the fight
-- (Bond.traitsFor), and nothing else carries it.
return {
    name = "Follow-up",
    description = "When the avatar strikes a foe beside you, you strike it too. Once a round, free.",
    bondFollowUp = true,
    onAllyStrike = function(ctx)
        local striker, foe = ctx.ally, ctx.target
        if not (striker and striker.char and striker.char.id == "character_avatar") then return end
        if not (foe and foe.alive) then return end
        if ctx.gap(foe) ~= 1 then return end
        if not ctx.canReach(foe) then return end
        local key = "bondFollowUp:" .. tostring(ctx.unit.char and ctx.unit.char.id)
        if not require("models.combat").firstThisTurn(striker, key) then return end
        ctx.log("action", string.format("%s follows up!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(foe)
    end,
}
