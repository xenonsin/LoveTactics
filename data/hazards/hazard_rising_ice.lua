-- THE GLASS PALACE, RISING: where the Snow Queen's next wall will stand ("Sloth's Bestiary", 2026-10-04, approved:
-- "each round she raises a 3-tile ice wall, telegraphed a turn ahead"). Laid by trait_glass_palace at the end of
-- each of her turns, three tiles in a line. Each stands ONE TURN -- the telegraph, hostile ground every planner
-- walks out of -- and when it runs out the ice rises: an Ice Wall (data/walls/ice_wall.lua) on every tile still
-- empty. A tile somebody is standing on stays floor; the ice does not rise through a body.
--
-- FIRE PUTS IT OUT before it rises (`dousedByTags`), as fire melts the wall it would have been.
return {
    name = "Rising Ice",
    description = "The Glass Palace rising. When it lands, an empty tile becomes an Ice Wall.",
    tags = { "ice" },
    duration = 5, -- one turn at Status.TICKS_PER_TURN
    disposition = "hostile",
    dousedByTags = { "fire" },
    onExpire = function(ctx)
        local combat, h = ctx.combat, ctx.hazard
        if not (combat and h) then return end
        local Combat = require("models.combat")
        if Combat.unitAt(combat, h.x, h.y) or Combat.objectAt(combat, h.x, h.y) then return end
        require("models.wall").place(combat, h.x, h.y, "ice_wall", { side = h.side })
    end,
}
