-- Vendor logic. Blueprints live in data/vendors/<id>.lua: a class vendor's identity.
-- Vendors are decoupled from hub geometry (data/buildings/) so a quest can name a sponsor
-- without knowing where its building stands, and from the player (every gate here takes a
-- plain count of quests-completed, not a player) so models/player.lua and this module do
-- not form a require cycle.
--
-- A vendor SELLS. It does not upgrade: every ladder in the game is climbed at the one bench
-- (models/forge.lua), which is also the only thing that spends materials. This module used to carry a
-- second door onto the same `item.level` -- abilities honed at their class vendor, consumables refined
-- per-type -- and having two doors onto one ladder meant two BILLS, two CEILINGS, and no single place
-- to look. Standing with a house is still the ceiling on how far its gear forges, but the Forge now
-- counts that itself (Forge.ceilingFor, off Quest.sponsorProgress) rather than borrowing a ladder
-- from here.
--
-- THE BENCH HAS TWO ROOMS AGAIN AND THIS IS NOT THAT BUG COMING BACK, which is worth saying here
-- because it is this header's own argument. What was wrong was two IMPLEMENTATIONS -- a second bill
-- and a second ceiling, quietly disagreeing with the first. The Bastion's forge and the Arcanum's
-- study are two doors onto one model: they ask models/forge.lua for the price, the ceiling and the
-- rung, and differ only in which kinds of work each offers (Forge.WORK). Two counters, one ledger.
--
-- A SHELF OPENS AS THE CLASS IT SELLS IS CLIMBED. Every ware names a rung and a rung is a class level
-- -- how far the roster's best holder of that class has got (Quest.shelfRung -> Class.rosterLevel).
-- There is no reputation score, no rank titles and no errand line; the houses stopped posting work at
-- the fold and the shelf has read the ladder ever since.
--
-- WHERE THAT RUNG COMES FROM DEPENDS ON WHETHER THE WARE IS FOR SALE OR FOUND. A priced one -- an
-- ability, a consumable, a house's opening weapon -- and everything else is found in the rift. BOTH
-- name the same field: `unlockLevel`, the class level that opens it, which is also the floor the rift
-- gives it up at (tools/ladder_fold folded the two apart axes into one):
-- the same conversion Vendor.foundPrice makes to quote it a price, so a found ware's cost and its gate
-- are one number (Vendor.lockReason).
--
-- Stock is *derived, not authored*: a vendor sells every item whose `class` matches its own and which
-- can be quoted a price at all. Adding data/items/<slot>/<id>.lua with the right class puts it on that
-- vendor's shelf.
--
-- One vendor is different: the Cafe declares `sells = false` and stocks NOTHING. It used to be the
-- general store -- the shelf for classless priced goods, plus a resale rack for every `potion`. Both
-- are gone: the five classless wares were given the houses that actually wanted them, and the resale
-- was a way to walk around the Crucible's own ladder. What the Cafe sells now is a meal before the
-- road, which is not an item at all (models/meal.lua, docs/meals.md). It keeps a blueprint here
-- because it keeps a shopkeeper -- a portrait, a name, a first-visit greeting.
--
-- The flag is stated on the vendor rather than assumed from an empty shelf, so an item that loses its
-- class by accident lands nowhere rather than quietly on the grocer's counter -- and so
-- tests/progression_spec.lua's "every priced item has a shelf" catches it.

local Registry = require("models.registry")
local Item = require("models.item")
local Class = require("models.class")

local Vendor = {}

Vendor.defs = Registry.load("data/vendors", "data.vendors")

function Vendor.get(id)
    return Vendor.defs[id]
end

-- The vendor id of the house that sells `class`, or nil for a classless one (the Cafe). Reverse-indexed
-- from the blueprints once, so the class -> house mapping lives in data rather than in a second table.
--
-- The single owner of that question. models/forge.lua asked it first (for a class item's ceiling) and
-- ui/panels/shop.lua now asks it too (to name the house a missing discipline parent is sold at), and
-- two private reverse indexes over the same field is exactly how they drift.
local byClass
function Vendor.forClass(class)
    if not class then return nil end
    if not byClass then
        byClass = {}
        for id, def in pairs(Vendor.defs) do
            if def.class then byClass[def.class] = id end
        end
    end
    return byClass[class]
end

-- Ordered list of vendors, for UI that enumerates them.
function Vendor.list()
    local list = {}
    for id, def in pairs(Vendor.defs) do
        list[#list + 1] = {
            id = id,
            name = def.name,
            class = def.class,
            description = def.description,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- (Vendor.TIERS / Vendor.tier -- the four-value wave enum { 0, 3, 6, 10 } -- used to live here. Item
-- gates left it when tools/unlock_rescale.lua rewrote all 339 onto per-quest `unlockLevel`, and the
-- Forge's class-item ceiling left it when that moved to Forge.CEILING_BASE + quests done. Nothing read
-- it after that, and a dead enum with no callers is exactly how the two halves of a house's offer
-- drifted onto different granularities in the first place, so it is deleted rather than kept around.)

-- The shelf price of a base item scaled to `level`: +50% of the base per tier, rounded. A consumable
-- refined to a higher recipe tier (Player.recipeLevel) is stocked and sold at this raised price. A nil
-- base (an item that was never for sale) stays nil. One place so shelf price and sell value agree.
function Vendor.priceFor(base, level)
    return base and math.floor(base * (1 + 0.5 * (level or 0)) + 0.5)
end

-- WHICH CLASSES A HOUSE'S SHELF CARRIES -- its own, and every cut of it. The taxonomy half of
-- Vendor.sells, lifted out because a second reader needed the question asked of a CLASS rather than of
-- an ITEM: the house a company training for a class opens (models/offer.lua's `declared` gate). One
-- rule, so the shelf that stocks a Ninja's gear and the house a Ninja opens cannot come apart.
--
-- An EARNED class's stock lands on each of its parent shelves. That is how a crossing's item appears on
-- both houses it is cut from -- shopping both shelves is literally how you build the thing -- and it is
-- read off the class's own `requires`, never authored per-shelf. The parents loop is harmless for a
-- root, which has none, so this needs no guard of its own.
--
-- DELIBERATELY NOT `sellsAll`. That flag is the Market answering the ware question with a shrug, and it
-- is answered before this in Vendor.sells; a classless counter carries no class, and a house gate that
-- read it would have every declaration open the one door that is not a house.
function Vendor.shelves(def, class)
    if not (def and class) then return false end
    if class == def.class then return true end
    for _, parent in ipairs(Class.parents(class)) do
        if parent == def.class then return true end
    end
    return false
end

-- Whether `def` (a vendor blueprint) stocks `item`. A class vendor sells its own class; a vendor that
-- declares `sells = false` (the Cafe, whose whole offer is the meal menu) stocks nothing at all. One
-- rule, so the shop, the sell-back and the hub's new-stock dot all agree on what a shelf holds. Takes
-- the def rather than an id so stock can call it in a loop.
function Vendor.sells(def, item)
    if not def or not item then return false end
    if def.sells == false then return false end

    -- THE MARKET SELLS EVERYTHING. One shop replaced the seven houses, so the thing that used to be a
    -- taxonomy question -- is this ware on my shelf -- is answered for it by a flag rather than by a
    -- class it does not have. What gates a ware there is its rung and its price, not its house
    -- (models/market.lua).
    if def.sellsAll then return true end

    return Vendor.shelves(def, Item.classOf(item))
end

-- WHY A WARE ON A SHELF IS SHUT -- "monster drop", "class" or "rung" -- or nil when it is out. Also hands back the
-- three facts the gate is derived from that a row wants anyway: whether the item's class is an EARNED
-- one (its `discipline`), the class level it names if any, and THE RUNG THE GATE ACTUALLY APPLIED.
--
-- `rung` is how far up this class's ladder the company has climbed (Quest.shelfRung); `unlocked` and
-- `levels` are the bare sets Vendor.stock documents. All of them optional, and a caller that knows none
-- of them gets the most generous answer -- an ungated shelf -- which is the same thing Vendor.stock has
-- always done with a nil gate.
--
-- CUT OUT OF Vendor.stock BECAUSE TWO READERS ASK IT NOW. The shelf asks it to grey a tile; the city's
-- red dot asks it to find out whether a marked ware is actually OUT (Vendor.hasMarkedStock). While they
-- answered it separately the door lit for stock the shop draws no mark on -- the shop suppresses the
-- unseen dot on a locked row, on purpose, so the mark could never be read and the plate burned forever
-- over a house the player had just finished reading. That is the same failure Market.hasUnread was cut
-- for (models/market.lua), and the rule it states is the rule here: A MARK IS ONLY EVER PUT ON
-- SOMETHING THE PLAYER CAN WALK IN AND SEE.
-- (IT TOOK AN `id` FIRST, and does not now. The id was only ever there to look the item up in the
-- `found` set; with that gate gone the parameter read nothing, and a parameter nothing reads is how a
-- caller comes to pass the wrong thing in it and never find out.)
function Vendor.lockReason(item, rung, unlocked, levels)
    if not item then return nil end
    -- TWO NUMBERS THAT USED TO BE ONE, and they still have to part -- but they part the other way round
    -- now that a found ware has a rung of its own.
    --
    --   unlockLevel  THE RANK, and it is a per-CLASS position: the grader spreads one house's stock
    --                 over the ladder, and models/balance.lua reads the result as the item's power
    --                 level. Reported to everyone downstream -- which band a row files under, how the
    --                 shelf sorts -- and it is the gate only on a ware that carries a price.
    --   gateRung      THE GATE, and it is now the same field. `unlockLevel` IS the class level, so the
    --                 gate is a read rather than a conversion.
    --
    -- THIS USED TO BE TWO FIELDS AND A BRANCH, and the branch is what the fold deleted. A priced ware
    -- named `unlockQuests` -- a grade rank carrying the name of a retired quest board -- while an
    -- unpriced one named `dropTier`, a depth counting from 1 where class levels count from 0, so the
    -- gate read `price and unlockQuests or dropTier - 1`. 231 blueprints carried BOTH and nothing on
    -- the blueprint said which governed; measured across them the two axes already agreed within a
    -- single rung four times in five (tools/ladder_fold's header carries the histogram), so they were
    -- one ladder wearing two names and an off-by-one between them. One field, one reading, and no
    -- conversion left that can fall out of step with itself.
    --
    -- Levels run 0..CLASS_LEVEL_CAP and so does this, so nothing is gated past the top of the ladder
    -- that opens it -- and rung 0 is the opening rack, held from the first morning.
    local gateRung = item.unlockLevel or 0
    -- AN EARNED CLASS'S STOCK is locked until that class is unlocked, on top of the rung gate -- and,
    -- if it names a `disciplineLevel`, until the class has grown that far.
    --
    -- `earned` is the fold's one predicate (docs/class-fold.md): a ROOT is held from the first morning
    -- and its stock is never locked by this, an earned class is the deeper cut and its stock is. It used
    -- to read `item.discipline ~= nil`, which meant the same thing while there were two fields; with
    -- one, a bare truthiness check would lock the entire catalogue behind a gate that does not exist and
    -- leave the counter with nothing to deal.
    local class = item.class
    local earned = class ~= nil and not Class.isRoot(class) and Class.defs[class] ~= nil
    local classLocked = earned and not (unlocked and unlocked[class])
    -- NAMED `disciplineLevel` SINCE THE FOLD, and the rename was forced rather than chosen: the gate
    -- above now owns the name `unlockLevel`. The two ask different questions and always did -- the rung
    -- gate is measured against the HOUSE's class (Quest.shelfRung reads the vendor's), this against the
    -- ITEM's own -- so one of them had to give the name up, and the one nothing in data/items has ever
    -- set is the one that could.
    local disciplineLevel = earned and item.disciplineLevel or nil
    if disciplineLevel and ((levels and levels[class] or 0) < disciplineLevel) then
        classLocked = true
    end
    -- THE THIRD REFUSAL IS GONE, and it is worth saying what it was. A found ware used to be shut until
    -- the company had CARRIED ONE OUT -- `lockReason = "undiscovered"`, a named silhouette with the
    -- depth it falls at where its price would go -- on the argument that a house should be a record of
    -- what you have brought it rather than a catalogue. What that cost is the thing the same doc names
    -- as the shelf's standing obligation: a shelf GUARANTEES an item is reachable and a drop table does
    -- not. 157 wares reached the player through the price band's long tail alone and 21 sat past the end
    -- of a boss queue, so a player who wanted the Lodge's kit had nowhere to go and get it.
    --
    -- So the rift is the HEAD START rather than the only door: it pays the same gear at the same depths,
    -- free and long before the rung, and the class ladder is the backstop that guarantees it. What stays
    -- rift-only is a small authored set -- what a body is KNOWN for -- and that is `unstocked`, answered
    -- at Vendor.foundPrice, which takes those off every counter entirely rather than greying them
    -- (docs/drops.md). A permanent silhouette is a want list; this shelf's want list is the bestiary.
    --
    -- WHY THE LOCK STILL NEEDS A REASON AND NOT JUST A FLAG. Two ways a tile can be shut -- the rung and
    -- the discipline -- and a rack that greys both identically tells the player "no" twice without ever
    -- saying which of two different things to go and do about it. Decided here, once, for the same
    -- reason `discipline` is: the readers all want the same answer and none should be re-deriving it.
    -- A MONSTER'S OWN DROP IS SHUT FOREVER, and it leads because it is the only refusal here that
    -- nothing the player does will ever answer. The other two name something to go and do -- grow the
    -- class, unlock the path -- and this one names where the thing comes from instead, because that IS
    -- the answer: go and kill the body that carries it (docs/drops.md).
    --
    -- IT IS ON THE RACK RATHER THAN ABSENT FROM IT, which is the change. `unstocked` used to answer nil
    -- at Vendor.foundPrice, and a ware with no price never entered Vendor.stock at all -- so the rarest
    -- pieces in the game were invisible at every counter and a player had no way to learn they existed
    -- short of meeting the creature. A shelf that shows them and refuses them is a want list again,
    -- which is the job the discovery gate used to do and did badly: this one is permanent and honest
    -- rather than a lock that opens once you have already got one.
    --
    -- THE PRICE STAYS NIL EITHER WAY, and that is not an oversight -- Vendor.foundPrice is unchanged, so
    -- Vendor.sellValue still answers 0 and the piece has no market price in EITHER direction. There is
    -- nobody to buy one from and nobody who would know what to pay. Visible is not the same as
    -- merchandise.
    -- `dropOnly` IS THE SECOND WAY A PIECE COMES OFF A BODY AND ONLY OFF A BODY, and the pair of them
    -- say two different things that were easy to confuse until both existed:
    --
    --   unstocked   there is no MARKET for this. Vendor.foundPrice answers nil, so Vendor.sellValue
    --               answers 0 as well: no counter deals one and no counter buys one back. A boar's hide
    --               is worth nothing to anybody in the city because nobody there knows what it is.
    --   dropOnly    the city does not STOCK it, but yours is worth something. It carries no `price`
    --               either -- it does not need one, and the shelf recut's law is that only abilities,
    --               consumables and a house's opening weapon do. Vendor.foundPrice derives its worth
    --               from its `unlockLevel` exactly as it does for every other found ware, so it sells back
    --               at the usual half. What the flag changes is one thing only: no counter will ever
    --               deal you one.
    --
    -- The Mere's kit is the second (docs/nagas.md): no smith in the city works in scale and silt, and a
    -- naga's spear is still a spear that a fence will take off your hands. Making it `unstocked`
    -- instead would have meant widening a rule argued for twenty-odd beast trophies -- and pinned by
    -- tests/discovery_spec.lua, which asserts a trophy sells for exactly 0 -- to fit seven items that
    -- want the opposite half of it.
    --
    -- Both lead, and both produce the SAME refusal on the rack, which is correct: the player's question
    -- at a counter is "can I buy this", the answer is no for the same reason in both cases, and the
    -- reason names somewhere to go -- kill the thing that carries it. The difference between them is
    -- felt at the sell desk, not here.
    local lockReason = nil
    if item.unstocked or item.dropOnly then lockReason = "monster drop"
    elseif classLocked then lockReason = "class"
    elseif (rung or 0) < gateRung then lockReason = "rung" end
    return lockReason, earned, disciplineLevel, gateRung
end

-- Every item this vendor could ever sell, in shelf order (cheapest first). Quest-gated items are
-- included; `locked` marks the ones the player has not earned yet, so the shop can show them greyed
-- out -- seeing what the rest of the line unlocks is the point of the ladder.
--
-- `questsDone` is the RUNG of this shelf the player has reached (Quest.shelfRung), which is a CLASS
-- LEVEL -- how far the roster's best holder has got in the class this counter sells. An item is locked
-- until that rung reaches its own, and a row reports the rung it was measured against as `rung`: a
-- every ware's is its `unlockLevel`, priced or found alike since the fold (Vendor.lockReason). Passed
-- as a bare number (not a player) so this module stays player-free.
--
-- `recipes` is an optional plain { itemId = tier } map (the player's consumable recipe levels):
-- a listed item is stocked at its tier, with `price` scaled to match, so buying it yields the
-- upgraded item.
--
-- Returns fresh tables, never the blueprints (which stay immutable).
-- `unlocked` is an optional bare set { classId = true } of the player's unlocked disciplines
-- (Class.unlockedSet). A discipline item is stocked either way but stays `locked` -- greyed like a
-- quest-locked ware -- until its discipline is unlocked, because seeing the deeper cut you can earn is
-- the point, same as the quest ladder.
--
-- `levels` is the matching bare map { classId = level } (Class.levelSet). The broad shelf
-- gates on QUEST COUNT; the deepest cut of a discipline gates on how far that discipline has actually
-- GROWN, via an optional `disciplineLevel` on the item (default 0: nothing gates until authored).
-- Two different questions -- "have you worked with this house" and "have you specialized" -- and the
-- shelf should not answer both with the same number.
-- `questsDone` may also be a FUNCTION of the item, returning the rung that item's own ladder has
-- reached. One shelf per house could take a single number because a house sold one class; the market
-- sells all seven (models/market.lua), and there each ware is gated on the level of ITS OWN class. A
-- bare number still works and means what it always meant, so every existing caller is untouched.
-- WHAT A FOUND WARE COSTS. Above the opener rung nothing is authored with a price any more
-- (tools/drop_tier.lua's recut): a weapon, a utility or a piece of armor carries no price at all.
-- So the price has to be DERIVED, and the material is already there -- a unlockLevel is the item's grade
-- rank, the same rank a slot is, spread along depth rather than along a shelf (docs/shelf.md). Read it
-- as the slot it would have had.
--
-- AND THE GATE READS THE SAME FIELD, which is the half that arrived later: Vendor.lockReason takes
-- `unlockLevel - 1` as the rung a found ware sits on, exactly as this takes it as the slot it prices at.
-- One number, two questions, no way for the price and the gate to drift apart.
--
-- OFF BY ONE ON PURPOSE: tiers run 1..cap and slots run 0..cap-1, so tier 1 prices at Grade.PRICE_BASE,
-- level with a house's opener. A found thing from the top of the rift and a bought thing from the
-- bottom of a ladder are worth the same, which is the one place these two axes have to agree.
-- Required INSIDE rather than at the top of the file. Two reasons and both matter: Grade pulls Combat in behind it, which is the heaviest module in the
-- game to hang off a table every quest and shop already loads -- and a new top-level require reorders
-- `pairs` over the registry, which is enough on its own to redden a spec that has nothing to do with
-- this change.
-- `unstocked` IS THE ONE THING A FOUND WARE CAN SAY THAT KEEPS IT OFF A COUNTER FOREVER, and it is the
-- whole of the exception now that the shelf deals the rest of the catalogue on the rung.
--
-- A found ware reaches a counter when the class it belongs to has grown that far, which is right for
-- the catalogue: a shelf has to guarantee its stock is reachable. But it leaves no way to author a piece
-- that is *only* ever taken off a body -- the boar's hide, the sow's pelt, the relic a general is put
-- down for (docs/drops.md). Without this flag the rarest thing in the game is something you eventually
-- shop for, which is the whole of what makes it rare undone by a counter.
--
-- IT IS NOT `bound`. Bound means nailed to one grid -- never earned, moved or carried, which is what
-- keeps a boss's phase machinery out of the player's hands. An unstocked piece is yours: take it, keep
-- it, move it between your own bodies, forge it, break it down (models/salvage.lua). What it is not is
-- MERCHANDISE.
--
-- Answered here, at the price, rather than at Vendor.sells -- because a thing with no price is a thing
-- no counter can quote, and every caller that wants to know "would a shop deal this" already comes
-- through this function.
--
-- WHICH ALSO MEANS IT CANNOT BE SOLD, because Vendor.sellValue reads this same figure -- and that is the
-- better rule rather than a side effect worth patching around. A piece that exists only where it fell
-- has no market price in either direction: there is nobody to buy one from and nobody who would know
-- what to pay for one. The company's options are to use it or to break it, which is exactly the shape a
-- thing this rare should have.
function Vendor.foundPrice(item)
    if not (item and item.unlockLevel) then return nil end
    if item.unstocked then return nil end
    return require("models.grade").priceFor(item.unlockLevel, item.type)
end

-- THE ORDER A SHELF DEALS IN, and it leads with what the player can actually take home. Every rack in
-- the city comes through here -- a house's shelf below, the town counter (models/market.lua), and the
-- bands the shop cuts out of either (ui/panels/shop.lua) -- so a counter's default order is one order,
-- learned once, at every door.
--
-- WHAT IS BUYABLE, THEN WHAT IS NOT. The ladder used to deal strictly by rank, which on a band running
-- sixty-four rows deep with seven of them open -- the rail prints exactly that, `7 / 64` -- scattered
-- those seven through fifty-seven tiles that refuse the press, so the one question a counter is opened
-- with, WHAT CAN I BUY, was answered by reading the whole rack. The locked rows are neither dropped nor
-- hidden: what the rift holds is the other half of what a shelf is for now, and they gather under the
-- stock rather than running through it.
--
-- WITHIN EACH HALF NOTHING CHANGED -- rank, then price, then name -- so the ladder still reads
-- top-to-bottom, once through what is open and once through what is not. `locked` is the only key read
-- and the purse is never one: a rack that re-dealt itself every time the company's gold crossed a price
-- would rearrange under the hand mid-purchase, and a tile already prices itself against the purse in
-- its own colour (ui/pool_grid.lua).
--
-- THE RANK IT DEALS BY IS `rung`, the figure the gate was actually measured against. Since the fold it
-- equals the authored `unlockLevel` on everything the ladder ranks, and the two are kept apart only so
-- a row built without going through Vendor.lockReason still sorts somewhere sane.
-- `rung` is what the gate was measured against and `unlockLevel` is what the blueprint authored; since
-- the fold those are the same number on everything the ladder ranks, and the fallback is here for a row
-- assembled by a caller that did not come through Vendor.lockReason.
function Vendor.shelfOrder(a, b)
    local la, lb = a.locked or false, b.locked or false
    if la ~= lb then return lb end
    local ra, rb = a.rung or a.unlockLevel or 0, b.rung or b.unlockLevel or 0
    if ra ~= rb then return ra < rb end
    if a.price ~= b.price then return (a.price or 0) < (b.price or 0) end
    return (a.name or "") < (b.name or "")
end

function Vendor.stock(vendorId, questsDone, recipes, unlocked, levels)
    local def = Vendor.defs[vendorId]
    if not def then return {} end
    local rungOf = questsDone
    if type(rungOf) ~= "function" then
        local fixed = questsDone or 0
        rungOf = function() return fixed end
    end

    local stock = {}
    for id, item in pairs(Item.defs) do
        local foundPrice = not item.price and Vendor.foundPrice(item) or nil
        -- A MONSTER'S DROP HAS NO PRICE AND IS STOCKED ANYWAY (see Vendor.lockReason). Admitted on its
        -- `unlockLevel` rather than on a price, because the price is exactly what it does not have --
        -- and the rung is what places it on the ladder so it sorts into the rack where it belongs
        -- rather than piling at one end.
        local trophy = item.unstocked and item.unlockLevel ~= nil
        if (item.price or foundPrice or trophy) and Vendor.sells(def, item) then
            -- THE RUNG THE BLUEPRINT AUTHORED. Reported to everyone downstream: which band a row
            -- files under, how the shelf sorts, whether the Market counts it a staple
            -- (models/market.lua). Since the fold it is the gate as well, so `rung` below agrees with
            -- it on everything the ladder ranks; the two are still reported apart because a row can be
            -- built for something that carries no rung at all.
            local unlockLevel = item.unlockLevel or 0
            local level = (recipes and recipes[id]) or 0
            local class = item.class
            local lockReason, earned, disciplineLevel, rung =
                Vendor.lockReason(item, rungOf(item), unlocked, levels)

            stock[#stock + 1] = {
                id = id,
                name = item.name,
                description = item.description,
                flavor = item.flavor,
                type = item.type,
                level = level,
                price = Vendor.priceFor(item.price or foundPrice, level),
                -- WHERE THE RIFT GIVES IT UP IS THE SAME NUMBER, which is the whole of what the fold
                -- bought: one rung says both "grow the class this far and buy one" and "go down to
                -- this floor and take one", so the shut tile can name both roads with no second field
                -- to drift off the first (ui/panels/shop.lua's lockReason).
                unlockLevel = unlockLevel,
                -- THE RUNG THE GATE WAS ACTUALLY MEASURED AGAINST. The same figure as above on
                -- anything the ladder ranks; kept distinct because it is what Vendor.lockReason
                -- actually compared, and a reader asking "how far must the class grow" wants the
                -- answer the gate gave rather than the field it read.
                rung = rung,
                class = class,
                -- The row's own name for "this is a deeper cut, not the open rack": the class when it
                -- is an earned one, nil when it is a root. Downstream this is what bands a shelf into
                -- sections and what a lock reason points at, and both of those want the earned half
                -- only -- so the check is made once, here, rather than at each reader.
                discipline = earned and class or nil,
                unlockLevel = unlockLevel,
                locked = lockReason ~= nil,
                lockReason = lockReason,
            }
        end
    end

    table.sort(stock, Vendor.shelfOrder)
    return stock
end

-- Whether any of the item ids in `marked` (a bare set, i.e. player.newStock) is OUT on this vendor's
-- shelf. What the hub city's red dot on a shop reads: the reward panel names the wares once, and
-- without a mark on the door itself the player has to remember which house it said. Takes bare sets
-- rather than a player so this module stays player-free, like everything else here.
--
-- A ware that two shelves carry (a potion, resold at the Cafe) dots both doors, which is simply true:
-- it is new on both.
--
-- `gates` IS WHAT MAKES THE ANSWER THE SAME ANSWER THE SHOP GIVES -- { rung, unlocked, levels, found },
-- the four figures Vendor.stock gates a rack with (Quest.shelfGates assembles them). Without it this
-- asked only whether the house SELLS the ware, and the shop suppresses the unseen dot on a locked row
-- on purpose -- so a mark on a ware the company has found but cannot yet buy lit the plate with nothing
-- behind the door that could clear it. Reading the whole shelf left it burning, because the one row it
-- was about draws no mark. That is the failure Market.hasUnread was cut for, and the rule it states is
-- the rule here: A MARK IS ONLY EVER PUT ON SOMETHING THE PLAYER CAN WALK IN AND SEE.
--
-- The mark is not thrown away by being refused, and that is the point of gating the READ rather than
-- the write: a ware marked two rungs above the company's standing is laid down at the moment the mark
-- is made and lights this door on the day the ladder reaches it -- which is the only announcement a
-- shelf opened by a class level ever gets. What does the marking is a rack that genuinely opened: a
-- companion joining (Market.markOpened) or a shelf diff (models/quest.lua). A DISCOVERY IS NOT ONE OF
-- THEM any more -- carrying a thing out of the rift opens no line now that the rung is the whole gate
-- (Vendor.lockReason), so Player.markFound stamps the ledger and lights nothing.
--
-- A nil `gates` keeps the old ungated answer, for a caller that has no player to ask.
function Vendor.hasMarkedStock(vendorId, marked, gates)
    local def = Vendor.defs[vendorId]
    if not (def and marked) then return false end
    for id in pairs(marked) do
        local item = Item.defs[id]
        -- `price or foundPrice`, because a shelf's stock arrives two ways. Reading `price` alone would
        -- have left the city silent about the one thing the company just went down and got: a discovery
        -- opens a line permanently, and the walk back from the Rift should point at the door it opened
        -- rather than ask the player to re-read seven shelves. Asked through Vendor.foundPrice rather
        -- than off `unlockLevel` so it is the SAME membership test Vendor.stock deals a rack by -- which
        -- is also what keeps a rift-only piece off this plate, since `unstocked` is a thing a ware says
        -- to the price and nothing else ever sees it.
        local stocked = item and (item.price or Vendor.foundPrice(item))
        if stocked and Vendor.sells(def, item)
            and not (gates and Vendor.lockReason(item, gates.rung, gates.unlocked,
                gates.levels)) then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Services: what a house does besides sell
-- ---------------------------------------------------------------------------
--
-- A shelf is the same verb at every door. Seven houses that all Buy and Sell means the city has two
-- verbs in it however many buildings get built, which is the whole of why the town stops changing once
-- the last door opens -- a new shop is only ever more rows. So a vendor may declare a SERVICE: one
-- thing only that house does, named on its own tab beside Buy and Sell.
--
-- One is authored (the Undercroft's Fence, below). The seam is what matters: a service is a data
-- field, so the other six are an authoring job rather than an engine one, and each house's
-- specialisation can be argued about in its own blueprint. Sketches, deliberately unbuilt --
-- the Crucible appraising a sealed find, the Arcanum reading an unknown discipline off a piece, the
-- Cafe standing a round -- are notes for that pass and not promises.
--
-- WHY THE UNDERCROFT GOT THE FIRST ONE. Greed's house, and the swap is greed's verb: nothing is
-- created, nothing is destroyed, and the fence takes a cut of the difference. It is also the service
-- an extraction game most obviously needs -- a run that pays out in gear produces duplicates by
-- construction, and until now the only thing to do with a second Iron Sword was sell it for half.

-- What the fence charges to turn one piece into another, as a share of the shelf price of the thing
-- handed over. Deliberately above the 50% a plain sell-back pays, because a swap is strictly better
-- than selling: it returns an ITEM rather than coin, at the grade you gave up, with no second trip to
-- the shelf and no waiting for a gate to open. Under 50% and selling would be strictly dominated,
-- which would make the Sell tab decorative at the one house that has both.
Vendor.SWAP_FEE = 0.6

-- The gold a swap costs, given the item being handed in. Rounded up, so no swap is ever free -- a
-- worthless trinket still costs a coin to launder, which is the fence's whole personality.
function Vendor.swapFee(item)
    if not item or not item.price then return nil end
    return math.max(1, math.ceil(Vendor.priceFor(item.price, item.level or 0) * Vendor.SWAP_FEE))
end

-- How far apart two prices may sit and still count as the same grade. A band rather than an exact
-- match because prices are derived from grade (docs/shelf.md) and land on arbitrary numbers: an exact
-- rule would make most items unswappable and the ones that were swappable a lookup table.
Vendor.SWAP_BAND = 0.35

-- What `vendorId` will hand over in exchange for `item`: every ware on its shelf of about the same
-- worth, minus the thing being traded in. The caller picks from the list, so the swap is a CHOICE and
-- not a roll -- a random return would make this a slot machine, and the player already has a slot
-- machine on the board in the shape of loot.
--
-- Locked stock is excluded outright, unlike the Buy list which shows it greyed: a shelf shows what you
-- are working toward, but a service that dangles a reward the fence cannot actually hand over is just
-- a worse error message. Takes the same bare `questsDone` / `recipes` / `unlocked` / `levels` the stock
-- call does, for the same player-free reason.
function Vendor.swapOffers(vendorId, item, questsDone, recipes, unlocked, levels)
    local def = Vendor.defs[vendorId]
    if not (def and def.service and def.service.id == "fence") then return {} end
    local worth = item and item.price and Vendor.priceFor(item.price, item.level or 0)
    if not worth or Item.isBound(item) then return {} end

    local lo, hi = worth * (1 - Vendor.SWAP_BAND), worth * (1 + Vendor.SWAP_BAND)
    local out = {}
    for _, entry in ipairs(Vendor.stock(vendorId, questsDone, recipes, unlocked, levels)) do
        if not entry.locked and entry.id ~= item.id
            and entry.price and entry.price >= lo and entry.price <= hi then
            out[#out + 1] = entry
        end
    end
    return out
end

-- What a vendor pays to buy `item` back: half its shelf price at the item's own level, rounded down --
-- so a refined consumable sells for more than a base one, matching what it cost. An item with no
-- `price` was never for sale and so can't be sold (returns 0) -- the Party screen refuses those
-- rather than giving them away for nothing. One place so the panel and its test agree on the rate.
function Vendor.sellValue(item)
    -- A FOUND WARE SELLS TOO, at the price its unlockLevel implies (Vendor.foundPrice). Reading `price`
    -- alone here would have made every weapon, utility and piece of armor above the opener rung worth
    -- nothing at a counter the moment the recut took their prices off -- a company that hauled out a
    -- duplicate would be carrying a thing it could neither use twice nor sell.
    local base = item and (item.price or Vendor.foundPrice(item))
    if not base then return 0 end
    if Item.isBound(item) then return 0 end -- a bound relic is never for sale, whatever price it carries
    -- EVERYTHING TAKES THE HAIRCUT NOW. There was one exception -- a valuable paid its full price,
    -- because its `price` was what a counter owed for it rather than what a shop charged -- and the
    -- valuables are deleted (models/spoils.lua's END_PURSE): an end pays coin, so nothing in the game
    -- is priced from the counter's side of the desk any more.
    return math.floor(Vendor.priceFor(base, item.level or 0) * 0.5)
end

return Vendor
