-- THE HOUSE A CLASS IS TAUGHT AT, AND WHEN IT REACHES THE PLAZA.
--
-- Every house's shelf is quiet (models/offer.lua) -- it may not put a card on the square -- so for a
-- while the seven class houses arrived in the order their OTHER rooms happened to be scheduled: the
-- Colosseum on the duel at trip 7, the Alchemist on the reading at 6, the Arcanum on the bestiary at 4.
-- Fighter was not last because fighter gear is late content; it was last because PvP is. And no root
-- class has a `requires` at all, so a player could declare Fighter on the first morning and then walk
-- five trips with nowhere to buy a fighter ability.
--
-- The `declared` gate is the fix: taking up a class opens the house that shelves it, at once, and the
-- trips gate on each house's other room is untouched underneath as the backstop. These cases hold both
-- halves of that -- the early open AND the untouched schedule -- plus the one-way rule that keeps the
-- city from being the only thing in this game that shrinks.

local Building = require("models.building")
local Class = require("models.class")
local Offer = require("models.offer")
local Player = require("models.player")
local Vendor = require("models.vendor")

-- The seven houses by the class each one shelves, read off the vendor blueprints rather than written
-- out here: a house that changed hands would otherwise be tested against a mapping nobody updated.
local function houseOf(class)
    local vendorId = Vendor.forClass(class)
    assert(vendorId, "no vendor shelves " .. tostring(class))
    for id, def in pairs(Building.defs) do
        if def.vendor == vendorId then return id, def end
    end
    error("no building keeps the " .. vendorId .. " counter")
end

local function isOpen(player, buildingId)
    return not Building.locked(player, Building.defs[buildingId])
end

-- A company with nobody in it, so a case can put exactly one body on the roster and nothing else is
-- speaking for it. `Player.new` opens with Rowan, who is a knight -- which is a fact one case below is
-- specifically about and every other case has to get out from under.
local function emptyCompany()
    local p = Player.new()
    p.roster = {}
    p.classesTaken = nil
    return p
end

local function bodyOf(class)
    return { id = "test_body", declaredClass = class }
end

return {
    {
        name = "every house's shelf is quiet, and announces on the class it teaches",
        fn = function()
            for _, class in ipairs({ "knight", "rogue", "mage", "priest", "hunter", "alchemist", "fighter" }) do
                local id, def = houseOf(class)
                local shelf
                for _, offer in ipairs(def.offers or {}) do
                    if offer.answer == "shelf" then shelf = offer end
                end
                assert(shelf, id .. " keeps no shelf")
                -- Quiet, because browsing is not a deed the player can feel...
                assert(shelf.quiet == true, id .. "'s shelf must stay quiet")
                -- ...and the one exception, because taking up the class IS one.
                assert(shelf.announce and shelf.announce.declared == true,
                    id .. "'s shelf must announce on `declared` -- without it this house is back on the"
                    .. " room queue and its class waits for whatever else is behind the door")
                assert(shelf.gate == nil,
                    id .. "'s shelf must stay ungated: a shopfront that offers no shop is not a shopfront")
            end
        end,
    },
    {
        name = "declaring a class puts its house on the plaza",
        fn = function()
            for _, class in ipairs({ "knight", "rogue", "mage", "priest", "hunter", "alchemist", "fighter" }) do
                local id = houseOf(class)
                local p = emptyCompany()
                assert(not isOpen(p, id), id .. " should be shut for a company with nobody in it")
                p.roster = { bodyOf(class) }
                assert(isOpen(p, id),
                    "declaring " .. class .. " should open " .. id .. " -- on the spot, not on a trip")
            end
        end,
    },
    {
        name = "a body born to a class opens its house without anyone declaring anything",
        fn = function()
            -- `Player.new` is Rowan and nobody else, and Rowan is a knight (data/characters). A fresh
            -- save therefore opens on the house that sells what the company is already carrying, which
            -- is the whole point: the shop for your starting class should not be three trips away.
            local p = Player.new()
            assert(#p.roster > 0, "the starting company should not be empty")
            assert(isOpen(p, houseOf("knight")),
                "a fresh save starts with a knight, so the Bastion is open on the first morning")
        end,
    },
    {
        name = "a crossing opens both houses that shelve it",
        fn = function()
            -- Shopping both shelves is literally how a crossing is built (models/vendor.lua), so a body
            -- declared into one must be able to reach both counters. Read off the class's own parents so
            -- this holds for whichever crossing is picked.
            local crossing
            for id in pairs(Class.defs) do
                if Class.arity(id) >= 2 then
                    local ok = true
                    for _, parent in ipairs(Class.parents(id)) do
                        if not Vendor.forClass(parent) then ok = false end
                    end
                    if ok then crossing = id; break end
                end
            end
            assert(crossing, "no crossing whose parents are both shelved -- nothing to test")

            local p = emptyCompany()
            p.roster = { bodyOf(crossing) }
            for _, parent in ipairs(Class.parents(crossing)) do
                assert(isOpen(p, houseOf(parent)),
                    crossing .. " should open " .. parent .. "'s house: its gear is on that rack")
            end
        end,
    },
    {
        name = "changing class back does not take the card off the plaza",
        fn = function()
            -- Changing class is free and reversible by design (ui/class_editor.lua). A live reading of
            -- the roster would therefore make the city the one thing in this game that SHRINKS -- move
            -- your only fighter to knight and the Colosseum is gone. Class.taken is one-way for exactly
            -- this, and it is the reason the ledger is persisted (models/save.lua).
            local p = emptyCompany()
            local body = bodyOf("fighter")
            p.roster = { body }
            assert(isOpen(p, houseOf("fighter")), "declaring fighter should open the Colosseum")

            body.declaredClass = "knight"
            assert(isOpen(p, houseOf("fighter")),
                "the Colosseum must stay on the square after the last fighter moves on")
            assert(isOpen(p, houseOf("knight")), "...and the Bastion joins it")
        end,
    },
    {
        name = "an undeclared body is not a fighter",
        fn = function()
            -- Growth.classOf answers `fighter` for a body with nothing declared and no innate class --
            -- a default about how to LEVEL, not a statement that the company has a fighter. Read as one
            -- it would open the Colosseum on the first morning of every save in the game, on the
            -- strength of the recruit who was trained in nothing at all.
            local p = emptyCompany()
            p.roster = { { id = "test_body" } }
            assert(Class.declaredOf(p.roster[1]) == nil,
                "a body standing in no class answers none")
            assert(not isOpen(p, houseOf("fighter")),
                "the Colosseum must not open for a company with no fighter in it")
        end,
    },
    {
        name = "the rooms behind the doors keep their own schedule",
        fn = function()
            -- THE BACKSTOP IS UNTOUCHED, which is the other half of the change. Opening the house early
            -- must not drag the room behind it forward: the duel is still the seventh trip whether or
            -- not somebody declared fighter on the first morning.
            local p = emptyCompany()
            p.roster = { bodyOf("fighter") }
            p.runsStarted = 0
            local _, def = houseOf("fighter")

            assert(Offer.openSet(p, def).shelf, "the shelf is open the moment the class is taken up")
            assert(not Offer.openSet(p, def).duel,
                "...and the duel is not: a house opening early does not open its rooms early")

            p.runsStarted = 7
            assert(Offer.openSet(p, def).duel, "the duel arrives on its own gate, as it always did")
        end,
    },
    {
        name = "a company that declares nothing still sees the old schedule",
        fn = function()
            -- The trips gates are the guarantee for a player who never opens the Roll, and they are
            -- unchanged. Each house's OTHER room is what puts its card up for such a company, so this
            -- walks the trip counter and holds each door to the gate its room was authored with.
            local p = emptyCompany()
            p.roster = { { id = "test_body" } } -- in no class at all: nothing announces
            local schedule = {
                { trips = 1, class = "rogue" },      -- the town counter
                { trips = 2, class = "hunter" },     -- supper
                { trips = 3, class = "knight" },     -- the forge
                { trips = 4, class = "mage" },       -- the bestiary
                { trips = 6, class = "alchemist" },  -- the reading
                { trips = 7, class = "fighter" },    -- the duel
            }
            for _, row in ipairs(schedule) do
                local id = houseOf(row.class)
                p.runsStarted = row.trips - 1
                assert(not isOpen(p, id),
                    id .. " should still be shut at " .. (row.trips - 1) .. " trips")
                p.runsStarted = row.trips
                assert(isOpen(p, id),
                    id .. " should arrive on trip " .. row.trips .. " for a company that declares nothing")
            end
        end,
    },
    {
        name = "the Roll's trainer button agrees with the card it walks to",
        fn = function()
            -- THE BUG THIS SHIPPED WITH. houseForClass computed `open` off a `classLevel` gate the shelf
            -- had carried; that gate was deleted when the shelf was ungated, the lookup answered nil, and
            -- `Offer.open(nil)` reads as open -- so every house in the city reported itself open forever.
            -- The Roll drew a live button on a shut Colosseum, the player pressed it, and the hub found
            -- the card locked and did nothing at all. Both sides ask Building.locked now.
            for _, class in ipairs({ "knight", "rogue", "mage", "priest", "hunter", "alchemist", "fighter" }) do
                for _, p in ipairs({ emptyCompany(), Player.new() }) do
                    local house = Building.houseForClass(class, p)
                    assert(house, "no house answers for " .. class)
                    assert(house.open == isOpen(p, house.id),
                        "the trainer button and the plaza disagree about " .. house.id
                        .. ": a control that is drawn live and then silently ignored is worse than one"
                        .. " drawn refused")
                end
            end
        end,
    },
    {
        name = "a house with no offers is never shut by the announce rule",
        fn = function()
            -- The Armory and the Rift are doors onto one thing each and declare no rooms. Offer.any
            -- answers true for them by the count, before anything is asked about quiet or announce, and
            -- that has to survive: "keeps no offers" must never read as "is shut".
            local p = emptyCompany()
            assert(isOpen(p, "armory"), "the Armory keeps no offers and is always open")
            assert(isOpen(p, "the_gate"), "the Rift keeps no offers and is always open")
        end,
    },
}
