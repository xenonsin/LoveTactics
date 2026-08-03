-- Leaping Crash: the fighter vaults across the field and lands like a dropped anvil. It teleports the
-- caster onto a chosen empty tile (fx.teleportUser, springing whatever the tile holds on arrival) and
-- then bursts, damaging everything in the 3x3 square around the landing -- friend or foe -- except the
-- caster standing at its centre. A gap-closer and an opener in one: leap into the thick of them, then
-- detonate. The reach is the leap distance; the blast is fixed at radius 1 around where you come down.
local Curve = require("models.curve")

return {
    name = "Leaping Crash",
    description = "Leaps to an empty tile and slams down, damaging everything around you.",
    flavor = "A gap-closer and an opener at once. The Colosseum mostly loves the noise.",
    sprite = "assets/items/ability_leaping_crash.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    price = 360,
    unlockQuests = 6,
    activeAbility = {
        target = "tile",   -- an empty tile to land on (not allowOccupied: you cannot land on a unit)
        range = 4,
        minRange = 1,      -- it is a leap, not a stomp in place
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(8), -- per-target blast damage = power + the caster's Damage, minus Defense
        aoe = { shape = "square", radius = 1 }, -- the 3x3 burst centred on the landing tile
        effect = function(fx)
            fx.teleportUser(fx.tx, fx.ty) -- land first...
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user then fx.damage(u) end -- ...then everything around the impact but you
            end
        end,
    },
}
