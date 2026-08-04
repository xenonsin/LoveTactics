-- A spear, so it skewers a line (docs/weapons.md). Its extra is that the wounds it opens stay open to
-- the next spear: everything in the line is left Exposed (status_exposed), which is +8 damage taken from
-- every PIERCE-tagged hit thereafter.
--
-- The party weapon of the family, and the one whose damage stat is somebody else. Exposed is narrow on
-- purpose (data/status/status_exposed.lua argues the case: "a vulnerability to everything would just be
-- a damage buff painted on the enemy") -- it answers pierce and nothing else. Which is exactly the tag
-- every spear, every bow, every longbow and half the daggers in this game already carry. Two spearmen in
-- a line, or a spearman and an archer, and this weapon is worth more than anything else on the shelf.
-- A party with no other pierce in it, and it is a slightly weak iron spear.
--
-- Note it exposes both tiles, unlike the Boar Spear's near-tile-only crossbar: a debuff that makes other
-- people's hits land is worth spreading, where a root is worth rationing.
local Curve = require("models.curve")

return {
    name = "Exposing Pike",
    description = "Inflicts Exposed on the far tile.",
    flavor = "The Bastion drills two ranks of pikes for a reason. The first rank is not the one that kills you.",
    sprite = "assets/items/exposing_pike.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "knight",
    price = 300,
    unlockQuests = 5,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 9 },
        -- Under an iron spear's: this weapon's output is measured across the party, not on its own line.
        damage = Curve.ramp(4, 14),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            -- The spear convention (docs/weapons.md): the point opens only the FAR rank.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local farX, farY = fx.tx + dx, fx.ty + dy
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                if u.alive and u.x == farX and u.y == farY then
                    fx.applyStatus(u, "status_exposed")
                end
            end
        end,
    },
}
