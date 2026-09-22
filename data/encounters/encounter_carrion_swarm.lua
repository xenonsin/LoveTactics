-- CARRION SWARM: nothing here can beat you, and that is not the same as nothing here mattering.
--
-- Four crawlers, each of which would rather eat a fallen body than fight a standing one. Individually
-- they are the cheapest chaff on the floor. Collectively they mean that the moment ANY of your company
-- goes down, the revive stops being a thing you will get to and becomes a thing you are racing for
-- (data/items/weapon/weapon_carrion_jaws.lua).
--
-- The most interesting property of this fight is that it is easy right up until it isn't, and what
-- flips it is a mistake you made two turns earlier.
local Band = require("models.band")

return {
    name = "Carrion Swarm",
    kind = "combat",
    weight = 3,
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
    -- IT HAS TO GROW, and the old slope (a fourth crawler on floor 10, a fifth never) did not. Three of
    -- the cheapest chaff in the game is a fight a deep company walks through without stopping, and
    -- tests/descent_spec.lua says outright that a floor may not offer one of those -- it was only ever
    -- kept off deep floors by Descent.floorPool's share filter, which drops a fight sitting under the
    -- floor's MEDIAN worth. That is a proxy, and it moved the first time the underworld's roster grew
    -- (data/encounters/encounter_the_bone_orchard.lua): two more mid-weight fights pulled the median
    -- down and this cleared the cut by a point and a half, at 222% of the company -- a walkover the
    -- filter had been hiding rather than a walkover anybody had decided on.
    --
    -- The fiction is unchanged and the slope is what carries it. "Nothing here can beat you" is a
    -- statement about ONE crawler and always was; the fight is the number of mouths waiting for
    -- somebody to go down, so a deeper floor wanting more mouths is the same sentence read further in.
    -- Capped at seven, because past that it stops being a race to a fallen body and becomes a wall.
    composition = function(ctx)
        return Band.fill({}, ctx, "character_carrion_crawler", { base = 3, per = 2, max = 7 })
    end,
}
