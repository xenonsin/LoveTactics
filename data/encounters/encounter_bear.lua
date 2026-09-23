-- THE BEAR: the road fight that teaches Fury Swipes, and the reason the sow is an exam rather than an
-- ambush.
--
-- THE LESSON HAS TO COME FIRST, and for this animal that is not a preference. The bear shape is a DRUID
-- ability (data/items/ability/ability_wild_shape_bear.lua), so a company without one would otherwise
-- meet the only compounding threat in the game for the first time on a 2x2 boss, with a cub already
-- three stacks into somebody. encounter_the_unseeing's header states the rule for the pair -- "the lanes
-- are the lesson and the lord is the exam" -- and this is the lesson half.
--
-- ONE BEAR IS A WHOLE FIGHT, which is why the composition climbs so much more slowly than the boar's.
-- The boar opens at 2 and adds one every other day because a single boar is a jab with a charge behind
-- it; a bear is a body whose threat GROWS while you stand in front of it. Two at once is not twice a
-- bear, it is two independent ramps on two different bodies, which is the shape of fight this encounter
-- is deliberately slow to hand out -- see the composition for how slow it turned out it could afford
-- to be.
--
-- depth 2 rather than 1. The boar owns the first morning (weight 6, depth 1) and should: it teaches
-- the lane, which is the other spatial question on the road. A company meeting a ramp before it has met
-- a charge has been handed the harder of the two lessons first for no reason.
--
-- No biome condition, which is the road stock's own convention (boar, wolf, ogre and stag all carry
-- none) rather than a claim that bears live in lava. The circles gate their own fights; the road does
-- not, and making this the one exception would be a rule nothing else follows.
local Band = require("models.band")

return {
    name = "Bear",
    kind = "combat",
    -- Half the boar's 6. It should be a fight the company has certainly seen by the time the sow is
    -- reachable, and not one the road is made of -- the boar is the animal you meet, this is the animal
    -- you remember. Measured against the pool with `. board-report` after any change here.
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
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        -- IT HAS TO KEEP PACE, AND IT HAS TO STOP. Both halves were learned the hard way and the two
        -- pull against each other, which is why the expression has a floor AND a ceiling.
        --
        -- KEEPING PACE. The first cut was `1 + day/8`, written to say "a bear fight is about the ramp,
        -- not the count" -- true of how it PLAYS and false of how it is RATED. Muster sums the opening
        -- roster against the company (models/muster.lua) and a company grows faster than that curve, so
        -- tests/descent_spec.lua caught floor 5 offering this at 218% of the party, past
        -- Muster.WALK_OVER: the fight could be declined outright. A road fight nobody has to take is not
        -- a lesson, and being the lesson is this fight's whole job.
        --
        -- ...AND STOPPING, WHICH IS WHERE THE CEILING COMES FROM. THE PARTY DOES NOT HEAL BETWEEN
        -- FIGHTS. A floor is walked on one health bar, so what a road stop costs is not just its own
        -- length -- it is everything the company no longer has for the next one. tests/skirmish_spec.lua
        -- measures exactly that, a sequence of fights on one company, and an unbounded bear count showed
        -- up as the BOAR fight growing by a turn: the company was arriving at it already mauled.
        --
        -- FOUR IS THE CAP AND THE ANIMAL IS THE REASON. A boar scales without limit because a sounder is
        -- a crowd -- `2 + day/2`, and by the deep floors it is a wall of them. A bear is not a herd
        -- animal and never becomes one; what makes a deep-floor bear worse is that it is a deeper-floor
        -- bear, which Growth.spawn already does by minting the body at the fight's own level (which is
        -- also why a capped count still rates: Muster prices the far side at the level it will really
        -- spawn at, not at the blueprint). More bears would be the wrong answer to depth twice over.
        return Band.fill({}, ctx, "character_bear", { base = 2, per = 2, max = 4 })
    end,
}
