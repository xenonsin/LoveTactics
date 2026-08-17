-- DRINKS THE FIRE: the Unquenched is healed by the burning ground, including yours.
--
-- The volcanic circle fills its own board with fire -- the swarm leaves a tile alight every time one
-- dies (data/traits/trait_cinderfall.lua), the brands Burn what they hit, and the biome's signature
-- hazard is fire outright (data/biomes/volcanic.lua). This is the body that turns all of that into a
-- resource.
--
-- Which makes it the circle's most interesting counterplay problem, because the obvious answer to a
-- Wrath floor -- clear the chaff first -- is the exact thing that feeds it. Standing on burning ground
-- it drinks; standing on clean ground it is an ordinary large animal. So the real answer is to move it,
-- or to move yourself and make it come.
--
-- Fires on onCast -- it drinks as it acts, so a turn spent standing in the fire doing nothing pays it
-- nothing. It has to be fighting, in the fire, which is the sin in one sentence.
return {
    name = "Drinks the Fire",
    description = "Heals as it acts, if it is standing in fire.",
    heal = 14,
    onCast = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        -- Hazard.at takes the id it is looking for, so this asks "is there fire on my tile" in one call
        -- rather than reading back whatever zone happens to be topmost and comparing.
        local Hazard = require("models.hazard")
        if not Hazard.at(ctx.combat, u.x, u.y, "hazard_fire") then return end
        ctx.heal(u, ctx.def.heal)
        ctx.log("action", string.format("%s drinks the fire.", (u.char and u.char.name) or "It"))
    end,
}
