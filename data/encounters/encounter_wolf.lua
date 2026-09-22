-- Encounter blueprint. See data/encounters/boar.lua for the shape.
return {
    name = "Dire Wolf",
    kind = "combat",
    weight = 6, -- see encounter_boar.lua: the four road fights were doubled together
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
    -- A pack that grows as the descent runs on, and gains an alpha late.
    composition = function(ctx)
        local p = ctx.depth or 1
        local list = {}
        for i = 1, 2 + math.floor(p / 2) do list[i] = "character_wolf_grunt" end
        if p >= 3 then list[#list + 1] = "character_wolf_alpha" end
        return list
    end,
}
