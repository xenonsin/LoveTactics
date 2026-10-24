-- THE HIRING BOARD (models/hire.lua, approved 2026-10-12). Holds the promises the review page made:
--
--   * a hire is a function of its id -- it resolves, instantiates and survives a save as that id alone;
--   * the board is three strangers per homecoming, dealt once and kept, from classes the company holds;
--   * the stat roll is zero-sum, and a gifted one is exactly GIFT_UNITS over;
--   * every standard kit is rung 0, so hiring never hands over a piece past the shelf;
--   * hiring charges the fee, arrives at the roster's median, and NEVER raises a shelf's rung;
--   * a gift is a find off the hire's own shelf at or below the company's rung;
--   * a hire can be dismissed and renamed; the avatar and the seven cannot be dismissed;
--   * and the reason the board exists at all: a hired body of another people can wear its race's item.

local Hire = require("models.hire")
local Character = require("models.character")
local Player = require("models.player")
local Class = require("models.class")
local Item = require("models.item")
local Growth = require("models.growth")
local Save = require("models.save")

local function freshPlayer(seed)
    local p = Player.new()
    p.seed = seed or 424242
    p.tripsCounted = 6
    p.gold = 1000
    return p
end

local function playableClasses()
    local out = {}
    -- Not the starter: a stranger is hired into a trade, and nobody is hired as a Novice.
    for id in pairs(Class.defs) do
        if Class.isPlayable(id) and not Class.isStarter(id) then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

return {
    {
        name = "a hire resolves from its id, instantiates, and stays out of the blueprint sweep",
        fn = function()
            local id = Hire.idOf("knight", "dwarf", 123456)
            local class, race, roll = Hire.split(id)
            assert(class == "knight" and race == "dwarf" and roll == 123456, "the id does not split back")
            local def = Character.defs[id]
            assert(def, "Character.defs did not resolve a hire id")
            assert(def.race == "dwarf" and def.class == "knight" and def.hire, "the blueprint lost its make")
            local char = Character.instantiate(id)
            assert(char.hire and char.race == "dwarf", "the instance lost hire/race")
            for key in pairs(Character.defs) do
                assert(not tostring(key):find("^character_hire@"),
                    "a derived hire leaked into pairs(Character.defs): " .. tostring(key))
            end
            assert(Character.defs[Hire.idOf("knight", "dragon", 1)] == nil, "a creature race resolved as a hire")
            assert(Character.defs[Hire.idOf("nonsense", "dwarf", 1)] == nil, "an unknown class resolved")
        end,
    },
    {
        name = "the roll is zero-sum, and a gifted stranger is exactly the gift over",
        fn = function()
            local gifted, n = 0, 0
            for _, class in ipairs(playableClasses()) do
                for roll = 1, 60 do
                    local r = Hire.rollOf(class, roll * 7717)
                    local net = Hire.netUnits(r.delta)
                    local want = r.gifted and Hire.GIFT_UNITS or 0
                    assert(math.abs(net - want) < 1e-9,
                        class .. " roll " .. roll .. " moved the line by " .. net .. " units, wanted " .. want)
                    local def = Character.defs[Hire.idOf(class, "human", roll * 7717)]
                    for stat, v in pairs(def.stats) do
                        assert(v >= 1 or stat == "staminaRegen" or Hire.template(class)[stat] == 0,
                            class .. "'s " .. stat .. " rolled below 1")
                    end
                    if r.gifted then gifted = gifted + 1 end
                    n = n + 1
                end
            end
            local rate = gifted / n
            assert(rate > 0.06 and rate < 0.14, "one in ten should arrive gifted; measured " .. rate)
        end,
    },
    {
        name = "the aptitude is one stat inside the personal budget, and the sheet reads it",
        fn = function()
            for roll = 1, 50 do
                local id = Hire.idOf("fighter", "orc", roll * 31)
                local pg = Growth.personal({ id = id })
                assert(pg, "a hire carries no personal growth")
                local count, total = 0, 0
                for _, v in pairs(pg) do count = count + 1; total = total + v end
                assert(count == 1, "an aptitude is ONE stat")
                assert(total <= Growth.PERSONAL_BUDGET, "the aptitude spends past the personal budget")
            end
        end,
    },
    {
        name = "every class's standard kit is real, rung 0, and leads with its weapon",
        fn = function()
            for _, class in ipairs(playableClasses()) do
                local kit = Hire.kitOf(class)
                assert(#kit > 0, class .. " has no kit")
                for _, id in ipairs(kit) do
                    local d = Item.defs[id]
                    assert(d, class .. "'s kit names a missing item " .. id)
                    assert((d.unlockLevel or 0) == 0, class .. "'s kit carries " .. id .. " at rung "
                        .. tostring(d.unlockLevel) .. "; hiring must never hand over a piece past the shelf")
                end
                assert(Item.defs[kit[1]].type == "weapon", class .. "'s kit does not lead with a weapon")
                if not Class.isRoot(class) then
                    assert(Hire.crossingPiece(class), class .. " has no rung-0 piece of its own")
                end
            end
        end,
    },
    {
        name = "the board is three strangers, dealt once per homecoming and kept",
        fn = function()
            local p = freshPlayer()
            local board = Hire.board(p)
            assert(#board.offers == Hire.SLATE, "the board should hold " .. Hire.SLATE)
            local seen = {}
            for _, o in ipairs(board.offers) do
                assert(Character.defs[o.id], "the board dealt an unresolvable id " .. o.id)
                assert(not seen[o.id], "the board dealt one stranger twice")
                seen[o.id] = true
                local class = Hire.split(o.id)
                assert(Class.isRoot(class), "a fresh company was dealt " .. class .. ", which it has not opened")
            end
            assert(Hire.board(p) == board, "asking again re-dealt the board")

            local twin = freshPlayer()
            for i, o in ipairs(Hire.board(twin).offers) do
                assert(o.id == board.offers[i].id, "the same seed and trip dealt a different board")
            end

            p.tripsCounted = p.tripsCounted + 1
            local next = Hire.board(p)
            assert(next ~= board and next.trip == p.tripsCounted, "a new homecoming did not deal a new board")
        end,
    },
    {
        name = "hiring charges the fee, arrives at the median, and never raises a shelf",
        fn = function()
            local p = freshPlayer()
            for _, char in ipairs(p.roster) do char.xp = 300 end
            local before = {}
            for _, class in ipairs(playableClasses()) do before[class] = Class.rosterLevel(p, class) end
            local gold = p.gold
            local size = #p.roster
            local char = assert(Hire.hire(p, 1))
            assert(p.gold == gold - Hire.FEE, "the fee was not charged")
            assert(#p.roster == size + 1, "the hire did not join the roster")
            assert(char.xp == 300, "a hire should arrive at the company's median experience")
            assert(Hire.board(p).offers[1].hired, "the offer was not marked taken")
            for _, class in ipairs(playableClasses()) do
                assert(Class.rosterLevel(p, class) <= before[class],
                    "hiring raised the " .. class .. " shelf from " .. before[class] .. " to "
                    .. Class.rosterLevel(p, class))
            end
            local again, why = Hire.hire(p, 1)
            assert(not again and why, "the same stranger was hired twice")

            local broke = freshPlayer()
            broke.gold = Hire.FEE - 1
            local none, reason = Hire.hire(broke, 1)
            assert(not none and reason and #broke.roster == #Player.new().roster,
                "a company that cannot cover the fee hired anyway")
        end,
    },
    {
        name = "a gift is a find off the hire's own shelf, at or below the company's rung",
        fn = function()
            local p = freshPlayer()
            for _, class in ipairs({ "knight", "fighter", "rogue", "mage", "hunter", "priest", "alchemist" }) do
                for roll = 1, 40 do
                    local gift = Hire.giftFor(p, class, roll * 101)
                    if gift then
                        local d = Item.defs[gift]
                        assert(d.class == class, "a " .. class .. " was gifted another shelf's " .. gift)
                        assert(d.price == nil, "a gift should be a find, got the priced " .. gift)
                        assert((d.unlockLevel or 0) <= Class.rosterLevel(p, class),
                            "a gift came from past the company's rung: " .. gift)
                    end
                end
            end
        end,
    },
    {
        name = "a hire survives a save as its id, nickname and board included",
        fn = function()
            local p = freshPlayer()
            local char = assert(Hire.hire(p, 2))
            char.name = "Biscuit"
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
            local found
            for _, c in ipairs(back.roster) do if c.id == char.id then found = c end end
            assert(found, "the hire did not survive the save")
            assert(found.name == "Biscuit", "the nickname did not survive the save")
            assert(found.hire and found.tint, "the restored hire lost its hire mark or tint")
            assert(back.hireBoard and back.hireBoard.trip == p.hireBoard.trip, "the board was not kept")
            assert(back.hireBoard.offers[2].hired, "the board forgot who was hired")
            assert(Hire.board(back).offers[2].id == p.hireBoard.offers[2].id, "a reload re-dealt the board")
        end,
    },
    {
        name = "a hire can be let go, and nobody else can",
        fn = function()
            local p = freshPlayer()
            local char = assert(Hire.hire(p, 1))
            local stash = #(p.stash or {})
            assert(Hire.dismiss(p, char.id), "a hire could not be dismissed")
            for _, c in ipairs(p.roster) do assert(c.id ~= char.id, "the dismissed hire is still here") end
            assert(#(p.stash or {}) > stash, "the dismissed hire's kit did not go back to the stash")
            for _, c in ipairs(p.roster) do
                assert(not Hire.dismiss(p, c.id), c.id .. " was dismissed, and only a hire may be")
            end
        end,
    },
    {
        name = "a hired body of another people can wear its race's item, which no companion can",
        fn = function()
            local Adventurers = require("models.adventurers")
            for race, byClass in pairs(Adventurers.RACE_ITEMS) do
                for class, itemId in pairs(byClass) do
                    local char = Character.instantiate(Hire.idOf(class, race, 9))
                    assert(Character.canCarry(char, Item.defs[itemId]),
                        "a hired " .. race .. " " .. class .. " cannot carry " .. itemId)
                end
            end
            local rowan = Character.instantiate("character_rowan")
            assert(not Character.canCarry(rowan, Item.defs.utility_mountains_root),
                "a human companion should not be able to carry a dwarf's item -- the gap hiring fills")
        end,
    },
    {
        -- THE ROSTER CAP (2026-10-23): the board opens on trip 3 now, and what waits on the Demon Lord is
        -- a ceiling of six bodies. Refused with a reason the panel prints; lifted once the Crown falls.
        name = "hiring is refused at six bodies until the Demon Lord falls, and uncapped after",
        fn = function()
            assert(Hire.ROSTER_CAP == 6, "the approved cap is six")
            local p = freshPlayer()
            p.campaignsFinished = 0
            while #p.roster < Hire.ROSTER_CAP do
                p.roster[#p.roster + 1] = Character.instantiate(Hire.idOf("knight", "human", 1000 + #p.roster))
            end
            assert(Hire.rosterFull(p), "six bodies is a full roster")
            assert(Hire.blockReason(p, 1) == Hire.FULL_REASON, "the board did not give the cap as its reason")
            local gold = p.gold
            local char, why = Hire.hire(p, 1)
            assert(not char and why == Hire.FULL_REASON, "a seventh body was hired before the Crown fell")
            assert(p.gold == gold, "a refused hire took the fee")
            assert(Hire.FULL_REASON:find("6") and Hire.FULL_REASON:find("Demon Lord"),
                "the reason does not say what the cap is or what lifts it")

            p.roster[#p.roster] = nil
            assert(not Hire.rosterFull(p) and Hire.hire(p, 1), "five bodies could not hire a sixth")

            p.campaignsFinished = 1
            assert(not Hire.rosterFull(p), "the cap outlived the Demon Lord")
            assert(Hire.hire(p, 2), "a seventh body was refused after the Crown fell")
        end,
    },
    {
        -- A SAVED STRAY DELVER JOINS AS A HIRE (2026-10-23): the same rolled body under the hire prefix,
        -- no fee, and the cap above holds for her too.
        name = "a saved delver joins as the same rolled body, free, inside the cap",
        fn = function()
            local Delver = require("models.delver")
            local delverId = Delver.idFor(777, 1)
            local hireId = Hire.delverId(delverId)
            assert(hireId and Hire.split(hireId), "a delver id does not map to a hire id")
            assert(Character.defs[hireId].name == Character.defs[delverId].name,
                "the hire is not the body that was saved")

            local p = freshPlayer()
            p.campaignsFinished = 0
            local gold = p.gold
            local char = assert(Hire.joinDelver(p, delverId))
            assert(char.id == hireId and char.hire, "she did not join as a hire")
            assert(p.gold == gold, "a saved delver charged a fee")
            assert(not Hire.joinDelver(p, delverId), "the same delver joined twice")
            assert(not Hire.joinDelver(p, "character_rowan"), "a non-delver id joined through the delver seam")

            while #p.roster < Hire.ROSTER_CAP do
                p.roster[#p.roster + 1] = Character.instantiate(Hire.idOf("mage", "elf", 2000 + #p.roster))
            end
            local none, why = Hire.joinDelver(p, Delver.idFor(778, 1))
            assert(not none and why == Hire.FULL_REASON, "a delver joined a full roster")
        end,
    },
    {
        -- WHO WALKED OUT ALIVE is counted off the combat before the mercy revive (states/battle.lua's
        -- win): a living party-side delver is saved; a fallen one, an enemy, or a bare id is not.
        name = "the survivors of a fight are the living delvers on the company's side",
        fn = function()
            local Delver = require("models.delver")
            local a, b = Delver.idFor(5, 1), Delver.idFor(5, 2)
            local combat = { units = {
                { side = "party", alive = true, char = { id = a } },
                { side = "party", alive = false, char = { id = b } },
                { side = "enemy", alive = true, char = { id = Delver.idFor(6, 1) } },
                { side = "party", alive = true, char = { id = "character_rowan" } },
                { side = "party", alive = true, char = { id = Delver.ID } },
            } }
            local out = Delver.survivors(combat)
            assert(#out == 1 and out[1] == a, "survivors read " .. table.concat(out, ","))
            assert(#Delver.survivors(nil) == 0, "no combat, no survivors")
        end,
    },
}
