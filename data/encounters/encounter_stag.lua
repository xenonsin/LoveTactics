-- Encounter blueprint. Only roams the wilds (conditional example): excluded
-- from the castle biome. See data/encounters/boar.lua for the shape.
return {
    name = "Ancient Stag",
    kind = "combat",
    weight = 4, -- see encounter_boar.lua: the four road fights were doubled together
    minDay = 1,
    -- IT BELONGS TO THE EARLY ROAD, AND NOW IT SAYS SO. Two stags is 216% of a floor-five company --
    -- a walkover, which tests/descent_spec.lua forbids a floor to offer -- and the only thing keeping
    -- it off deep floors was Descent.floorPool's share filter, which drops a fight sitting under the
    -- floor's MEDIAN worth. A median is a proxy, and it moved the first time the underworld's roster
    -- grew (data/encounters/encounter_the_bone_orchard.lua); this fell out the other side of it, still
    -- fielding the two animals it fielded on day four.
    --
    -- A DAY CEILING RATHER THAN MORE STAGS, which was tried first and is the wrong answer: a third
    -- animal put the fight at 27 unit-turns against tests/skirmish_spec.lua's budget of 22, because a
    -- stag is a big slow body and three of them is a set-piece. The fight is not underweight -- it is
    -- FINISHED, and the honest thing to say about a finished road fight is that the road ended. Deeper
    -- floors already have the versions of this that scale: data/encounters/encounter_the_herd.lua for
    -- more of them, and the Meandering Stag for the one that is worth stopping for.
    condition = function(ctx)
        if ctx.biome == "castle" then return false end
        return (ctx.day or 1) <= 12
    end,
    -- A lone beast, joined by a second late in the campaign.
    composition = function(ctx)
        local list = { "character_stag_beast" }
        if (ctx.day or 1) >= 4 then list[#list + 1] = "character_stag_beast" end
        return list
    end,
}
