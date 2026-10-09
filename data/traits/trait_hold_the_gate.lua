-- HOLD THE GATE: the Archon Warden's rule, and the Sentinel's once it is carried out (data/items/utility/
-- utility_hold_the_gate.lua, utility_wardens_post.lua). Reviewed 2026-10-09 ("The Crown's Bestiary", slice A).
--
-- A keeper of a door between the spheres. On any turn it has not moved, it holds its post: every body it covers
-- within 2 takes half from anything struck from farther than 2 tiles. The Warden's own organ covers ARCHONS
-- (`court = true`); the Sentinel's post covers every ally.
--
-- THE POST IS A TILE. It is planted at the bell and at the end of each of the bearer's own turns on which it did not
-- move, and the cover holds for exactly as long as the bearer still stands on it (models/archon_court.lua's
-- ArchonCourt.isHolding). So a shove, a pull or a swap ends the cover on the spot, and it comes back at the end of
-- its next still turn -- the review's counter, falling out of where the body stands rather than written twice.
return {
    name = "Hold the Gate",
    description = "On a turn you did not move, allies within 2 take half damage from foes farther than 2 tiles.",
    holdsTheGate = true,
    reach = 2,
    share = 0.5,
    court = false, -- the Warden's organ sets it: Archons only
    onCombatStart = function(ctx)
        require("models.archon_court").post(ctx.unit, true)
    end,
    onTurnEnd = function(ctx)
        local still = require("models.combat").tilesMovedThisTurn(ctx.unit) == 0
        require("models.archon_court").post(ctx.unit, still)
    end,
}
