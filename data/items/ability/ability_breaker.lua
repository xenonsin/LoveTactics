-- Breaker: the wave arrives, and a whole rank gives ground.
--
-- The twin of ability_riptide, and everything worth knowing about the pair is in that file's header:
-- same lane, same one tile, opposite direction. PUSH takes you into the channel BEHIND you, which is
-- what makes this the half that works when the Mere is standing on dry land and the water is at your
-- back. Riptide is the half that works when it is not.
--
-- NEAREST FIRST, the mirror of Riptide's ordering and for the mirror reason: driving a rank away with
-- the far body unresolved means the far body is still standing where the near one is being pushed, and
-- half the lane fails to move for a reason no player could see.
--
-- NAMED FOR THE BREAKING WAVE rather than for the surge that would have been the obvious word, because
-- data/items/ability/ability_surge.lua is already an item and means something else entirely (an extra
-- action). One word per mechanic cuts both ways: a second Surge would have been two mechanics per word.
local Curve = require("models.curve")

return {
    name = "Breaker",
    description = "Drives every body in a 3-tile line one step away from you.",
    flavor = "A wave is only a great deal of water arriving at once, with an opinion.",
    sprite = "assets/items/breaker.png",
    type = "ability",
    tags = { "water", "magical" },
    class = "mage",
    dropOnly = true,
    dropTier = 8,
    unlockQuests = 5,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 5,
        cost = { stat = "mana", amount = 9 },
        damage = Curve.ramp(12, 22),
        aoe = { shape = "line", length = 3 },
        effect = function(fx)
            local hit = {}
            for _, u in ipairs(fx.aoeUnits()) do hit[#hit + 1] = u end
            table.sort(hit, function(a, b)
                local da = math.max(math.abs(a.x - fx.user.x), math.abs(a.y - fx.user.y))
                local db = math.max(math.abs(b.x - fx.user.x), math.abs(b.y - fx.user.y))
                if da ~= db then return da < db end
                return (a.x * 1000 + a.y) < (b.x * 1000 + b.y) -- a stable tiebreak: seeds must replay
            end)
            for _, u in ipairs(hit) do
                fx.damage(u)
                -- Straight away from the caster: the plain shove, which is what fx.knockback does with
                -- no destination handed to it. It routes through the same primitive everything else
                -- does, so a body driven into a channel drowns with nothing about drowning written here.
                if u.alive then fx.knockback(u, 1) end
            end
        end,
    },
}
