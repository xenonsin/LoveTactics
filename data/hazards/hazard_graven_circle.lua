-- A graven circle: sigils cut into the ground by the mage who is standing in them. The caster is Graven
-- while it stays (data/status/status_graven.lua) -- its casts and its steps cost less of the timeline.
--
-- THE OWNER, AND NOBODY ELSE. Every other friendly zone in the game pays out to allies and skips the
-- body holding it open: a Rally Banner inspires the line and not the standard, sacred ground blesses
-- everyone who is not the banner (data/hazards/hazard_rally.lua, hazard_sacred.lua). This one is the
-- exact inverse -- it pays the owner and NOBODY else, ally or otherwise. That is the shelf's sin written
-- into an `if`: the Arcanum's line is pride, and a working that another mage could simply walk into and
-- benefit from would be a gift. This is not a gift. It is a circle with one name in it, and the party
-- may stand in it all day for nothing.
--
-- It needs its own zone id for the reason data/hazards/hazard_rally.lua sets out: a zone-bound status
-- remembers the id that granted it, so sharing an id with another zone would let the wrong ground keep
-- the wrong buff alive.
--
-- `disposition = "friendly"` so the enemy AI does not treat the tiles as dangerous and route around
-- them -- there is nothing here to hurt anyone, and an AI that gave the circle a wide berth would hand
-- the mage free area denial it never paid for.
return {
    name = "Graven Circle",
    description = "Cut sigils: the mage who graved them casts and moves for less while standing within.",
    sprite = "assets/hazards/graven_circle.png",
    tags = { "arcane" },
    duration = 20, -- the sigils scuff out on their own; the ability re-scales this by its forge level
    disposition = "friendly",
    onEnter = function(ctx)
        -- The one line that makes it pride. `owner` is the caster, stamped on by the ability below.
        if ctx.unit ~= ctx.hazard.owner then return end
        -- Graven declares no `lingers`, so this grant is stamped with "hazard_graven_circle" as its
        -- source automatically and lasts exactly as long as the mage stands here.
        ctx.applyStatus(ctx.unit, "status_graven")
    end,
}
