-- THE SECOND DRAUGHT: a work party that has been drinking its own stock.
--
-- Envy's glass fields are full of things that copy what they face, and this is the human version of
-- the same joke: a company that could not be better than the one ahead of it and settled for being
-- a worse copy, faster. They throw before they close and they are frail behind it.
--
-- Envy's floor is among the thinnest of the seven for bodies that carry gear, which is why a stop
-- that seats two alchemists is worth more than it looks (docs/drops.md).
--
-- Weight and scaling follow the circle's existing traffic (encounter_envy_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Second Draught",
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
    condition = function(ctx) return ctx.biome == "desert" end,
    -- SMALLER THAN ITS SEVEN SIBLINGS, AND MEASURED RATHER THAN GUESSED. At a lead plus two-to-three
    -- beaters this stop ran 54 unit-turns against tests/skirmish_spec.lua's budget of 22 -- the worst
    -- ordinary fight in the game by a factor of two.
    --
    -- Nothing here can kill anything, which is Envy's cast working as authored and wrong for a common
    -- stop: the Apothecary is "feeble on purpose: the payload is what she lends, not what she hits" and
    -- she MENDS her own side, and the Alchemist swings for six. Four such bodies is not a hard fight,
    -- it is a long one -- a party grinding through two hundred health while a healer tops it back up.
    --
    -- So the pack is three at its widest and the healer is the one you have to reach. That is also the
    -- better reading of the stop: what makes this dangerous is the thing keeping the others standing.
    composition = function(ctx)
        -- TWO CHEMISTS AND A LINE THAT GROWS WITH THE STACK. An apothecary and one alchemist rated
        -- 201% of the company on floor eleven -- past Muster.WALK_OVER, so the game offered to resolve
        -- Envy's own ordinary traffic without a board, which tests/descent_spec.lua forbids a floor to
        -- offer. The old `depth / 8` was `day / 20` converted, and twenty days of a forty-day campaign
        -- is half of it; a fifth of fifteen floors is three, so the ramp had lost most of its climb.
        local list = { "character_apothecary", "character_apothecary" }
        for _ = 1, 1 + math.floor((ctx.depth or 1) / 3) do
            list[#list + 1] = "character_alchemist"
        end
        return list
    end,
}
