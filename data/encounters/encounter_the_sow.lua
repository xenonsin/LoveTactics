-- THE SOW: a mother and her cub, met on the road rather than commissioned.
--
-- `kind = "elite"` rather than "combat", which is the honest label and also the one that measures it
-- correctly: tests/skirmish_spec.lua holds ORDINARY road fights to a short budget and judges elites
-- separately. A fight whose whole back half depends on a choice the player makes about a body is not an
-- ordinary stop. See data/characters/character_sow.lua for the fight.
--
-- SHE OPENS WITH A LITTER, AND IT IS THE ANIMAL RATHER THAN A BUDGET. encounter_the_unseeing opens with
-- three boars it does not need, because Muster.encounter rates a fight by summing its OPENING roster and
-- a lord who spends his turns making more bodies is structurally under-rated. Nothing here is under-rated
-- in that way: every body is on the board from the bell and none of them makes more.
--
-- It was authored as a fixed pair and that was wrong for a reason worth keeping: a fixed roster cannot
-- keep pace with a company that grows floor on floor, and the fight came out walk-over-able at floor 10.
-- What it is NOT is the rating being padded -- see the composition for why one cub and three cubs are
-- the same single decision.
--
-- depth 6, behind encounter_bear's 2. The gate is real rather than aspirational: the road bear is what
-- teaches Fury Swipes at a size that can be survived, and this is the first time the ramp arrives on a
-- 2x2 body with a second one already working on your line. A company that meets her having never seen
-- the wound deepen has been asked a question nobody set up.
--
-- WHY NO ESCORT. Every other elite on the road brings its own stock and this one brings a yearling,
-- which reads as thin until you notice what the cub IS: it is the fight's offer. Filler would give the
-- player something else to kill, and the whole fight is about whether they kill the one thing standing
-- in front of them.
local Band = require("models.band")

return {
    name = "The Sow",
    kind = "elite",
    weight = 2, -- the Unseeing's weight: a road apex, met rarely
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
        -- A LITTER, NOT A ROSTER. One cub early and up to three deep, because a fixed pair could not keep
        -- pace: a company grows floor on floor and Muster rates the OPENING roster, so the fight she was
        -- authored as rated 202% of a floor-10 party -- past Muster.WALK_OVER, meaning it could be
        -- declined outright. A boss the party may walk past is not a boss.
        --
        -- AND THE DECISION IS UNCHANGED, which is the only reason this is allowed to move. Killing any
        -- cub wakes her exactly once (trait_bereaved latches; tests/sow_spec.lua pins that a second one
        -- must not double her), and all of them leave together if she drops first (trait_orphaned). So
        -- three cubs is not three decisions -- it is the same single decision with more of the thing you
        -- would have to leave standing, which makes the merciful road cost more rather than cost
        -- differently. A sow raises one to three; this is the animal, not a budget.
        local list = { "character_sow" }
        return Band.fill(list, ctx, "character_bear", { base = 1, per = 5, max = 3 })
    end,
}
