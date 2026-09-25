-- THE NEST: the Godling, a Scale-Priest and the worshippers who walk in to be eaten. Approved in both rounds
-- (2026-09-24/25, "The Kobolds of Greed") and billed as a SPARE elite on Greed's seat, not the lieutenant (as
-- picked on the page) -- so the Counting Hall stays the seat's named elite and this is the other one a seat
-- floor can deal.
--
-- THE HOARD-THANE IN REVERSE, AS A CLOCK. Devotees arrive in waves from every side (`from = "surround"`,
-- the Gluttony stair's pattern, capped by `maxAlive` so the cave tops up rather than floods) and walk to the
-- Godling; every one that ends its turn beside it is devoured and gives it a stack of Glut. So every Devotee
-- the company stops is Defense the Godling does not get, and a critical on the bare patch takes all of it
-- back at once. Kill the Godling and every kobold that sees it is Forsaken.
--
-- A KILL-ALL THAT WAITS FOR ITS WAVES (Combat.outcomeFor): three of them, counted (`count`), so the fight
-- ends when the last has come and fallen. Sometimes a Wyrmling is already up beside the Godling ("Can have
-- already hatched in the encounter") -- a seeded draw that lands on no Wyrmling with no seed.
--
-- An objective-bearing encounter is always played out, never auto-resolved (EncounterBattle.eligible).
local Band = require("models.band")
local Status = require("models.status")

local TURN = Status.TICKS_PER_TURN

return {
    name = "The Nest",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function(ctx)
        local list = { "character_the_godling", "character_kobold_scale_priest" }
        if Band.count(ctx, { base = 0, min = 0, max = 1, vary = 1, key = "nest_hatched" }) == 1 then
            list[#list + 1] = "character_wyrmling"
        end
        return Band.fill(list, ctx, "character_kobold_skulker", { base = 1, per = 6, max = 2 })
    end,
    objective = {
        type = "killAll",
        waves = {
            { at = 2 * TURN, every = 3 * TURN, count = 3, from = "surround", maxAlive = 8,
              composition = function() return { "character_kobold_devotee", "character_kobold_devotee" } end },
        },
    },
}
