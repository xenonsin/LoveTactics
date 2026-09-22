-- Encounter blueprint. A lone beast on early ground, and beasts belong to Gluttony's wood.
--
-- IT WAS EXCLUDED FROM THE CASTLE and open everywhere else, which was the shape while the road
-- pool was shared. Under the circle-lock rule a body that is not human belongs to exactly one
-- circle, so the condition names the one ground it may walk rather than the one it may not.
return {
    name = "Ancient Stag",
    kind = "combat",
    weight = 4, -- see encounter_boar.lua: the four road fights were doubled together
    depth = 1,
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
        if ctx.biome ~= "forest" then return false end
        return (ctx.depth or 1) <= 12
    end,
    -- A lone beast, joined by a second late in the campaign.
    composition = function(ctx)
        local list = { "character_stag_beast" }
        if (ctx.depth or 1) >= 4 then list[#list + 1] = "character_stag_beast" end
        return list
    end,
}
