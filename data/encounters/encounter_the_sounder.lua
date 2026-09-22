-- THE SOUNDER: boar, plural. A sounder is what a group of them is actually called.
--
-- encounter_boar.lua fields one animal and reads as texture; three of them read as a decision about
-- where to stand. Nothing new is needed for it -- the body has always been there and has never been
-- brought in numbers.
--
-- Deliberately NOT built around character_pig, which is a shape a hunter wears rather than a body that
-- fights (one health, tier 0). See character_wyrmling.lua on why a worn shape and a combatant have to
-- be separate blueprints.
return {
    name = "The Sounder",
    kind = "combat",
    weight = 4,
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
        local list = {}
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_boar"
        end
        return list
    end,
}
