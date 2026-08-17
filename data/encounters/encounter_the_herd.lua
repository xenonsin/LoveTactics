-- THE HERD: what a stag looks like when it is not alone.
--
-- encounter_stag.lua is the single worst offender in the pre-existing pool -- one body against a
-- company of four, rating 582% against Muster.WALK_OVER of 200, which is to say every marker it drew
-- went calm and the fight offered to resolve itself instead of opening a board. It stays, because a
-- lone beast IS correct texture and walking one off is the option working rather than failing.
--
-- This is the version that is a fight. Same body, brought in the numbers it lives in.
return {
    name = "The Herd",
    kind = "combat",
    weight = 3,
    minDay = 2,
    composition = function(ctx)
        local list = {}
        for _ = 1, 3 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_stag_beast"
        end
        return list
    end,
}
