-- GRAVE-ROBBER: the ghoul crouches over a body that is down and takes something off it -- Greed's verb,
-- done by the dead. A LOAN (Combat.strip): the ghoul wears the piece, and it goes home when the ghoul
-- dies, when the fight ends and before any save. Never a thing that destroys gear. It reaches a body in
-- its revive window only, so the window is the whole of the counterplay: get them up, or stand over them.
local function downedFoes(combat, unit)
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if not u.alive and u.incapacitated and not u.noRevive and u.side ~= unit.side then
            out[#out + 1] = { x = u.x, y = u.y }
        end
    end
    return out
end

return {
    name = "Grave-Robber",
    description = "Takes a piece of gear off an adjacent downed foe, and wears it for the rest of the fight.",
    flavor = "It checks the pockets first. It always checks the pockets first.",
    sprite = "assets/items/ability_grave_rob.png",
    type = "ability",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 3 },
        aiAims = downedFoes, -- a downed body is not a unit anything else aims at
        ai = { priority = "urgent", act = "cast", label = "a body is down beside it",
               whenFn = function(ctx) return #downedFoes(ctx.combat, ctx.unit) > 0 end },
        effect = function(fx)
            local body = fx.downedAt(fx.tx, fx.ty)
            if body and body.side ~= fx.user.side then fx.strip(body, { downed = true }) end
        end,
    },
}
