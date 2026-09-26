-- SHADOW AND FLAME: the Thing Under the Seam's heavy blow (character_deep_bane). A cone of fire three deep
-- off the face of its body -- 2, then 4, then 4 across off a 2x2 face (models/hoard.lua's cone, the one
-- Dragonfire breathes) -- WOUND UP a turn ahead: the cone is committed and marked on the board when it
-- begins, and lands when the thing's next turn comes round. Everything still standing in it then is hit
-- hard enough to go down, and Burns.
--
-- THE TELEGRAPH IS THE WHOLE COUNTERPLAY, which is why it can hit this hard. A turn to step out of the
-- marked tiles, to stun it out of the swing (an interrupted wind-up is a wasted one), or to shove it off
-- its aim. A company that reads the board takes nothing; one that does not loses a body.
--
-- It burns THE COMPANY and nothing else: the thing fights alone, so there is no side of its own to spare,
-- and the check is the side rather than the caster so that stays true if it is ever given one. The ground
-- is left as it was -- the trail it walks is how this body sets the floor alight, and a second source of
-- fire would make the two indistinguishable.
--
-- A demon's blow: `physical, slash, fire`, never `magical`. Creature kit: no shelf, no price, noSteal.
local Curve = require("models.curve")

local LENGTH = 3

return {
    name = "Shadow and Flame",
    description = "Winds up a turn, then sweeps a cone of fire 3 deep off its body. Every foe in it is hit hard and Burned.",
    flavor = "The dwarves had a word for it once. Nobody who learned the word lived to teach it.",
    sprite = "assets/items/ability_shadow_and_flame.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = LENGTH,
        speed = 6,
        windup = 5, -- a turn: the cone is committed and marked here, and lands on its next turn
        cooldown = 15, -- about one swing in three turns; the lash is the rest of them
        cost = { stat = "stamina", amount = 12 },
        -- MEASURED to put a body down: at floor six (the thing at level 19, a company at its danger level)
        -- it lands ~110-125 on a priest, a mage, a rogue or an archer, each of them 78-109 health, so every
        -- one of them goes down from full -- and about 65 through a knight's plate, which is what plate is
        -- for. Foreclosure's telegraphed single blow is (24, 40); this is twice that because it is the
        -- whole fight's one threat and the board says a turn ahead where it will land.
        damage = Curve.ramp(52, 68),
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return require("models.hoard").cone(unit, tx, ty, LENGTH)
            end,
        },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive and u.side ~= fx.user.side then
                    fx.damage(u, { inflicts = "status_burn" })
                end
            end
        end,
    },
}
