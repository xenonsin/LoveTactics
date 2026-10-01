-- DJINNI'S BREATH: the Djinni's gale, and its drop. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- A lane cast (aimed at the adjacent tile, as every lane cast in this engine is): every body in the 4-tile line
-- is pushed 2 tiles straight down it, the caster's own side included -- wind has no side. Riptide's mirror, and
-- the same reason for the order: FARTHEST FIRST, so each body is shoved into ground the one beyond it has already
-- left rather than into its back.
--
-- On the spire it is the doorway answer turned round: a djinn cannot be cornered by a company it can blow back
-- out of the door. Beside an Ifrit it is worse -- a body pushed while it trails fire lays two tiles of it.
local Curve = require("models.curve")

return {
    name = "Djinni's Breath",
    description = "Push every body in a line 2 tiles.",
    flavor = "It was not angry. It simply wanted the room.",
    sprite = "assets/items/ability_djinnis_breath.png",
    type = "ability",
    tags = { "wind", "magical" },
    class = "mage",
    unlockLevel = 13,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(15, 25), -- a light buffet: the push is the spell
        aoe = { shape = "line", length = 4 },
        effect = function(fx)
            local hit = {}
            for _, u in ipairs(fx.aoeUnits()) do hit[#hit + 1] = u end
            table.sort(hit, function(a, b)
                local da = math.max(math.abs(a.x - fx.user.x), math.abs(a.y - fx.user.y))
                local db = math.max(math.abs(b.x - fx.user.x), math.abs(b.y - fx.user.y))
                if da ~= db then return da > db end
                return (a.x * 1000 + a.y) > (b.x * 1000 + b.y) -- a stable tiebreak: seeds must replay
            end)
            for _, u in ipairs(hit) do
                fx.damage(u)
                if u.alive then fx.knockback(u, 2) end
            end
        end,
    },
}
