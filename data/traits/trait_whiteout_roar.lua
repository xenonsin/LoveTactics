-- WHITEOUT ROAR: the yeti's rule (data/items/utility/utility_whiteout_roar.lua), and on a smaller scale the
-- Yeti-Hide Mantle's (traitParams: radius 3, the nearest one only, and Root). Approved 2026-10-04 on "Sloth's
-- Bestiary", slice A.
--
-- At the top of the bearer's turn, every foe within `radius` with no ally beside it is Cowering for about two
-- turns (`duration`) -- frightened, it moves 2 fewer, so the straggler cannot get back to its friends. The
-- counterplay is the review's: move in pairs. models/sloth_beasts.lua owns the reading of "alone".
--
-- IT ROOTED until the creature identity pass (2026-11-19): four Sloth bodies hinged on Root, and the yeti's lesson
-- is about distance from a friend, which a shortened step says as well as a pinned one. The mantle a company
-- takes off it keeps Root (`status` in its traitParams), so the trophy did not change under its owner.
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Whiteout Roar",
    description = "At the start of its turn, each foe within 4 with no ally beside it is Cowering.",
    radius = 4,
    nearest = false,
    status = "status_cowering",
    duration = 10,
    onTurnStart = SlothBeasts.roar,
}
