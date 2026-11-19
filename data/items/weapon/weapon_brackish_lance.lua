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
--
-- AND IT KNOCKS A SOAKED BODY BACK A TILE (2026-11-19, the creature identity pass), which is the Fen
-- Lancer's own payoff. Before this the lancer's soaking was worth something only on the Tidecaller's
-- turn; alone it was a reach-2 spear. Now the Wet it lays down is also what it collects on: a body the
-- point finds ALREADY Wet -- off the shallows, off this lance's last thrust, off a Rain cloud -- is driven
-- one tile along the thrust. On a fen that tile is often the channel, and a body that cannot swim does
-- not come back out of the deep (Combat.drown). Wet is read BEFORE the blow lays any, so a dry body is
-- soaked by one thrust and only shoved by the next: the tell is the badge, a turn ahead.
--
-- The answer is in the same sentence: stay dry beside a lancer, or keep your back to dry ground. The far
-- body is driven first so the near one has somewhere to go.
local Curve = require("models.curve")

return {
    name = "Brackish Lance",
    description = "Skewers a 2-tile line and leaves the far tile Wet. A target already Wet is knocked back 1 tile.",
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
            -- Who was soaked BEFORE this thrust, and which body is the far one, both read before anything
            -- moves or is soaked -- a shove that reads the tile afterwards reads the tile the body left.
            local struck, far, soaked = {}, nil, {}
            for _, u in ipairs(fx.aoeUnits()) do
                struck[#struck + 1] = u
                if u.x == farX and u.y == farY then far = u end
                soaked[u] = fx.hasStatus(u, "status_wet")
            end
            for _, u in ipairs(struck) do
                fx.damage(u)
                if u.alive and u == far then fx.applyStatus(u, "status_wet") end
            end
            -- The far body first, so the near one is not shoved into it.
            if far and far.alive and soaked[far] then fx.knockback(far, 1) end
            for _, u in ipairs(struck) do
                if u ~= far and u.alive and soaked[u] then fx.knockback(u, 1) end
            end
        end,
    },
}
