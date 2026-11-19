-- NEXT FACE: the Faceless Champion's telegraph (models/faces.lua's Faces.telegraph). Creature identity pass,
-- 2026-11-19.
--
-- At the end of its turn the Champion commits the champion's face it will wear next, read off whoever of the
-- company stands nearest it then, and this badge names it. At the top of its next turn it puts that face on and
-- the badge comes off. The face rides on the instance (`face`) and the tooltip reads it live, as Already Known
-- does.
--
-- Not a blessing and never stripped: it is a promise about the body, not something it holds.
local BASE = "Next Face: the champion's face it will wear at the start of its next turn."

return {
    name = "Next Face",
    abbr = "Next",
    description = BASE,
    color = { 0.760, 0.640, 0.380 }, -- badge tint (a champion's brass)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    describe = function(status)
        local face = status and status.face
        if not face then return BASE end
        return "Next Face: at the start of its next turn it wears the " .. face .. "."
    end,
}
