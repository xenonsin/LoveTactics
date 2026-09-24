-- THE MOSS KING, on the wood's first floor, over the kin he means to eat.
--
-- An ELITE, not the stair: a marked stop a company reads off the board and chooses, which is what the
-- fen's King is too (data/encounters/encounter_the_king_slime.lua). The two ask different questions.
-- The fen's King voids steel and asks how many elements you brought; the Moss King only resists it
-- (data/characters/character_moss_king_slime.lua) and asks whether you can keep his court apart --
-- every moss slime left standing beside him is a meal (data/items/ability/ability_coalesce.lua), and
-- every piece he falls into goes on eating the others.
--
-- RUNG 1, the approach floor, because a descent opens there: a pair with no element can still win
-- this, and it is the floor the slimes were asked for. KILLALL, as the fen's King is, for the King's
-- own reason -- an `assassinate` would end the fight on the beat the split begins it.
local Band = require("models.band")

return {
    name = "The Moss King",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1,
    composition = function(ctx)
        -- Two of his court at the least: one meal is a heal, two is a choice about which to kill first.
        return Band.fill({ "character_moss_king_slime" }, ctx, "character_moss_slime",
            { base = 2, min = 2, per = 6, max = 3 })
    end,
}
