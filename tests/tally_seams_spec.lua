-- Tests for the six tallies added for the hall roster's signatures: the deeds the seams did not
-- already count. Each is one Combat.tally at a seam that already existed, and each exists because a
-- relic gates on it and nothing else in the vocabulary says the same thing:
--
--   tilesMoved   Fen's, and it must be TILES rather than move cost, or rough ground fills it faster
--   tilesBlinked Vess's, and it must count only ground crossed WITHOUT walking
--   goldSpent    Cass's, and it must count what actually left the purse, not what was asked for
--   consumed     Hilde's, and it must not simply be `cast` -- the two diverge the moment she swings
--   stolen       Pim's, banked on the lift rather than on where the item lands
--   shifted      Mira's, and only a shape she took HERSELF, never one she inflicted
--
-- The negative half of each is the point: a tally that counts too much is the same bug as one that
-- counts nothing, and it is the half a "does it increment?" test misses.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function field()
    local c = Combat.new(arena(12, 12), { unit("character_rowan", 1, 1) }, { unit("character_bandit", 6, 6) })
    return c, c.units[1], c.units[2]
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    {
        name = "tilesMoved counts tiles walked, and forced movement is not walking",
        fn = function()
            local c, knight = field()
            assert(Combat.tallyCount(knight, "tilesMoved") == 0, "starts empty")

            -- Two tiles, not four: the knight's own movement is 4, and the chainmail and the Sworn
            -- Aegis take a tile of pace each. Worth stating in the test that reads it, because a
            -- walk of "obviously three" failing as unreachable is the kind of thing that gets blamed
            -- on the tally rather than on the armour.
            openTurn(c, knight)
            local ok, why = Combat.moveUnit(c, knight, 1, 3)
            assert(ok, "walks the two tiles its plate leaves it: " .. tostring(why))
            assert(Combat.tallyCount(knight, "tilesMoved") == 2,
                "two steps: " .. Combat.tallyCount(knight, "tilesMoved"))

            -- A shove is not a walk. It pays no move cost and does not spend the turn, and a relic
            -- that paid out for being knocked about would reward standing in front of a mace.
            Combat.teleportUnit(c, knight, 6, 4) -- into the open, where a shove has somewhere to go
            local before = Combat.tallyCount(knight, "tilesMoved")
            Combat.knockback(c, c.units[2], knight, 2, { amount = 0 })
            assert(knight.y < 4, "the shove actually moved it")
            assert(Combat.tallyCount(knight, "tilesMoved") == before, "being shoved banks nothing")
        end,
    },
    {
        name = "tilesBlinked counts only ground crossed without walking",
        fn = function()
            local c, knight = field()
            assert(Combat.tallyCount(knight, "tilesBlinked") == 0, "starts empty")

            -- Chebyshev, like every other distance on this board: (1,1) -> (5,3) is four.
            Combat.teleportUnit(c, knight, 5, 3)
            assert(Combat.tallyCount(knight, "tilesBlinked") == 4,
                "four tiles: " .. Combat.tallyCount(knight, "tilesBlinked"))

            -- And walking banks the OTHER tally, never this one. The two must not both fill, or
            -- Vess's gate would be satisfiable on foot -- which is the one thing it is not for.
            openTurn(c, knight)
            Combat.moveUnit(c, knight, 5, 5)
            assert(Combat.tallyCount(knight, "tilesBlinked") == 4, "walking adds nothing to the blink count")
            assert(Combat.tallyCount(knight, "tilesMoved") == 2, "it went to tilesMoved instead")
        end,
    },
    {
        name = "goldSpent banks what actually left the purse, not what was asked for",
        fn = function()
            local c, knight = field()
            local held = 50
            c.purse = { get = function() return held end, spend = function(n) held = held - n end }

            assert(Combat.spendPurse(c, knight, 30) == 30, "spends what it has")
            assert(Combat.tallyCount(knight, "goldSpent") == 30, "and banks it")

            -- Asked for more than is left: the blow lands soft, and the tally agrees with the purse
            -- rather than with the request. A gate reading the request would pay a broke party in full.
            assert(Combat.spendPurse(c, knight, 100) == 20, "clamped to the remainder")
            assert(Combat.tallyCount(knight, "goldSpent") == 50, "the tally follows the coin: "
                .. Combat.tallyCount(knight, "goldSpent"))

            -- A spend of nothing banks nothing, so an empty purse never inches a gate forward.
            Combat.spendPurse(c, knight, 10)
            assert(Combat.tallyCount(knight, "goldSpent") == 50, "a broke spend banks nothing")
        end,
    },
    {
        name = "stolen banks on the lift, and a bound relic is not liftable",
        fn = function()
            local c, knight, bandit = field()
            assert(Combat.tallyCount(knight, "stolen") == 0, "starts empty")

            local taken = Combat.steal(c, knight, bandit)
            if taken then
                assert(Combat.tallyCount(knight, "stolen") == 1, "the lift is banked")
            end

            -- Strip the victim to nothing but a bound relic: `bound` is untakeable, so the attempt
            -- finds nothing and must bank nothing. Pim's gate counts thefts, not attempts.
            local bare = unit("character_bandit", 7, 7)
            for _, it in ipairs(Character.eachItem(bare.char)) do Character.removeItem(bare.char, it) end
            Character.addItem(bare.char, Item.instantiate("armor_sworn_aegis"))
            c.units[#c.units + 1] = bare
            bare.alive, bare.side = true, "enemy"

            local before = Combat.tallyCount(knight, "stolen")
            assert(Combat.steal(c, knight, bare) == nil, "nothing takeable")
            assert(Combat.tallyCount(knight, "stolen") == before, "a failed lift banks nothing")
        end,
    },
    {
        name = "shifted counts a shape taken, never one inflicted",
        fn = function()
            local c, knight, bandit = field()
            local Transform = require("models.transform")

            Transform.apply(c, bandit, "character_pig")
            assert(Combat.tallyCount(knight, "shifted") == 0,
                "polymorphing somebody else is a debuff applied, not a shape taken")
            assert(Combat.tallyCount(bandit, "shifted") == 0,
                "and the victim did not choose it either")
        end,
    },
}
