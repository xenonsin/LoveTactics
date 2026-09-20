-- THE MEANDERING STAG: met in the wood, and the one apex on the road you are meant to be able to walk
-- away from.
--
-- `kind = "elite"` rather than "combat", which is the honest label and also the one that measures it
-- correctly: tests/skirmish_spec.lua holds ORDINARY fights to a short budget and judges elites
-- separately, and a fight whose first half is a terrain problem is not an ordinary stop.
--
-- BUT THE LABEL IS DOING SOMETHING ELSE HERE TOO, and it is the premise rather than the filing. Elites
-- are what still stand on a descent floor after the ordinary fighting left it -- a threat you can read
-- from across the board, price against the company, and route around. Nothing about this animal comes
-- looking for anybody. It should be possible to see it on the map and go somewhere else, and now that
-- the Run Away plate always works (models/flee.lua) it is possible to see it on the DEPLOY screen and
-- do the same.
--
-- IT DOES NOT FIGHT, SO THE WOOD DOES. The escort is not filler and it is not a wall in front of the
-- boss: it is the only thing on the board that can hurt anybody for the first half, and the stag is
-- its HEALER -- running between them laying ground that mends whatever stands on it
-- (data/hazards/hazard_bloom.lua). No other boss in this bestiary is a support unit.
--
-- Which is where the first half's decision comes from, and it is a real one. Race the stag down to
-- stop the healing, and reach the threshold with the pack still standing and a short trail on the
-- floor. Grind the pack first, and meet a much longer trail -- which is the Vengeful Spirit's
-- ammunition (ability_swailing.lua). Both roads cost. Neither is the answer.
--
-- WOLVES AND BOARS, not the circle's own chaff. The Petal-Drifts and Choristers belong to Lust and
-- would make this read as a demon's floor; this is an animal, met in a wood, and what comes with it is
-- the rest of the wood. They are also both bodies the player has already learned to read
-- (encounter_wolf at weight 6 from day 1, encounter_boar beside it), which matters when the thing
-- BEHIND them is doing something no fight has done before.
--
-- A FOREST FIGHT, by condition rather than convention -- the wood the White Wolf belongs to
-- (encounter_white_wolf.lua) and the Winter Hart's tundra's opposite number. Two apexes in one stratum
-- is not a collision: hers is a PACK fight, this is a solitary one, and a wood that holds both reads
-- as a place rather than a slot. Thornveil's `glades` carve -- open trails through thick cover -- is
-- also exactly the ground a running animal needs to be uncatchable on, and exactly the ground a
-- company needs if it means to corner one.
--
-- minDay 8, behind the White Wolf's 5 and the Sow's 6, because it is the last thing the wood has and
-- because a company that has never had to corner anything has been asked a question nobody set up.
return {
    name = "The Meandering Stag",
    kind = "elite",
    weight = 2, -- the road's apexes: met rarely
    minDay = 8,
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_meandering_stag" }
        -- THREE AT THE OPEN, growing shallowly. Muster.encounter rates a fight by summing its opening
        -- roster and nothing else, and a boss contributing ZERO damage to that sum is a fight this
        -- system cannot see properly -- so the escort is carrying the whole rating as well as the whole
        -- threat. Three is what makes the first exchange read as a fight rather than as a large animal
        -- walking away from you.
        local day = ctx.day or 1
        for _ = 1, 2 + math.floor(day / 14) do
            list[#list + 1] = "character_wolf_grunt"
        end
        for _ = 1, 1 + math.floor(day / 20) do
            list[#list + 1] = "character_boar"
        end
        return list
    end,
}
