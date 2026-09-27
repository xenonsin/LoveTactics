-- THE MORNING STAR: the Horned Twin's weapon, and her drop. Approved 2026-09-26 ("The Oni of Wrath"), after
-- Re:Zero's horned sister and the chained flail she swings.
--
-- A mace on a chain: it reaches 2 tiles and drags whatever it strikes one tile toward the wielder, where the tile
-- is open. A drag, not a shove, so it hurts nothing on the way in. The review said reach 3; no carried melee
-- weapon reaches past 2, and that is what Clear Out is priced on (tests/tactics_ability_spec.lua). It sits on the
-- knight's shelf, which is where the maces are.
local Curve = require("models.curve")

-- One step from `t` toward `u` along the longer axis, or nil.
local function stepToward(t, u)
    local dx, dy = u.x - t.x, u.y - t.y
    if math.abs(dx) >= math.abs(dy) and dx ~= 0 then return t.x + (dx > 0 and 1 or -1), t.y end
    if dy ~= 0 then return t.x, t.y + (dy > 0 and 1 or -1) end
    return nil
end

return {
    name = "Morning Star",
    description = "Strikes a foe up to 2 tiles away and drags it 1 tile toward you.",
    flavor = "Twenty feet of chain and a ball of spikes. It comes back to her hand faster than it left.",
    sprite = "assets/items/weapon_morning_star.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    hands = 2,
    class = "knight",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 4,
        requiresSight = true,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(13, 25),
        effect = function(fx)
            local t, u = fx.target, fx.user
            if not (t and t.alive) then return end
            fx.damage(t)
            local Combat = require("models.combat")
            if not t.alive or Combat.unitGap(u, t) <= 1 then return end
            if require("models.status").blocksForcedMove(t) then return end
            local x, y = stepToward(t, u)
            if x and Combat.footprintFree(fx.combat, 1, 1, x, y) then fx.teleport(t, x, y) end
        end,
    },
}
