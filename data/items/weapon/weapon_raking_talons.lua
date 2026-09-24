-- RAKING TALONS: the wood's hawk, reviewed over two rounds on 2026-09-23 ("The Sated and the Flight"). Every
-- stealing pitch was denied ("stealing isn't a hawk thing"); what it got instead was both halves of a hunt:
--
--   SWOOP     +1 damage for every tile flown this turn before the strike, up to +6 (trait_swoop)
--   MANTLING  a strike that leaves its quarry below half health does not fly home. The hawk hunches over
--             it: the prey is Rooted and fed on each turn (status_mantled), the hawk cannot move or dodge
--             (status_mantling), and it holds until anything hits it (trait_mantling)
--
-- Otherwise it is the Talons' own rake-and-return (data/items/weapon/weapon_talons.lua, which the
-- Falconer's Glove's hawk still carries untouched): strike, then back to the tile the turn began on.
--
-- A body that cannot be pinned is not mantled: a boss (the wood's elites are off the Charm and execute
-- tables for the same reason) and anything too big to hunch over.
local Curve = require("models.curve")

local function mantleable(tgt)
    if not (tgt and tgt.alive and tgt.char) then return false end
    if tgt.char.boss or (tgt.w or 1) > 1 or (tgt.h or 1) > 1 then return false end
    local hp = tgt.char.stats.health
    return hp.max and hp.max > 0 and hp.current < hp.max * 0.5
end

return {
    name = "Raking Talons",
    description = "Rakes a foe and flies back. Below half health, it stays and feeds on them instead.",
    flavor = "It does not kill what it catches. It starts eating, and lets that take care of it.",
    sprite = "assets/items/weapon_raking_talons.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true,
    traits = { "trait_swoop", "trait_mantling" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            fx.damage(fx.target)
            local u, tgt = fx.user, fx.target
            -- Already on a body: keep feeding on it where it stands.
            if u.mantlingPrey then return end
            -- Through fx.applyStatus, so a hover preview pins nobody: status_mantled's onApply ties the
            -- two bodies together and puts Mantling on the hawk.
            if mantleable(tgt) and not tgt.mantledBy then
                fx.applyStatus(tgt, "status_mantled")
                if u.mantlingPrey == tgt then return end
            end
            local turn = fx.combat and fx.combat.turn
            if turn and turn.startX and (turn.startX ~= u.x or turn.startY ~= u.y) then
                fx.teleportUser(turn.startX, turn.startY)
            end
        end,
    },
}
