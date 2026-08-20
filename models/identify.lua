-- IDENTIFICATION: gear the rift hands up unread, and the counter in the city that reads it.
--
-- A descent's gear comes off its FLOORS -- the Gate's shelf is draughts and a spare blade, and always
-- was (models/gate.lua). That put every piece of gear inside one price band: what a fight can pay is
-- capped by `bandPrice`, so a floor can never hand over anything dearer than the road it stands on.
-- IDENTIFICATION IS HOW THE RIFT PAYS ABOVE THAT BAND. An unread piece is drawn richer than the band
-- allows, or off a body carrying something better than the band would ever have rolled, and the fee is
-- what turns that luck into gear.
--
-- Wizardry's Boltac, and the lineage is not decoration: models/gate.lua opens by arguing that the Gate
-- IS Wizardry's castle -- a stair with a lamp over it at the edge of a town that holds the counters.
-- This is one of those counters. The one it is missing.
--
-- WHAT IS HIDDEN IS THE FORGE LEVEL, and the alternative was considered at length and rejected. Rolling
-- BONUS STATS onto a found piece -- Diablo's affixes -- fails three ways here:
--
--   price is derived     grade -> slot -> price (docs/shelf.md, models/grade.lua). An item whose power
--                        was rolled has a `price` that is a lie, and Vendor.sellValue (half of price)
--                        pays the wrong number for it forever after.
--   balance is one unit  a blow and a coat are one subtractive quantity, measured through
--                        Combat.mitigatedDamage (docs/balance.md). Unbudgeted power injects straight
--                        into the single figure the whole curve is tuned on.
--   items are verbs      an instance here carries `aura`, `trail`, `charge`, `waitBehavior`, `traits`,
--                        `terrainEase`. A rolled +2 power is the least readable thing one of them could
--                        gain, and it competes with nothing already on the object.
--
-- The forge level has none of those problems because the game already owns it: every magnitude resolves
-- per level off an authored curve (models/curve.lua), the " +n" rides on the name (Item.instantiate),
-- and a save already carries it. A found +3 axe is a fully-tuned object with no new balance surface.
--
-- THE DELAY IS THE POINT. An unread piece cannot be equipped, so it is dead weight until the company
-- climbs out -- and the way up is a fixture on every floor (models/descent.lua). A satchel of unread
-- blades is therefore weight on the extraction decision, which is exactly the decision Descent.account
-- says the descent needed to make heavier.
--
-- Pure model -- no love.graphics, no state switching -- so it loads under the headless runner. RNG falls
-- back to math.random when love.math is absent, so the roll is exercisable outside a window.

local Item = require("models.item")
local Player = require("models.player")
local Sprite = require("models.sprite")

local Identify = {}

-- love.math.random under LÖVE, else math.random. Same call signatures. One helper, so the module is
-- engine-agnostic -- the same shape models/spoils.lua and models/relic.lua keep.
local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- ---------------------------------------------------------------------------
-- What can be sealed
-- ---------------------------------------------------------------------------

-- The types that can turn up unread, and the label each one wears while it is.
--
-- CONSUMABLES ARE ABSENT AND THAT IS THE WHOLE ARGUMENT FOR THE LIST. A stack merges by id
-- (Item.bagPut), and two unread potions have no id to merge on without giving away that they are the
-- same potion. Excluding them sidesteps the problem instead of solving it, and costs nothing: the
-- everyday restock is what the band already pays out in the clear, and a mystery draught is a worse
-- prize than a mystery blade in any case.
--
-- ABILITIES ARE PRESENT, and the label reads better than it sounds. They are a large share of the
-- shelf, they are not stackable, and "Ability" is already a word the player reads -- the Armory's own
-- filter strip prints one chip per item type, titlecased, so `Unidentified Ability` names a category
-- the player has been sorting by since the first stash screen.
Identify.LABELS = {
    weapon  = "Unidentified Weapon",
    armor   = "Unidentified Armor",
    utility = "Unidentified Utility",
    ability = "Unidentified Ability",
}

-- The husk's icon, per type. Missing art resolves to its own path through models/sprite.lua rather than
-- crashing, so these are wired now and start drawing the moment the files land (docs/art-assets.md).
local SPRITES = {
    weapon  = "assets/items/unidentified_weapon.png",
    armor   = "assets/items/unidentified_armor.png",
    utility = "assets/items/unidentified_utility.png",
    ability = "assets/items/unidentified_ability.png",
}

-- ONE LINE, ON EVERY HUSK, SAYING WHAT TO DO ABOUT IT. Not flavor: the husk has no description of its
-- own to show (it has no idea what it is), and a card with a blank where the sentence goes reads as a
-- bug rather than as a mystery.
Identify.BLURB = "Unidentified. The Touchstone will name it, for a fee."

-- Can a piece of this blueprint ever turn up unread? Type is the whole gate, plus the two markers that
-- mean "this was never really an object on a shelf":
--
--   bound      a signature relic belongs to its bearer and is never moved, stowed or sold
--              (models/voucher.lua's BONDS). Sealing one would offer to sell somebody's identity.
--   no price   the "shoppable" marker. A natural weapon has none, and a wolf's fangs are not a find.
function Identify.canSeal(defOrItem)
    local def = defOrItem
    if type(def) == "string" then def = Item.defs[def] end
    if not (def and def.type) then return false end
    if def.bound then return false end
    if not (def.price and def.price > 0) then return false end
    return Identify.LABELS[def.type] ~= nil
end

-- Is this instance still unread? The one predicate every caller asks -- panels, the tooltip, the
-- Armory's filter strip and the grid's refusal all read through here rather than testing the field.
function Identify.isUnidentified(item)
    return type(item) == "table" and (item.unidentified or 0) > 0
end

-- The floor a piece was found on, or 1. See `unidentified` in Identify.sealed for why the field carries
-- a number rather than a boolean.
function Identify.floorOf(item)
    return math.max(1, math.floor(tonumber(item and item.unidentified) or 1))
end

-- ---------------------------------------------------------------------------
-- The roll
-- ---------------------------------------------------------------------------

-- A FLOOR OF ONE. Every read lands at least a rung above base, so the fee always buys something and the
-- gamble is HOW FAR rather than WHETHER. A dud outcome would make the counter a slot machine that
-- sometimes charges you for nothing, and there is no version of that which is fun to walk to.
Identify.MIN_LEVEL = 1

-- ...and the chance of climbing one more rung, rolled again at each rung until it fails. A coin flip
-- that mostly does not come off, which gives the fat floor and long tail a reveal wants: on a cap of
-- five that reads +1 at 55%, +2 at 25%, +3 at 11%, and the rest out in the tail worth watching for.
--
-- Deliberately generous rather than punishing. The hall's own pull is tuned toward "another one
-- already?" and never toward "finally" (models/voucher.lua), and nothing here is sold for money either,
-- so none of the genre's scarcity machinery is load-bearing.
Identify.CLIMB = 0.45

-- How high a piece found on `floor` may read. Climbs with depth, because depth is the only thing the
-- player spends to change it -- going one circle deeper is one better ceiling, which is the descent's
-- own question restated in gear.
--
-- Half a rung per floor, so the fifteenth floor tops out near the item ceiling without ever passing it.
function Identify.capFor(floor)
    floor = math.max(1, math.floor(tonumber(floor) or 1))
    return math.max(Identify.MIN_LEVEL, math.min(Item.MAX_LEVEL, 1 + math.ceil(floor / 2)))
end

-- The level a piece found on `floor` reads at, rolled once at DROP time and stored in the instance's
-- ordinary `level` field until somebody pays to look at it.
--
-- ROLLED AT THE DROP, NOT AT THE REVEAL, and this is the same rule ui/panels/hire_reveal.lua states
-- about the crossing: a reveal that rolls at the END of its own animation is a reveal a player can
-- close and reopen to reroll. What the panel does is withhold a fact it already holds.
function Identify.rollLevel(floor)
    local cap = Identify.capFor(floor)
    local level = Identify.MIN_LEVEL
    while level < cap and rnd() < Identify.CLIMB do level = level + 1 end
    return level
end

-- Did this piece climb its whole ladder? The reveal's rarest beat -- the glass breaks and the light goes
-- with it (ui/panels/identify_reveal.lua).
--
-- BOTH HALVES ARE LOAD-BEARING. `level == cap` is the climb; `cap >= 4` is what stops a shallow floor
-- from handing out the moment for free. Floor one caps at two, so hitting the cap there is a coin flip
-- and would spend the rarest animation in the game on the least interesting outcome it has. Six floors
-- down, hitting a cap of four is one read in eleven; at the bottom it is one in several hundred.
function Identify.isOvershoot(level, floor)
    local cap = Identify.capFor(floor)
    return cap >= 4 and (level or 0) >= cap
end

-- ---------------------------------------------------------------------------
-- The husk
-- ---------------------------------------------------------------------------

-- A sealed instance, built for `id` as found on `floor`.
--
-- BUILT FROM NOTHING RATHER THAN STRIPPED DOWN, and that direction is the whole leak defence. Sealing by
-- clearing fields off a real instance is a whitelist maintained by hand in the wrong direction: the day
-- somebody adds a field to Item.instantiate -- and that constructor already copies thirty-odd -- the new
-- one leaks through every husk in the game and nothing says so. A husk that was never anything else
-- cannot leak a field it never had.
--
-- What survives is exactly what the player is allowed to know: the TYPE (which is what the card says),
-- and the machinery that makes it a stash row at all.
--
--   id             kept, because the read has to rebuild the true item and the save has to survive.
--                  Never drawn, never compared, never grouped on while `unidentified` is set.
--   level          the rolled answer, sitting in the field it will still be sitting in afterwards.
--   unidentified   THE FLOOR IT WAS FOUND ON, not a boolean. Truthy either way, and carrying the number
--                  means the fee, the sell price and the reveal's ceiling all read one field instead of
--                  three. Same trick models/voucher.lua plays: the floor IS the grade, internally, and
--                  the player is shown a consequence of it rather than the number.
--
-- Note what is absent and what that buys for free: no `tags`, so Item.archetype answers nil and the
-- Armory's weapon-family chips cannot name the blade; no `discipline`, so its house chip cannot either;
-- no `price`, so Vendor.sellValue refuses to quote it and the Touchstone's own number is the only one
-- anybody can see; no `traits`, `aura` or `activeAbility`, so there is nothing for a tooltip to spill.
function Identify.sealed(id, floor, level)
    local def = Item.defs[id]
    if not (def and Identify.canSeal(def)) then return nil end
    floor = math.max(1, math.floor(tonumber(floor) or 1))
    return {
        id = id,
        type = def.type,
        name = Identify.LABELS[def.type],
        description = Identify.BLURB,
        sprite = Sprite.load(SPRITES[def.type]),
        quantity = 1,
        level = level or Identify.rollLevel(floor),
        unidentified = floor,
    }
end

-- ---------------------------------------------------------------------------
-- The bill
-- ---------------------------------------------------------------------------

-- What a read costs, and it reads the FLOOR rather than the item.
--
-- THAT IS NOT A SIMPLIFICATION, IT IS THE ONLY PRICE THAT WORKS. A fee derived from what the piece is
-- actually worth -- the obvious first cut, and the one every other bill in this game uses -- prints the
-- answer on the price tag: a player who sees one husk quoted at ninety and another at four hundred has
-- identified both without paying for either. The bill may only ever read facts the player already has,
-- and the floor is the one fact the husk is allowed to carry.
Identify.FEE_BASE = 60
Identify.FEE_PER_FLOOR = 20

-- ONE NUMBER, TWO DIRECTIONS: what the counter charges to name a piece is also what it PAYS to take the
-- piece off you unnamed. The symmetry makes selling and naming come out roughly even in gold, which puts
-- the choice where it belongs -- SELL WHEN YOU ARE BROKE, NAME IT WHEN YOU WANT THE THING. Without the
-- alternative the fee is a toll: a click standing between a drop and the item, charged for nothing but
-- the delay.
--
-- BUYING IT BACK COSTS MORE THAN SHE PAID (Identify.BUYBACK_MARKUP), and that premium is what makes the
-- sale a decision rather than a deposit. At par the counter is a locker: sell the satchel on the way in,
-- take the gold, redeem whatever you still want later, and the question the room exists to ask -- name
-- this one, or let it go -- is never actually asked, because letting it go costs nothing. The markup is
-- the price of having been wrong, and it is small enough to pay when you were.
function Identify.fee(item)
    return Identify.FEE_BASE + Identify.FEE_PER_FLOOR * Identify.floorOf(item)
end

-- ---------------------------------------------------------------------------
-- The counter
-- ---------------------------------------------------------------------------

-- Every unread piece in the stash, in the order it was found. What ui/panels/touchstone.lua lists.
function Identify.pending(player)
    local out = {}
    for _, item in ipairs((player and player.stash) or {}) do
        if Identify.isUnidentified(item) then out[#out + 1] = item end
    end
    return out
end

function Identify.count(player)
    return #Identify.pending(player)
end

-- Read `item`, spending the fee. Returns true on success, or false plus a reason.
--
-- THE LIVE TABLE IS RE-STAMPED, NEVER REPLACED. The obvious implementation -- build the true instance
-- and swap it into the stash slot -- hands every view a different table than the one it was drawing a
-- moment ago, and a view that keys anything by table identity (a hover, a selection, a reveal's
-- animation state) silently loses track of the row mid-frame. So the husk is emptied and refilled in
-- place: same table, same address, new contents. Same rule the rest of the codebase follows about
-- refreshing derived state.
--
-- Everything is rebuilt from the blueprint at the stored level, which is exactly what the Forge does
-- when it raises a rung (models/forge.lua) -- so a read item is indistinguishable from one bought at
-- that level and hammered up to it, because it IS one.
function Identify.read(player, item)
    if not Identify.isUnidentified(item) then return false, "nothing to read" end
    local fee = Identify.fee(item)

    -- Built BEFORE the gold moves. Item.instantiate raises on an id that is no longer in data/ -- a
    -- stale save naming a deleted blueprint -- and a fee charged for a piece that then failed to
    -- materialise would be gold taken for nothing.
    local revealed = Item.instantiate(item.id, 1, item.level)
    if not Player.spendGold(player, fee) then return false, "not enough gold" end

    for k in pairs(item) do item[k] = nil end
    for k, v in pairs(revealed) do item[k] = v end
    item.unidentified = nil

    -- The stash's unseen dot is keyed by item id, and until this moment the id was a secret the player
    -- was not being shown. Marking it here is what puts the red dot on the thing they just learned they
    -- own, in the Armory, where they are about to go looking for it.
    Player.markNew(player, Player.NEW_STASH, item.id)
    return true
end

-- ---------------------------------------------------------------------------
-- The shelf: what the counter is holding for you
-- ---------------------------------------------------------------------------

-- WHAT IT COSTS TO CHANGE YOUR MIND, as a multiple of what the sale paid. Half again: sell a floor-13
-- piece for 320 and it is 480 to have it back, so the round trip costs 160 and the arithmetic is one a
-- player can do in their head at the counter.
--
-- Deliberately a premium rather than a penalty. It has to be big enough that selling is a real decision
-- -- at par the counter is a free locker (see Identify.fee) -- and small enough that a company which sold
-- gear to pay for a night at the Inn can afford to undo that once it has been paid. A doubling would
-- make the first sale unrecoverable in practice, which is the same as having no buy-back at all.
Identify.BUYBACK_MARKUP = 1.5

-- HOW MANY SOLD PIECES THE COUNTER KEEPS. The oldest falls off when a sale pushes past this, and what
-- falls off is gone.
--
-- A SECOND LIMIT BEHIND THE PRICE, not the main one -- the markup above is what makes selling cost
-- something. This is what stops the shelf becoming an unbounded second stash: a pawnbroker holds what
-- she has room for, the save carries it, and the panel has to draw it.
--
-- Six, which is one more than the counter shows at once (ui/panels/touchstone.lua's MAX_ROWS). A shelf
-- shorter than the list would drop pieces the player could still see; a much longer one stops being a
-- thing anybody has to think about. The panel always draws what is on it, so what is about to fall off
-- is visible before the sale that pushes it.
Identify.SHELF_MAX = 6

-- What the counter is holding, oldest first. Created lazily -- an empty shelf is the absence of one.
function Identify.shelf(player)
    return (player and player.touchstoneShelf) or {}
end

function Identify.shelfCount(player)
    return #Identify.shelf(player)
end

-- Sell `item` unnamed. Returns the gold paid and, when the shelf overflowed, the piece that fell off it.
--
-- Removed from the stash by IDENTITY rather than by id, because id is precisely the thing that is not yet
-- knowable here -- two husks of the same blueprint are two different finds and only one of them is being
-- sold. The husk table itself moves onto the shelf rather than being rebuilt, so a piece that goes and
-- comes back is the same object it was, level and floor intact.
--
-- The eviction is RETURNED rather than swallowed. A shelf that silently drops the oldest piece is a shelf
-- that steals, and the panel has to be able to say which one went.
function Identify.sell(player, item)
    if not Identify.isUnidentified(item) then return nil, "nothing to sell" end
    local stash = (player and player.stash) or {}
    local at
    for i, held in ipairs(stash) do
        if held == item then at = i break end
    end
    if not at then return nil, "not in the stash" end

    table.remove(stash, at)
    player.touchstoneShelf = player.touchstoneShelf or {}
    local shelf = player.touchstoneShelf
    shelf[#shelf + 1] = item

    local dropped
    while #shelf > Identify.SHELF_MAX do
        dropped = table.remove(shelf, 1)
    end

    local paid = Identify.fee(item)
    Player.addGold(player, paid)
    return paid, dropped
end

-- What the counter wants to hand a shelved piece back: the fee plus its markup, rounded UP so the premium
-- can never round away to nothing on a cheap floor.
function Identify.buyBackPrice(item)
    return math.ceil(Identify.fee(item) * Identify.BUYBACK_MARKUP)
end

-- Buy `item` back off the shelf. Returns true, or false plus a reason.
--
-- The husk goes back into the stash as the SAME TABLE that left it, so a piece sold and redeemed is the
-- piece you found -- same blueprint, same rolled level, same floor -- rather than a fresh roll wearing
-- its label. Selling is a decision about an object, and a redeemed object that had been quietly re-rolled
-- would make it a decision about nothing.
function Identify.buyBack(player, item)
    local shelf = Identify.shelf(player)
    local at
    for i, held in ipairs(shelf) do
        if held == item then at = i break end
    end
    if not at then return false, "not on the shelf" end
    if not Player.spendGold(player, Identify.buyBackPrice(item)) then return false, "not enough gold" end
    table.remove(shelf, at)
    Player.addToStash(player, item)
    return true
end

-- ---------------------------------------------------------------------------
-- Granting
-- ---------------------------------------------------------------------------

-- Put a sealed piece of `id` in the stash, found on `floor`. The sealed twin of Player.grantItem, and it
-- deliberately does NOT mark the stash dot: the dot is keyed by item id (models/player.lua), and a dot
-- keyed on the answer is a dot that can be read by anyone who knows where to look. The Touchstone's own
-- door carries the news instead, which is a better place for it -- the player is told there is something
-- to read, at the place that reads it.
function Identify.grant(player, id, floor, level)
    local item = Identify.sealed(id, floor, level)
    if not item then return nil end
    Player.addToStash(player, item)
    if Player.onItemGranted then Player.onItemGranted(item) end
    return item
end

-- The vendor id the door declares. It keeps no shelf (`sells = false`, data/vendors/touchstone.lua) and
-- exists purely so the house has a name the rest of the game can ask about -- the Cafe's own trick.
Identify.VENDOR = "touchstone"

-- Has this company any business here? What opens the door (models/building.lua's `unlockUnidentified`).
--
-- TWO CLAUSES, AND THE SECOND ONE IS WHAT KEEPS THE DOOR STANDING. The first is the arrival: a husk in
-- the stash, so the card goes up the night the first unreadable thing is carried in -- the player finds
-- the thing, cannot read it, and THEN the door is there, which is the same lesson the Inn teaches on the
-- first wound. The second is memory: once the counter has been walked into it stays, because a door that
-- came off the plaza the morning after it was used would be the bug data/buildings/the_inn.lua records
-- about reading the wound ledger instead of the mark.
--
-- The memory is `visitedVendors`, which the first-visit greeting already sets and models/save.lua already
-- persists (models/vendor_visit.lua). No new flag, no new save field: the house was given a vendor id for
-- its greeting, and the greeting's own record answers this for free.
function Identify.everFound(player)
    if not player then return false end
    if Player.hasVisitedVendor(player, Identify.VENDOR) then return true end
    return Identify.count(player) > 0
end

return Identify
