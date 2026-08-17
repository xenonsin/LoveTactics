-- THE COLOURS: the fight that teaches "kill the one that is not hitting you".
--
-- The standard-bearer holds the rank together and barely fights. Killing it does not merely stop a buff:
-- because the rank rule is measured live off adjacency, the shape collapses and the survivors become
-- ordinary. The same lesson the Long Note warband teaches with a Rally Banner, told again in armour.
return {
    name = "The Colours",
    kind = "combat",
    weight = 4,
    minDay = 3,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        local list = { "character_standard_bearer", "character_gilded_sworn" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_gilded_page"
        end
        return list
    end,
}
