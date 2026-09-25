-- THE CHURCHYARD YEW: the Hamadryad and her tree, and the Move half of the circle's elite.
--
-- She plants her Heartwood Tree beside her at the bell, and while it stands she cannot die -- every
-- killing blow leaves her at 1 beside it. So the thing to cut is the tree, and between the company and
-- the tree is her grove: Nymphs that step between plants and light bodies for a shove, hedges she grows
-- behind you, thorns that bill every tile you are thrown across, and Through the Grain, which puts a
-- body out alone on the far side of the room.
--
-- BILLED NOWHERE, as the Anchorhold and the Lady Chapel are; RUNG 2, the seat, where the circle's other
-- Move elite (the Eyrie) stands. One elite, one floor: see models/encounter.lua's eligibility note.
--
-- MOVE ONLY (tests/greed_lust_circle_spec.lua sweeps every Lust roster for the mix).
local Band = require("models.band")

return {
    name = "The Churchyard Yew",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 2,
    composition = function(ctx)
        local list = { "character_hamadryad", "character_nymph" }
        return Band.fill(list, ctx, "character_nymph", { base = 1, per = 6, max = 2 })
    end,
}
