-- THE BELL LOFT: the Lust circle's fifth ordinary fight, and the stratum's own thesis played at full
-- volume by something that cannot be answered the way the stratum is usually answered.
--
-- THE BELL RINGS AND THERE HAS BEEN NOBODY ON THE ROPE FOR A LONG TIME. What is up here is the other
-- half of what the blooding left in the building -- the breath, where the lamp rooms have the heat
-- (data/characters/character_wind_elemental.lua). The city below still sets its day by it.
--
-- THREE TILES, WHICH IS THE WHOLE FIGHT. models/descent.lua's Lust entry says the flock rearranges a
-- company and the BUILDING kills it, and every fight on this floor has been a quiet version of that: a
-- gust moves a body one tile, a kiss trades two. A bellstroke throws a body three, and Combat.knockback
-- bills the impact of every tile the shove could not spend -- so in a warren of thin walls the same
-- sentence, unchanged, is suddenly lethal. A company that learned the Open Roof and thinks it has
-- learned this circle's wind meets the version where the lesson costs a body.
--
-- AND THE ANSWER THE FLOOR HAS BEEN TEACHING DOES NOT WORK HERE. Cut the one doing it is this circle's
-- law and it has held on every stop -- a charm ends with its charmer, a jeer with its taunter, a coil
-- with the serpent. The law still holds; what has gone is the walking over. A Wind Elemental wears Unheld
-- from the bell (trait_nothing_to_hold), so it cannot be hauled into reach, cannot be shoved off a
-- ledge, cannot be pinned by anything the party carries -- and it holds the gap at exactly the range it
-- throws from. Reaching the one doing it is the fight, and this is the only stop on the stratum where
-- it is.
--
-- IT IS ALSO WHERE THE CIRCLE ARGUES WITH ITSELF, WHICH IS LEFT IN AND IS THE REASON A FLOOR THAT ROLLS
-- BOTH IS WORTH ROLLING. A harpy caught in a room with one of these is a harpy whose whole trade is now
-- happening at somebody else's scale; a lamia's coil closes on a draught and shuts on nothing. The
-- stratum's bodies were never additive (the lamia's header argues this at length) and this is the end
-- of that argument: a body standing outside the entire conversation about where anybody is.
--
-- THE OPPOSITE OF THE CISTERN, AND MEANT TO BE MET IN EITHER ORDER. Down there a company that plants
-- itself has agreed to be bitten from three tiles away. Up here planting is very nearly the only thing
-- that works -- a party strung across a doorway hands the loft three tiles of purchase on every body in
-- it, and one packed into the middle of the floor eats a shove that ends on a friendly shoulder.
--
-- Locked to the castle stratum by ctx.biome. NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT.
local Band = require("models.band")

return {
    name = "The Bell Loft",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "castle" end,
    composition = function(ctx)
        -- ONE HEAVIER THAN THE CISTERN'S BAND, AND THE NUMBER WAS MEASURED RATHER THAN CHOSEN. This
        -- shipped on the Cistern's own count (base 1) on the argument that a tier-2 body which reaches
        -- does not need a crowd -- and tests/descent_spec's walk-over sweep rated it at 272% on floor
        -- three, which is a company nearly three times the fight and a stop states/game.lua would
        -- offer to skip outright. The argument was right about the FIGHT and wrong about the WEIGHT:
        -- this body is authored thin on purpose (44 health against the lamia's 62, because almost none
        -- of the damage on the readout is ever its own), so it needs the third body to be worth
        -- stopping for at all. Three of them throwing three tiles apiece is still more displacement
        -- than anything else on the floor fields.
        local list = { "character_wind_elemental" }
        return Band.fill(list, ctx, "character_wind_elemental", { base = 2, per = 5 })
    end,
}
