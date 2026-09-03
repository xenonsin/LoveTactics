-- VALUABLES: the campaign's money, in the only form it comes in -- objects, with weight, that have to
-- be carried out of the rift and sold.
--
-- WHAT THEY ARE FOR. Gold used to fall out of fights as a number, which meant it arrived weightless,
-- could not be dropped, could not be stolen, could not be left behind, and had to be protected by a
-- special rule (Player.loseHaul's percentage haircut) because the two systems built to put a haul at
-- risk -- the mule's cap and the bloodstain (Descent.dropPack) -- only work on THINGS. A number could
-- not participate in either.
--
-- So the campaign's income is objects now. A valuable is an item with a price, no class, no shelf, no
-- effect and no use: its entire purpose is to be picked up, to take up room while it is carried, and to
-- be sold at a counter in the city. And every system that already handles items handles it:
--
--   THE MULE       it occupies slots (Valuable.bulk), so treasure competes with the gear you found for
--                  the eight the mule holds. That is the knapsack the mule's cap was built to create and
--                  never had anything to fill it with -- gear's value is diffuse ("might I use this?"),
--                  and a valuable puts a QUOTED number on the slot it takes.
--   THE BLOODSTAIN a wipe drops the pack where the company fell, and the pack now contains the run's
--                  income. So the takings are recoverable by walking back down to the tile -- which a
--                  flat percentage cut could never offer -- and Player.loseHaul stops needing to touch
--                  gold at all. The rule was deleted, not added.
--
-- BULK IS THE KNOB, and it is why the small ones are not simply worse. Value per slot CLIMBS with bulk:
-- a three-slot idol is worth more per slot than three pocket pieces, so the deep floors' lumpy finds
-- are the ones worth clearing space for, and "leave the censer, take the idol" is the decision. A set
-- where everything was one slot would only ever ask "how many", which is not a question.
--
-- WHERE THEY COME FROM. Ends -- elites, objectives, generals, the work a player chose to walk to
-- (models/spoils.lua). Never off an ordinary body: at one valuable per fight this is an inventory chore
-- with a floor's worth of clicking in it, and the ambient income is scrip's job (models/scrip.lua).
-- That split is the whole economy in one line -- the grind funds in-run power, the errand funds the
-- campaign.
--
-- THERE IS NO FENCE, and that is a decision rather than an omission. Selling a valuable underground for
-- scrip is the obvious next feature -- it converts progression into in-run power, which is a real greed
-- decision -- and it is deliberately not built, because the thing it was going to solve is already
-- solved: a company with a full mule far from the stair sends the mule home (Mule.dispatch). Adding a
-- second answer to the same question would make both of them smaller. If it is ever built, it runs ONE
-- direction and at a rate bad enough to hurt: scrip must never buy a valuable, and nothing underground
-- may take gold. See models/scrip.lua for why that asymmetry is the whole design.
--
-- Pure model: no love.graphics at require time, so it loads under the headless runner.

local Item = require("models.item")

local Valuable = {}

-- HOW MANY MULE SLOTS one takes when the blueprint does not say. One, so a valuable authored without
-- thinking about weight behaves like every other item in the game rather than becoming free freight.
Valuable.DEFAULT_BULK = 1

-- Is this a valuable? Takes an id, a blueprint or a live instance, because the three callers have three
-- of those: the drop pool holds ids, Vendor.sells is handed a def, and the mule is counting instances.
function Valuable.is(what)
    if type(what) == "string" then what = Item.defs[what] end
    return not not (what and what.valuable)
end

-- How many mule slots `what` occupies. ONE for everything that is not a valuable, which is what makes
-- this safe to call over a whole stash: bulk is a valuable's field, and asking any other item for its
-- weight gets the answer the mule has always given.
function Valuable.bulk(what)
    if type(what) == "string" then what = Item.defs[what] end
    if not Valuable.is(what) then return 1 end
    return math.max(1, math.floor(what.bulk or Valuable.DEFAULT_BULK))
end

-- What a city counter pays for `item`, in gold. ITS FULL PRICE, not the half an ordinary piece of gear
-- sells back for, and the difference is not generosity -- it is that the two numbers mean different
-- things. Gear's `price` is what a shop CHARGES, so selling one back at half is the shop's margin on a
-- thing you already bought. Nobody ever sold you a valuable. Its price is its worth, and a haircut
-- there would just mean every valuable in the data is authored at double what it is worth, which is a
-- lie stored in a hundred files instead of a rule stored in one.
function Valuable.value(what)
    if type(what) == "string" then what = Item.defs[what] end
    if not Valuable.is(what) then return 0 end
    return math.max(0, math.floor(what.price or 0))
end

-- Every valuable the rift can give up at `depth`, as a list of ids. `depth` is the floor level the fight
-- was on; a blueprint's own `depth` is the shallowest floor it appears on, so the pool widens as the
-- company descends and the deep, lumpy pieces cannot turn up in the first hour.
--
-- SORTED BY ID rather than left in `pairs` order, because the roll below draws from it and a pool whose
-- ORDER changes between runs makes a seeded floor unreproducible -- which is the bug models/seed.lua
-- exists to prevent and the one Overworld:snapshot is still carrying.
function Valuable.pool(depth)
    depth = math.max(1, math.floor(tonumber(depth) or 1))
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.valuable and (def.depth or 1) <= depth then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- HOW MANY PIECES AN END LEAVES, by what kind of end it was. An elite is a fight the player could have
-- walked around; an objective is the one they came down for; a general closes a circle. The ladder is
-- flat and short on purpose -- what makes a deep end pay more is WHICH pieces its depth has unlocked
-- (Valuable.pool), not how many it hands over, because the count is what turns into clicking and the
-- worth is what turns into a decision.
Valuable.DROPS = { elite = 1, objective = 1, general = 2 }

-- Roll the valuables an end leaves behind, as a list of ids (empty for an ordinary fight).
--   opts.kind    "elite" | "objective" | "general"; anything else pays none
--   opts.depth   the floor level, which decides how deep the pool goes
--   opts.rnd     injectable RNG, () -> [0,1). Defaults to love.math/math.random, so a seeded caller
--                gets a reproducible haul and a headless test can pin one.
--
-- BIASED TOWARD THE DEEP END OF WHAT IS AVAILABLE, by drawing twice and keeping the dearer piece. A
-- flat draw over a pool that only ever widens means floor eleven pays its floor-one censer as often as
-- its idol, so descending would raise the CEILING on a haul without raising the haul -- and the greed
-- the landing question needs is a company that can feel the floor getting richer.
function Valuable.roll(opts)
    opts = opts or {}
    local n = Valuable.DROPS[opts.kind or ""] or 0
    if n <= 0 then return {} end
    local pool = Valuable.pool(opts.depth)
    if #pool == 0 then return {} end
    local rnd = opts.rnd or function()
        if love and love.math and love.math.random then return love.math.random() end
        return math.random()
    end

    local out = {}
    for _ = 1, n do
        local a = pool[math.max(1, math.min(#pool, math.floor(rnd() * #pool) + 1))]
        local b = pool[math.max(1, math.min(#pool, math.floor(rnd() * #pool) + 1))]
        local pa, pb = (Item.defs[a] or {}).price or 0, (Item.defs[b] or {}).price or 0
        out[#out + 1] = (pb > pa) and b or a
    end
    return out
end

return Valuable
