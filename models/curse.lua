-- CURSES: the second thing that can be wrong with a piece of gear, and the only one you cannot fix
-- with a hammer.
--
-- THE PRECEDENT IS BROKEN (models/item.lua's Item.wear), and the pair is deliberate. A broken piece
-- wore out; it is refused in the hand (Combat.itemBlockReason), it is mended at the Forge, and the bill
-- is gold. A cursed piece is the opposite shape in every one of those places: it still WORKS -- that is
-- what makes it a curse rather than a rock in your bag -- it is lifted at the Cathedral, and the thing
-- standing between you and being rid of it is usually not money.
--
--   broken   the piece stops working      -> the Forge     -> gold, and the piece is back this minute
--   cursed   the piece works AGAINST you  -> the Cathedral -> a rite that takes trips, or gold for haste
--
-- A CURSE SPEAKS THE ITEM'S OWN VOCABULARY, AND THAT IS THE WHOLE IMPLEMENTATION. A blueprint here
-- declares `bonus`, `resist`, `maxBonus`, `unarmedBonus`, `rules`, `traits`, `traitParams` and
-- `openingBoon` -- every one of them a field an ITEM already declares, read by the code that already
-- reads it (Combat.applyUnitPassives folds the first four beside the item's own, Trait.attach the
-- traits, states/battle.lua the boon). So a curse is a SECOND ITEM stapled to the first one, in the same
-- cell, felt by the same body.
--
-- That buys three things a bespoke effect table would not have:
--
--   no new balance surface   a curse's -3 attack is the same quantity a coat's +3 is, measured through
--                            the one subtractive unit docs/balance.md is written about. Nothing new to
--                            tune against, and the damage breakdown already knows how to print it.
--   rule-bending for free    `rules` is Item.RULE_NAMES -- health pinned at 1, no walking at all, mana
--                            paid in blood. Fourteen inversions of the game's own rules, already
--                            written, already read, already tested. A curse that makes you pay for
--                            spells in blood is one line here, not a system.
--   one place to look        an author asking "what may a curse do?" reads models/item.lua, which is
--                            where they were going to end up anyway.
--
-- WHAT IS *NOT* BORROWED IS `price`, `grade`, `unlockLevel`, `class`. A curse is not a thing on a shelf.
-- It is never bought, never sold, never found on its own -- it arrives attached to something else.
--
-- AND THE ONE FIELD THAT IS ITS OWN: `binds`. A binding curse makes Item.isBound answer true, which is
-- the single predicate every mutation path in the game already refuses through -- the grid editor, the
-- stash, the vendor, combat theft, the at-risk sweep. One field, and the piece cannot be taken off,
-- put down, sold or stolen. That is the classic and it costs one line, because the game already had to
-- know how to nail an item to a body for signature relics.
--
-- THE BIND HOLDS AGAINST YOU, NOT AGAINST THE PRIESTS, and that distinction is the Cathedral's whole
-- reason to have this room. "It cannot be removed" means by you, underground, with your hands. The rite
-- is the answer, and a curse that had no answer would not be a curse -- it would be a deleted item with
-- extra steps.
--
-- ---------------------------------------------------------------------------
-- WHAT IT COSTS TO BE RID OF ONE, and why it is shaped exactly like a wound
-- ---------------------------------------------------------------------------
--
-- docs/the-count.md states the law this room could most easily have broken:
--
--     A cost on recovery is a tax on NEEDING to recover, and needing to recover is what being bad at
--     the game looks like.
--
-- models/wound.lua's Ward is the answer that survived three attempts, and this is that answer with an
-- item where the body goes:
--
--   THE RITE    free, always, no gate and no purse test. The piece is left with the priests and is out
--               of the company for Curse.RITE_DESCENTS trips while they work on it -- so the cost is
--               paid in going down without it, exactly as a resting body's is paid in who walks down
--               without them. Served by DESCENDING (Curse.tickRites, called where Wound.tickRest is).
--   THE LIFTING Curse.fee in gold, and the hex is off before you leave the room.
--
-- The gold buys SPEED and never relief. A company that cannot pay is never stuck with a hex forever;
-- it is stuck with it for two trips, and it chose which two.
--
-- THAT IS ALSO WHY THE FEE MAY BE AUTHORED PER CURSE where the Ward's is one number for every bone.
-- A bone is a bone. A hex is a thing with a name that the player can read off the tooltip before they
-- walk into the room, so a nastier one costing more reads as a fact about the hex rather than as a
-- price pulled out of the piece's worth -- which is the trap models/identify.lua's fee block spends
-- forty lines refusing, and for the same reason: a bill derived from what the thing is worth prints the
-- answer on the price tag.
--
-- Pure model -- no love.graphics, no state switching -- so it loads under the headless runner.

local Registry = require("models.registry")

local Curse = {}

Curse.defs = Registry.load("data/curses", "data.curses")

-- ---------------------------------------------------------------------------
-- What can carry one
-- ---------------------------------------------------------------------------

-- WEAPONS, ARMOUR, UTILITIES AND ABILITIES -- the four types that sit in a grid cell for the length of
-- a campaign and are therefore the four a hex has time to be a problem on.
--
-- CONSUMABLES ARE ABSENT, and it is the same argument models/identify.lua makes for leaving them out of
-- the seal: a stack merges by id (Item.bagPut), so three draughts are one row, and a curse on "the
-- stack" would be a curse on a thing that is not an object. Hexing one potion out of six is a rule
-- nothing in the inventory layer can express, and the fix -- splitting the stack -- would hand the
-- player a second identical row with no visible difference but a badge. Sidestepped rather than solved,
-- and the cost is nil: a cursed potion is drunk once and gone, which is not a curse, it is a bad potion.
Curse.CURSABLE = { weapon = true, armor = true, utility = true, ability = true }

-- Is `item` a thing a hex could land on at all? Type is most of it, plus the two markers that mean the
-- piece is not really an object the player chose to carry:
--
--   noSteal    a beast's fangs, a wyrm's breath. A body part, not gear -- there is no Cathedral visit
--              that helps a wolf, so a hex there is a permanent debuff with a room it cannot reach.
--   unread     a husk has no stats to spoil and no name to print (models/identify.lua). It may still
--              be CARRYING a curse -- the seal stores the truth and withholds it -- but nothing may
--              afflict one afterwards, because the player would be told about a hex on an item they
--              have not been told the identity of.
--
-- A piece that is already cursed is refused too: one hex per item, always. Two would need a merge
-- policy (Item.mergeRules already has one, but the tooltip would then have to print a pile and the
-- rite would have to charge for a pile), and the interesting decision -- pay, or go down two trips
-- without it -- does not get better for being about three hexes at once.
function Curse.canAfflict(item)
    if type(item) ~= "table" then return false end
    if not Curse.CURSABLE[item.type] then return false end
    if item.noSteal then return false end
    if (item.unidentified or 0) > 0 then return false end
    if Curse.isCursed(item) then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- Reading one off a live item
-- ---------------------------------------------------------------------------

-- The hex on `item`, or nil. THE one reader: every surface that folds a penalty, draws a badge, prints
-- a tooltip row or prices a lifting comes through here rather than testing `item.curse` itself, so an
-- id left on an instance by a deleted blueprint reads as "not cursed" everywhere at once instead of
-- reading as cursed in the grid and clean in the fold.
--
-- AND A SEALED PIECE READS AS CLEAN, which is the whole of "the seal stores the truth and withholds
-- it" (models/identify.lua's Identify.sealed, and Curse.canAfflict's `unread` clause above, which is
-- this same rule pointed the other way: a hex may travel INSIDE a seal, but nothing may put one on a
-- piece whose name is still secret, and nothing may read one out of a piece whose name is still
-- secret). The field stays on the husk -- the read has to find it, and the save has to carry it -- and
-- it is simply not answered for until Identify.reveal hands over the true item and stamps it on.
--
-- IT BELONGS HERE RATHER THAN ON THE FOUR SURFACES, because there were four and each had found its
-- own way to say it:
--
--   the tooltip    ui/item_tooltip.lua printed "Cursed: The Shut Hand", the hex's own sentence and the
--                  bind note on a card whose title said Unidentified Weapon. Its comment argues no
--                  guard is needed because a husk "carries no tags, no class, no ability and no bonus"
--                  -- which was true of every field a husk had on the day it was written.
--   the lock       a binding hex made Item.isBound answer true, so the stash cell refused to be
--                  dragged, silently, on a nameless object.
--   the Cathedral  Curse.kit walks the stash, so the rite listed the husk -- and ui/panels/rite.lua
--                  names the hex on the paid row deliberately. Curse.noticed then opened the door on
--                  the plaza, so the CITY announced it.
--   the wipe       Player.atRisk skips a bound item, so a hexed husk survived a death that dropped the
--                  clean ones. The worst of the four: it reads as luck and it rewards the bad roll.
--
-- One guard in the one reader answers all four, which is what the paragraph above promised this
-- function was for.
function Curse.of(item)
    if type(item) ~= "table" then return nil end
    if (item.unidentified or 0) > 0 then return nil end
    local id = item.curse
    if type(id) ~= "string" then return nil end
    return Curse.defs[id]
end

function Curse.isCursed(item)
    return Curse.of(item) ~= nil
end

-- Does the hex on `item` nail it to whoever is holding it? Read by Item.isBound, which is what every
-- mutation path in the game already refuses through -- so this is the whole of "it cannot be removed".
function Curse.binds(item)
    local def = Curse.of(item)
    return def ~= nil and def.binds == true
end

-- The name to print, and the line under it. Both fall back rather than answering nil: a badge with no
-- word on it is a bug wearing a mystery's clothes, and the player is entitled to know a hex is a hex
-- even if the blueprint forgot to say which.
function Curse.name(item)
    local def = Curse.of(item)
    return def and def.name or "Cursed"
end

function Curse.description(item)
    local def = Curse.of(item)
    return def and def.description or "Something is wrong with this piece."
end

-- ---------------------------------------------------------------------------
-- COUNTING THEM, which is what a whole shelf of gear is now built to read
-- ---------------------------------------------------------------------------
--
-- A body's hexes are a RESOURCE to some items (The Reckoning hits harder per hex, The Gathered Weight
-- pays stats per hex, Speak for Them silences for turns per hex), and that is the second half of what
-- this system is for. A curse costs you something; a shelf that reads the count is what makes paying it
-- a decision instead of a chore.
--
-- IT READS ONE BODY'S GRID, NOT THE COMPANY'S, and that is the balance. The body cashing four hexes in
-- is the body that cannot move, recovers nothing between fights and has half a health pool -- so the
-- scaling is always paid for in the same place it is spent. A company-wide reading is a different
-- question with a different answer (Curse.kit, above) and only one item asks it.

-- How many pieces in `char`'s grid are hexed. The number every counting item quotes -- through
-- `ab.counter`, which is also what draws the grid badge and the tooltip row, so the figure the player
-- reads and the figure the effect multiplies by are the same call.
function Curse.countOn(char)
    -- `char.inventory` rather than `char`: the tooltip's dry run and the grader both hand in a
    -- STAND-IN body with no grid on it (models/combat.lua's previewStandIn), and Character.eachItem
    -- indexes the field directly. A counting item asked "how many hexes" by a preview should answer
    -- none, not fault -- the same reading a body that happens to carry none gets.
    if not (char and char.inventory) then return 0 end
    local Character = require("models.character")
    local n = 0
    for _, item in ipairs(Character.eachItem(char)) do
        if Curse.isCursed(item) then n = n + 1 end
    end
    return n
end

-- Every hexed piece in `char`'s grid, in cell order. What an ability picks from when it has to choose
-- one -- Rouse the Binding wants the deepest, Let It Walk wants any.
function Curse.hexedOn(char)
    if not (char and char.inventory) then return {} end
    local Character = require("models.character")
    local out = {}
    for _, item in ipairs(Character.eachItem(char)) do
        if Curse.isCursed(item) then out[#out + 1] = item end
    end
    return out
end

-- The worst hex `char` is carrying, as item + def, or nil. Ties go to the first cell, so a body holding
-- two curses of one depth resolves the same way twice -- a replayed fight must pick the same piece.
function Curse.deepestOn(char)
    local best, bestDef
    for _, item in ipairs(Curse.hexedOn(char)) do
        local def = Curse.of(item)
        if def and (not bestDef or Curse.depthOf(def) > Curse.depthOf(bestDef)) then
            best, bestDef = item, def
        end
    end
    return best, bestDef
end

-- ---------------------------------------------------------------------------
-- MOVING ONE, which is the whole of what a Shaman may do to a binding
-- ---------------------------------------------------------------------------
--
-- A Shaman manipulates and never removes (docs/curses.md). Every one of their verbs bottoms out here or
-- in Curse.afflict: Rebind moves a hex to the body standing beside it, Let It Spread creeps it into the
-- next cell, Let It Walk lends it to something that can be killed. The company's hex count is the same
-- afterwards in all three -- only WHERE it sits has changed.
--
-- Ending one is the Exorcist's job and the Cathedral's, and both of those go through Curse.lift.

-- Move the hex on `from` onto `to`. Returns the curse id on success, or nil plus a reason.
--
-- THE TARGET IS CHECKED BEFORE THE SOURCE IS EMPTIED, which is the only thing this function has to get
-- right: a move that lifted first and then found the destination refused would have destroyed a curse,
-- and destroying one is precisely what the caller is not allowed to do.
function Curse.move(from, to)
    local id = from and from.curse
    if type(id) ~= "string" then return nil, "nothing to move" end
    if from == to then return nil, "same piece" end
    if not Curse.canAfflict(to) then return nil, "cannot take it" end
    Curse.lift(from)
    Curse.afflict(to, id)
    return id
end

-- Move a hex from `char` onto whichever of `char`'s own cells will take one, chosen by `pick` (a cell
-- index or a predicate). The shape Let It Spread wants: the binding stays in the same grid and creeps.
function Curse.spreadWithin(char, from)
    if not (char and Curse.isCursed(from)) then return nil end
    local Character = require("models.character")
    local cell = Character.slotIndex(char, from)
    if not cell then return nil end
    -- Adjacency is the grid's own (diagonals included), so a hex creeps the way the adjacency auras
    -- already read -- the player's mental model of "next to" is one thing, not two.
    for _, i in ipairs(Character.adjacentIndices(cell)) do
        local neighbour = char.inventory[i]
        if Curse.canAfflict(neighbour) then
            return Curse.afflict(neighbour, from.curse) and from.curse or nil
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- The two gates a hex closes outside combat
-- ---------------------------------------------------------------------------

-- Does the hex on `item` stop the Forge working it (Cold Iron)? Read by models/forge.lua, which is the
-- only file that cares -- a curse that costs no stat at all and costs the bench instead.
function Curse.blocksForge(item)
    local def = Curse.of(item)
    return def ~= nil and def.blocksForge == true
end

-- Is this body's kit warded against taking a hex at all (Consecration)? PREVENTION, which is neither of
-- the system's other two verbs: a Shaman cannot do it and the Cathedral's rite is not it. Asked by
-- Curse.canAfflict, so every vector in the game -- trap, cast, reveal, blueprint -- is refused by one
-- clause rather than by four that could drift.
function Curse.warded(char)
    if not (char and char.inventory) then return false end
    local Character = require("models.character")
    for _, item in ipairs(Character.eachItem(char)) do
        if item.curseWard then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- The two effect lists that are NOT folded by Combat.applyUnitPassives
-- ---------------------------------------------------------------------------
--
-- A curse's flat halves -- `bonus`, `resist`, `maxBonus`, `unarmedBonus`, `rules` -- are summed beside
-- the item's own where every other source of those is summed, in Combat.applyUnitPassives, and nothing
-- outside that function needs to know a hex exists. The two lists below are the exceptions, because
-- traits and opening boons are gathered by OTHER passes (models/trait.lua at attach, states/battle.lua
-- at the bell) and each walks the grid for itself.
--
-- SO THE JOIN LIVES HERE RATHER THAN AT EITHER CALL SITE. Both passes ask "what does this piece bring?"
-- and get one answer, so neither has to remember that a piece may be two things stapled together -- and
-- a third pass that ever needs the same question has somewhere to ask it. Both return a fresh list and
-- both are safe on an uncursed item, which is the overwhelming majority of every grid in the game.

-- Every trait id `item` grants: its own, then its hex's.
function Curse.traitsOn(item)
    local out = {}
    for _, id in ipairs((item and item.traits) or {}) do out[#out + 1] = id end
    local def = Curse.of(item)
    for _, id in ipairs((def and def.traits) or {}) do out[#out + 1] = id end
    return out
end

-- Every opening boon `item` brings to the bell, its own first, each already unwrapped to a single
-- `{ id, opts }`. An author may write one entry bare or several in a list -- the bare table is the
-- overwhelmingly common shape and nobody should have to wrap it -- so the unwrapping is done once here
-- instead of at every reader.
function Curse.openingBoons(item)
    local out = {}
    local function add(boon)
        if not boon then return end
        for _, b in ipairs(boon.id and { boon } or boon) do out[#out + 1] = b end
    end
    add(item and item.openingBoon)
    local def = Curse.of(item)
    add(def and def.openingBoon)
    return out
end

-- ---------------------------------------------------------------------------
-- Putting one on, and taking one off
-- ---------------------------------------------------------------------------

-- Stamp curse `id` onto `item`. Returns true, or false plus a reason a caller may narrate.
--
-- ONLY THE ID IS WRITTEN. The effects are looked up through Curse.of on every read rather than copied
-- onto the instance, so a rebalanced hex flows into old saves exactly the way a rebalanced item does --
-- and, more to the point, lifting it is one assignment rather than an unwind of everything it folded.
-- An overlay that had been baked in would have to be subtracted back out, and the one thing a system
-- that writes to the player's gear must never do is get the subtraction wrong.
function Curse.afflict(item, id)
    if not Curse.defs[id] then return false, "unknown curse" end
    if not Curse.canAfflict(item) then return false, "cannot be cursed" end
    item.curse = id
    return true
end

-- Take it off. Returns the id that was lifted, or nil if there was nothing on it -- so a caller can
-- name what it just undid without having read the field first.
function Curse.lift(item)
    if type(item) ~= "table" then return nil end
    local id = item.curse
    item.curse = nil
    return id
end

-- ---------------------------------------------------------------------------
-- The roll: which hex, and how deep it may be found
-- ---------------------------------------------------------------------------

-- love.math.random under LÖVE, else math.random. One helper so the module is engine-agnostic -- the
-- shape models/identify.lua and models/spoils.lua both keep.
local function rnd(...)
    if love and love.math and love.math.random then return love.math.random(...) end
    return math.random(...)
end

-- The shallowest floorLevel a hex may be rolled at. A blueprint declaring no `depth` is available from
-- the first floor, which is the right default: the mild ones are the common ones and the deep ones say
-- so themselves.
--
-- THE UNIT IS `floorLevel`, NOT THE FLOOR NUMBER -- 1 + (floor - 1) * Descent.LEVEL_PER_FLOOR, so 1 to
-- 15 down a fifteen-floor rift. models/identify.lua's fee block records what it cost to get that wrong
-- once already: a figure tuned against 1..8 that was actually being handed 1..15.
function Curse.depthOf(def)
    return math.max(1, math.floor(tonumber(def and def.depth) or 1))
end

-- Every hex that may turn up at `level`, by id, sorted. Sorted rather than left to `pairs` because the
-- roll below indexes into it: a set walked in hash order is a different list on a machine that required
-- one more module, and a seeded roll that picks a different curse on two machines is not a roll.
function Curse.eligible(level)
    level = math.max(1, math.floor(tonumber(level) or 1))
    local out = {}
    for id, def in pairs(Curse.defs) do
        if Curse.depthOf(def) <= level then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- Roll one hex for a piece found at `level`. Nil when nothing is eligible, which cannot happen while
-- any blueprint declares no depth but is answered rather than asserted -- a data folder emptied by a
-- bad merge should hand back clean loot, not crash the reveal.
function Curse.roll(level)
    local pool = Curse.eligible(level)
    if #pool == 0 then return nil end
    return pool[rnd(#pool)]
end

-- ---------------------------------------------------------------------------
-- What it costs to be rid of one
-- ---------------------------------------------------------------------------

-- THE DEFAULT LIFTING FEE, for a hex that names no figure of its own.
--
-- 120 GOLD, AGAINST THE THREE BILLS ALREADY ON THE BOARD. A bone is Wound.TREAT_COST 40; a reading is
-- Identify.FEE_BASE 100 plus 45 a level; a complete descent pays something like 20,000 (the arithmetic
-- is in models/identify.lua's fee block). So this sits a little above a reading and nowhere near a
-- trip's income, which is the band it wants: payable the moment you decide you want the piece back,
-- never the thing that decides whether you go down again.
--
-- IT IS DELIBERATELY NOT MUCH MONEY, because the money is not the interesting half of this room. Two
-- trips without your best weapon is the cost that gets weighed; the fee is the button for a player who
-- has already decided they would rather not weigh it. Pricing it high would make the free path the one
-- everybody takes, which turns the choice back into a wait.
Curse.LIFT_COST = 120

-- What the Cathedral charges to lift the hex on `item` today. A curse may name its own `fee`; the
-- nastier ones do, and the figure is a fact about the hex rather than about the piece -- see the header
-- on why a bill derived from the item's worth would print the answer on the price tag.
function Curse.fee(item)
    local def = Curse.of(item)
    if not def then return 0 end
    return math.max(0, math.floor(tonumber(def.fee) or Curse.LIFT_COST))
end

-- HOW MANY TRIPS THE FREE RITE TAKES. Two, which is Wound.REST_DESCENTS, and they are the same number
-- on purpose: the two free paths in the city cost the same span of the same clock, so a player learns
-- the unit once. A body laid up and a piece left on the altar both come back on the second homecoming.
Curse.RITE_DESCENTS = 2

-- ---------------------------------------------------------------------------
-- The ledger: what the company is carrying, and what the priests are holding
-- ---------------------------------------------------------------------------

-- Has anything in this company ever been hexed? The Cathedral's room gate (models/offer.lua's
-- GATES.cursed), and a sticky flag rather than a live count for exactly the reason Wound.everWounded is
-- one: a door that appeared when the first hex landed and vanished the moment it was lifted would take
-- the room away at the instant the player finished learning what it was for.
function Curse.everCursed(player)
    return (player and player.cursed) == true
end

function Curse.markCursed(player)
    if player then player.cursed = true end
end

-- THE GATE'S OWN READING, and it STAMPS. Answers "should the Cathedral be offering the rite?" -- which
-- is the sticky mark above, OR anything hexed right now; and having seen one, it writes the mark.
--
-- IT IS A PREDICATE WITH A SIDE EFFECT, which is unusual enough to argue for. The alternative was for
-- every vector to remember to stamp, and they cannot all reach a player to do it: Combat.curseItem is
-- handed a board and a unit, and a board has no idea whose company it is fighting for. So a trap that
-- hexed a knight's sword on floor three set no mark at all, and the room that lifts it never opened --
-- the player left the rift carrying a curse and a city with no answer to it.
--
-- The fix could have been a SECOND ledger (the gate reads a live count, the mark is written elsewhere),
-- and that is exactly the shape that goes stale: two facts about one event, kept apart, disagreeing the
-- first time one of them is not updated. One function, asked at the one moment the answer is wanted --
-- the city being drawn -- writing the mark it just earned.
--
-- The live clause also covers the case the mark cannot: a piece that arrives already hexed, bought over
-- a counter (utility_hexbinders_cord) rather than dealt by anything that could have stamped.
function Curse.noticed(player)
    if not player then return false end
    if Curse.count(player) > 0 then Curse.markCursed(player) end
    return Curse.everCursed(player)
end

-- Every hexed piece the company is carrying, as { char, item } -- the roster's grids first in roster
-- order, then the stash (where `char` is nil). What the Cathedral's room lists, and what a warning
-- before a descent would count. Mirrors Player.brokenKit, which is the same sweep for the other defect.
--
-- THE STASH IS WALKED TOO, and a bound hex cannot be in there -- Item.isBound refuses the stow -- so
-- anything this finds in the stash is a hex the player chose to shelve rather than pay for. That is a
-- legitimate answer to a curse and the room should still offer to finish the job.
--
-- AND NOT A HUSK, which is the one thing in the stash that can be carrying a hex without being one:
-- Curse.isCursed goes through Curse.of, which answers nil for anything still sealed. Before that guard
-- this sweep listed unread finds, and ui/panels/rite.lua names the hex on its paid row deliberately --
-- so the Cathedral read the seal out loud, and Curse.noticed opened its door on the plaza to announce
-- it.
function Curse.kit(player)
    local Character = require("models.character")
    local out = {}
    for _, char in ipairs((player and player.roster) or {}) do
        for _, item in ipairs(Character.eachItem(char)) do
            if Curse.isCursed(item) then out[#out + 1] = { char = char, item = item } end
        end
    end
    for _, item in ipairs((player and player.stash) or {}) do
        if Curse.isCursed(item) then out[#out + 1] = { char = nil, item = item } end
    end
    return out
end

function Curse.count(player)
    return #Curse.kit(player)
end

-- ---------------------------------------------------------------------------
-- The two ways out
-- ---------------------------------------------------------------------------

-- PAY, AND IT IS OFF BEFORE YOU LEAVE THE ROOM. Returns true, or false plus a reason.
--
-- The gold moves BEFORE the lift for the same reason models/identify.lua builds its revealed instance
-- first: the two halves must not be able to half-happen. Here the risky half is the purse, so it goes
-- first -- a lift that then failed would be gold taken for nothing, and there is nothing that can fail
-- about clearing a field.
function Curse.pay(player, item)
    local Player = require("models.player")
    if not Curse.isCursed(item) then return false, "nothing to lift" end
    local fee = Curse.fee(item)
    if not Player.spendGold(player, fee) then return false, "not enough gold" end
    Curse.lift(item)
    return true
end

-- LEAVE IT WITH THEM, AND GO DOWN WITHOUT IT. The piece comes off whatever grid it is in -- a bind does
-- not hold against the priests, see the header -- and sits on `player.rites` until Curse.RITE_DESCENTS
-- trips have been served.
--
-- THE LIVE TABLE IS MOVED, NOT COPIED. It is the same item: the forge level it was hammered to, the wear
-- it has taken, the quantity, all of it, still in the table that was in the grid a moment ago. A copy
-- would be a second object, and a system that hands the player a NEW sword in place of the one they
-- left is a system that eventually loses the +3.
--
-- Returns true, or false plus a reason.
function Curse.commit(player, item)
    if not (player and Curse.isCursed(item)) then return false, "nothing to commit" end

    local Character = require("models.character")
    local removed = false
    for _, char in ipairs(player.roster or {}) do
        local cell = Character.slotIndex(char, item)
        if cell then char.inventory[cell] = nil; removed = true; break end
    end
    if not removed then
        for i, stashed in ipairs(player.stash or {}) do
            if stashed == item then table.remove(player.stash, i); removed = true; break end
        end
    end
    -- Not in a grid and not in the stash: it belongs to something this function does not know about
    -- (a draft run's loaner, a husk mid-reveal). Refused rather than duplicated -- committing it would
    -- put the same table in two places and the return would hand back a second copy.
    if not removed then return false, "that piece is not in the company" end

    player.rites = player.rites or {}
    player.rites[#player.rites + 1] = { item = item, left = Curse.RITE_DESCENTS }
    return true
end

-- What the priests are holding, in the order it was committed. Each entry is { item, left }, `left`
-- being trips still to serve. The room draws this under its own rows, for the same reason the Ward
-- lists the resting: it is the cost of the free path, made visible. A name sitting in this list is a
-- weapon that is not going down with you.
function Curse.rites(player)
    local out = {}
    for _, entry in ipairs((player and player.rites) or {}) do
        out[#out + 1] = entry
    end
    return out
end

-- SERVE A TRIP. Called on the descent, from the same seam Wound.tickRest is -- one trip down is one
-- night the rite is worked, and both free paths in the city are therefore paid in the same currency and
-- tick on the same event.
--
-- A rite that comes due hands the piece back CLEAN AND TO THE STASH, never to the grid it came off.
-- The cell it vacated is two trips stale by then: the player has almost certainly put something else in
-- it, and a return that shoved that something out would be the system deciding a loadout question on
-- the player's behalf. The stash always has room (models/player.lua) and the Armory is one door away.
--
-- Returns the items handed back, so a caller can say whose rite finished.
function Curse.tickRites(player)
    local Player = require("models.player")
    local list = player and player.rites
    if not list or #list == 0 then return {} end

    local done, kept = {}, {}
    for _, entry in ipairs(list) do
        entry.left = (entry.left or 0) - 1
        if entry.left <= 0 then
            Curse.lift(entry.item)
            Player.addToStash(player, entry.item)
            done[#done + 1] = entry.item
        else
            kept[#kept + 1] = entry
        end
    end
    player.rites = kept
    return done
end

return Curse
