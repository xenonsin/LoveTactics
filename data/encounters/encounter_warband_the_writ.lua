-- THE WRIT: a company that names one of yours and kills that one.
--
-- Setup is the Mark of Heresy, payoff is the Coup de Grace that reads it, and the exorcist is the
-- multiplier -- it strips the wards you would otherwise answer a named execution with. That third body
-- is what turns the fight positional: you cannot ward through this, so you break line of sight or you
-- kill the inquisitor before the blade comes around.
--
-- See encounter_warband_vat_work.lua for the role grammar and why four distinct bodies is the ceiling.
return {
    name = "The Writ",
    kind = "combat",
    weight = 3,
    minDay = 5, -- an execution company is not what the road opens with
    composition = function(ctx)
        local list = {
            "character_inquisitor", -- setup: marks one of yours
            "character_assassin",   -- payoff: the mark is what Coup de Grace is priced against
            "character_exorcist",   -- multiplier: takes the wards away from the answer
            "character_crusader",   -- the line, holding the ground between you and the blade
        }
        for _ = 1, math.floor((ctx.day or 1) / 14) do list[#list + 1] = "character_crusader" end
        return list
    end,
}
