-- Encounter blueprint. See data/encounters/encounter_boar.lua for the shape.
--
-- The multi-tile showcase: an Ogre (data/characters/character_ogre.lua) stands on a 2x2 block of
-- the board rather than a single cell, so it walls off ground the way its size says it should. It
-- comes with a small escort so the fight is about working around the bulk rather than surrounding it.
return {
    name = "Ogre",
    kind = "combat",
    weight = 4, -- see encounter_boar.lua: the four road fights were doubled together
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    -- LOCKED TO THE WOOD, which is the circle-lock rule arriving rather than a retune: humans
    -- float to every floor and everything else belongs to exactly one circle. This was shared
    -- road stock on all fifteen, and the beast band is Gluttony's identity now.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_ogre" }
        -- One extra escort every two days, so the brute is never entirely alone late on.
        local escorts = 1 + math.floor((ctx.depth or 1) / 1)
        for _ = 1, escorts do list[#list + 1] = "character_bandit" end
        return list
    end,
}
