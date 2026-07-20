-- Acedia's people, met on the road rather than at the end of it. They surface once the player has
-- some standing, because the Bastion does not send a squire after the knights it will not name.
--
-- They are the line's argument walking around loose: a disciplined knightly company, in the order's
-- own forms, that walked out of a gate fifteen years ago and has held nothing since (docs/story.md).
return {
    name = "The Forsworn",
    kind = "elite",
    minPrestige = 3,
    weight = function(ctx) return math.max(1, math.floor((ctx.prestige or 1) / 2)) end,
    composition = function(ctx)
        local list = { "character_forsworn_captain" }
        for i = 1, 1 + math.floor((ctx.prestige or 1) / 3) do
            list[#list + 1] = "character_forsworn_knight"
        end
        return list
    end,
}
