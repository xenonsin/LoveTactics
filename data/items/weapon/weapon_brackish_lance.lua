-- The Fen Lancer's spear: green wood, a leaf-blade, and a haft that has been in the water a long time.
--
-- A spear, so the effect lands on the FAR tile -- the point reaches past the near body to the rank
-- behind it (docs/weapons.md). Here the far tile is left WET, which makes this the cheap piece that
-- teaches the Mere's whole combination in the first fight a company takes in the fen: soak the second
-- rank, then let the Tidecaller put a charge through the water.
--
-- IT SOAKS WHAT IT CANNOT REACH, which is the reading that makes the family rule feel like a fact about
-- the weapon rather than a rule about spears. The lancer stands in the channel, the front rank is what
-- it skewers, and the man BEHIND that one gets the river thrown over him.
--
-- Read beside data/items/weapon/weapon_tidesbreak.lua, which is the knight shelf's water spear: that
-- one soaks the far tile AND drives the line back AND steps its wielder into the gap. This does one of
-- those three. The difference is the difference between a shelf item and a body's kit.
local Curve = require("models.curve")

return {
    name = "Brackish Lance",
    description = "Skewers a 2-tile line and leaves the far tile Wet.",
    flavor = "It has been under the water so long the wood has stopped caring.",
    sprite = "assets/items/brackish_lance.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "water", "melee" },
    hands = 2,
    class = "knight",
    dropOnly = true,
    unlockLevel = 13,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 24),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            -- The spear convention: the status lands on the FAR tile only, which is the aimed cell plus
            -- one more step along the thrust.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local farX, farY = fx.tx + dx, fx.ty + dy
            for _, u in ipairs(fx.aoeUnits()) do
                local isFar = (u.x == farX and u.y == farY)
                fx.damage(u)
                if u.alive and isFar then fx.applyStatus(u, "status_wet") end
            end
        end,
    },
}
