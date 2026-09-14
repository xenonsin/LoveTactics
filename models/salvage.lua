-- SALVAGE: breaking a piece you carry down into the stock the Forge bills in.
--
-- The faucet the drop loop was missing. docs/drops.md states the case: an ARPG's drop schedule is only
-- survivable because the trash is the currency -- the Horadric cube, a runeword, a PoE vendor recipe --
-- and here a second copy of anything was worth strictly LESS than the first (Vendor.sellValue, half of
-- price) and could become nothing else. So the commonest outcome of a fight was a disappointment, and
-- the only lever on that was the drop rate, which is not the lever.
--
-- Breaking a piece pays its OWN house's stock and its OWN quality's craft stock, which is the whole
-- design in one line: the junk becomes depth on the thing you actually carry, from the same line it
-- came off. Farm a Wrath body for a Wrath blade, break the third one, forge the first.
--
-- IT READS THE BLUEPRINT, NEVER THE INSTANCE'S LEVEL, and that is a refusal rather than a
-- simplification. Paying anything back for forged rungs opens a bench-to-bench arbitrage -- forge it
-- up, break it down, bank the difference -- and the only thing standing between that and an exploit
-- would be an inequality nobody can check by reading. The rungs you spent are spent. What you get back
-- is what the OBJECT is, which is also the only thing a player can predict without arithmetic.
--
-- A FIRST COPY MAY BE BROKEN. Decided 2026-09-14 and it is the interesting half: a salvage that only
-- ever ate duplicates is a disposal chute, and "keep this or break it" is a real decision only while
-- the piece in your hand might be the only one. What that obliges is the mark below -- see
-- Salvage.breakDown, which stamps the discovery ledger before the item goes.
--
-- WHAT IT MAY NEVER BEAT is keeping the piece. Salvage.YIELD_* are sized well under one forge rung
-- (models/forge.lua's materialsFor bills target+1 craft stock and one-to-two house stock PER RUNG), so
-- breaking a thing is a way to make progress on something else, never the optimal first move on a good
-- drop. That inequality is pinned in tests/salvage_spec.lua rather than left to reading.
--
-- Pure logic, headless-safe: no love.graphics at require time, no RNG at all. A salvage is a
-- computation, not a roll -- the player is told exactly what breaking a thing pays before they press
-- the button, because a gamble on top of a gamble is not a decision (docs/identification.md makes the
-- same argument about the reading's floor).

local Class = require("models.class")
local Item = require("models.item")
local Material = require("models.material")
local Player = require("models.player")
local Spoils = require("models.spoils")

local Salvage = {}

-- ONE OF EACH, AND DEPTH BUYS A BETTER GRADE RATHER THAN A BIGGER PILE.
--
-- The first cut of this paid more craft stock the deeper the piece was ranked, and it broke the
-- inequality above at exactly the place you would expect: a deep crossing item pays two parent houses,
-- so three craft plus two house is five stock against a first rung that costs four. Scaling the
-- QUANTITY of a yield against a bench whose own bill starts small has no headroom in it.
--
-- Grading the yield instead has all the headroom it needs and says the truer thing anyway: what a deep
-- find is worth breaking for is better ORE, not more of the cheap kind. A floor-two hauberk gives
-- scrap; a floor-eight one gives mythril; both give exactly one, and one house stock beside it. So a
-- break is always two or three pieces of stock against a first rung's three or four, structurally,
-- whatever either ladder is re-cut to.
Salvage.CRAFT = 1
Salvage.HOUSE = 1

-- An item's class the way the FORGE reads it: one field, already naming the most specific claim
-- (docs/class-fold.md). An earned class pays its parents, exactly as the bench bills them, so breaking
-- a Ninja blade stocks the rogue line it descends from rather than a "ninja" house that does not exist.
local function housesFor(class)
    local out = {}
    if not (class and Class.defs[class]) then return out end
    if Class.isRoot(class) then
        local id = Material.houseFor(class)
        if id then out[#out + 1] = id end
        return out
    end
    for _, parent in ipairs(Class.parents(class)) do
        local id = Material.houseFor(parent)
        if id then out[#out + 1] = id end
    end
    return out
end

-- What breaking `item` pays, as a `{ [materialId] = count }` table. Takes an instance or a bare
-- `{ id = ... }`; reads the blueprint for everything, so two copies of one thing always break the same.
-- An unknown id pays nothing rather than erroring -- the panel simply draws no rows.
function Salvage.yield(item)
    local def = item and item.id and Item.defs[item.id]
    if not def then return {} end

    local out = {}
    local function add(id, n)
        if id and n > 0 then out[id] = (out[id] or 0) + n end
    end

    add(Salvage.craftGradeFor(def), Salvage.CRAFT)
    for _, houseId in ipairs(housesFor(def.class)) do add(houseId, Salvage.HOUSE) end

    return out
end

-- WHICH craft grade a broken piece pays, and it reads DEPTH rather than price.
--
-- `Material.gradeFor` bands on price, which is the right question at the bench: what you are forging
-- is something you bought, and what you paid for it says what it is made of. It is the wrong question
-- here, because above a house's opening rung the found catalogue carries no price at all
-- (docs/shelf.md) -- so every weapon, every coat and every charm the rift hands up would grade as
-- scrap, and the deepest find in the game would break into the cheapest ore in it.
--
-- `Spoils.depthOf` is the axis that survived the recut and it answers the same question for an
-- unpriced thing: how dear is this. Banded in even thirds up the class ladder, which is the same cut
-- and the same argument Material.GRADE_BY_PRICE makes about the shelf -- with one grade per band there
-- is no cut that makes the middle twice the ends.
--
-- A PRICED piece still reads its price, so the two halves of the catalogue never disagree about the
-- same object: an opening weapon is scrap whichever way you ask.
function Salvage.craftGradeFor(def)
    if def and def.price and def.price > 0 then return Material.gradeFor(def) end

    local grades = Material.craftGrades()
    local depth = math.max(1, Spoils.depthOf(def))
    local span = math.max(1, Class.CLASS_LEVEL_CAP)
    local band = math.min(#grades, math.max(1, math.ceil(depth / (span / #grades))))
    return grades[band]
end

-- May this piece be broken, and if not, WHY -- the string a panel prints under a greyed button rather
-- than a bare false (ui/panels/*.lua's own convention; see Vendor.stock's lockReason).
--
-- Three refusals and no fourth. Note what is NOT here: owning only one is not a refusal, and neither
-- is never having carried one out (see the header).
function Salvage.refusal(player, item)
    local def = item and item.id and Item.defs[item.id]
    if not def then return "unknown" end
    -- Nailed to one grid by definition -- a boss's phase machinery is not stock.
    if def.bound then return "bound" end
    -- A husk has no readable identity yet, so there is nothing to tell the player they are breaking.
    -- The Touchstone names it first; that is what the Touchstone is for.
    if require("models.identify").isUnidentified(item) then return "unread" end
    -- Nothing to give back means nothing to decide about.
    if next(Salvage.yield(item)) == nil then return "worthless" end
    return nil
end

function Salvage.canBreak(player, item)
    return Salvage.refusal(player, item) == nil
end

-- Break `item`, banking its yield onto `player`. Returns the yield table on success, or nil plus the
-- refusal string. DOES NOT REMOVE THE ITEM -- the caller owns where it was (a stash index, a grid
-- cell), and a model that reached into both would be guessing at which.
--
-- THE MARK IS THE WHOLE OBLIGATION OF LETTING A FIRST COPY BREAK. Player.recordFound stamps at the
-- SURFACE, walking roster grids and the stash -- so a piece broken underground is not in either when
-- that fires, and its counter line would be lost for good (models/vendor.lua deals a found ware only
-- once the ledger holds it). Stamping here is the Touchstone's own precedent said in another material:
-- a sale there is not final, because a shelf that silently drops its oldest is a shelf that steals.
function Salvage.breakDown(player, item)
    local why = Salvage.refusal(player, item)
    if why then return nil, why end

    local yield = Salvage.yield(item)
    for id, count in pairs(yield) do Player.addMaterial(player, id, count) end
    -- Before the item goes anywhere, so the line it opens survives the decision to break it.
    Player.markFound(player, item.id)
    return yield
end

return Salvage
