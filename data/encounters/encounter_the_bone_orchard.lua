-- THE BONE ORCHARD: the underworld's ordinary traffic, and the stop where the company finds out its
-- swords are decoration.
--
-- Deliberately the fen ooze's lesson (data/encounters/encounter_fen_ooze.lua) asked one aisle over and
-- far more gently. The ooze is a LOADOUT problem with no out -- bring no element and there is no fight
-- -- and it is gated at depth 6 for exactly that reason. This is the same question about DAMAGE TYPE,
-- with three differences that make it the shallow version:
--
--   * the answer is on a shelf every company has walked past. A mace is knight stock at rung 0.
--   * the wrong answer still works, slowly. `slash = 3` is mitigation, not immunity; a party of swords
--     wins this, it just spends the fight learning why it was unpleasant.
--   * every body on the board is holding the weapon that does not work on it, which is the joke and
--     also the tell -- these are dead KNIGHTS and dead ARCHERS, still carrying the iron sword and the
--     iron bow off the same shelves the party shops at, and none of it cuts bone any better in their
--     hands than it does in yours.
--
-- THE BODIES ARE ONES THE PLAYER ALREADY KNOWS, which is most of why this reads without a word of
-- explanation. Every one of them EXTENDS a living blueprint (data/characters/character_skeleton_knight.lua,
-- character_skeleton_archer.lua) and is drawn from that body's own token in bone, so the board says
-- "these were a company like yours" before anybody has taken a turn.
--
-- TWO RANKS ONCE THE ROAD HAS GONE ON, because one rank is a queue. The dead walk in and the archer
-- behind them charges for backing off, which closes the obvious escape from a melee line you cannot cut
-- and leaves the board with one honest answer on it.
--
-- ONE ARCHER, AND NEVER TWO, and that number is measured rather than chosen. The Skeleton Archer kites
-- (models/ai.lua's `skirmish` posture, inherited from the living archer), and a body that gives ground
-- in front of a party already swinging the wrong damage type turns a road stop into a chase: two of them
-- put this fight at 27 unit-turns against tests/skirmish_spec.lua's budget of 22. One sits inside it with
-- room to spare. The deeper orchard is a nastier SHAPE, not a longer fight -- the archer replaces a
-- walker rather than joining it, so the board stays three bodies and gets harder to walk at.
--
-- Gated to the underworld, the same predicate every circle keeps its stock with, so the stratum means
-- something and no engine work was needed to say so.
local Band = require("models.band")

return {
    name = "The Bone Orchard",
    kind = "combat",
    -- Ordinary weight: this IS what the underworld is, not a thing it sometimes deals. The lesson is
    -- cheap and the bodies are chaff, so meeting it often is the point.
    weight = 5,
    -- Shallow on purpose, and the whole difference from the ooze. There is no board here a company can
    -- be unable to win, so it needs no safety margin -- it only needs to arrive before the deep
    -- version of itself (data/encounters/encounter_the_barrow_knight.lua, depth 12).
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "underworld" end,
    -- THREE BODIES, AND IT IS A CEILING RATHER THAN A BUDGET. Written first as four-plus-two and
    -- measured at 54 unit-turns against tests/skirmish_spec.lua's budget of 22 -- two and a half times
    -- an ordinary stop, which is what happens when you put six bodies on a board and then hand the
    -- party the two damage types those bodies turn aside. The fight was doing its job so thoroughly
    -- that it stopped being a fight anybody wants to have twice.
    --
    -- The lesson does not need the bodies. "Your edges do nothing here" is taught by ONE skeleton and
    -- merely repeated by the fifth, so the count went to the smallest number that still fields two
    -- ranks -- and what grows with depth is the ratio of shooters to walkers rather than the total. A
    -- deeper orchard is a nastier shape, not a longer one.
    composition = function(ctx)
        -- A third body once the road has gone on -- and deeper still, that third body is the rank
        -- behind. NEVER A FOURTH OF ANYTHING, which is the ceiling argued above, so the bow does not
        -- join the knights: it REPLACES one, and the knights' own ceiling drops by exactly the bow.
        -- That is "a nastier shape, not a longer one" written as arithmetic.
        --
        -- The band says how many knights; it does not say whether the archer is there, because that is
        -- the depth telling the player the orchard has learned to shoot back (`vary = 0`).
        local bows = ((ctx.depth or 1) >= 14) and 1 or 0
        local list = Band.fill({}, ctx, "character_skeleton_knight",
            { base = 2, per = 8, max = 3 - bows })
        if bows > 0 then
            Band.fill(list, ctx, "character_skeleton_archer", { base = bows, max = bows, vary = 0 })
        end
        return list
    end,
}
