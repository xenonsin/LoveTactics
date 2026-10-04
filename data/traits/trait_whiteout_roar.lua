-- WHITEOUT ROAR: the yeti's rule (data/items/utility/utility_whiteout_roar.lua), and on a smaller scale the
-- Yeti-Hide Mantle's (traitParams: radius 3, the nearest one only). Approved 2026-10-04 on "Sloth's Bestiary",
-- slice A.
--
-- At the top of the bearer's turn, every foe within `radius` with no ally beside it is Rooted -- frozen with fear,
-- which is Root's own status and Root's own answers (a Cure, or a friend standing next to you before it comes
-- round). The counterplay is the review's: move in pairs. models/sloth_beasts.lua owns the reading of "alone".
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Whiteout Roar",
    description = "At the start of its turn, each foe within 4 with no ally beside it is Rooted.",
    radius = 4,
    nearest = false,
    onTurnStart = SlothBeasts.roar,
}
