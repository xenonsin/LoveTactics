-- Tests for HOW ACT 0 ENDS: the Champion stands on the way out, and killing it opens a road rather
-- than cutting to the city.
--
-- THE SHAPE IS THE DESCENT'S, borrowed on purpose. A circle's guardian stands on its stair and dying
-- OPENS it (models/descent.lua's Descent.openStair) instead of descending on the killing blow, because
-- winning must not take the rest of the board out of the player's hands. Act 0 ends the same way, for
-- a reason of its own: the kill is where the company reaches level 2 (prologue.EXIT_LEVEL), and a leg
-- that cut to the city on that frame had nowhere to put the level-up, the newly-opened class screen,
-- or the coach line pointing at it. Back on the map there is a board to stand on and time to read.
--
-- What is pinned here is the CONTRACT between the three pieces -- the objective's declaration, the
-- gate it opens, and the stop it leaves behind -- rather than any one of their implementations.

local prologue = require("states.prologue")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Player = require("models.player")

-- The Champion's objective, off the exported quest rather than by reaching into the state's locals --
-- the same reason prologue.FLIGHT_QUEST is exported at all (tests/flight_leg_spec.lua). It hangs off
-- the quest's `map`, which is the table states/game.lua reads the leg out of.
local function championObjective()
    return (prologue.FLIGHT_QUEST.map or {}).objective
end

return {
    {
        name = "the Champion stands on the way out rather than ending the leg",
        fn = function()
            local obj = championObjective()
            assert(obj, "the flight quest should carry an objective")
            assert(obj.win and obj.win.target == "character_demon_champion_tutorial",
                "the objective under test should be the Champion's")
            assert(obj.opensExit, string.format(
                "the Champion's objective must declare `opensExit` -- without it states/game.lua "
                .. "calls the prologue's onComplete on the killing blow and Act 0 cuts straight to "
                .. "the city, which is the beat this whole arrangement exists to stop"))
            assert(obj.opensExit.kind == "road",
                "the way out is a road stop, got " .. tostring(obj.opensExit.kind))
            assert(type(obj.opensExit.name) == "string" and #obj.opensExit.name > 0,
                "the road has to name itself -- it is a marker the player walks back to")
        end,
    },

    {
        name = "the road is a stop the board knows how to describe",
        fn = function()
            -- A kind that reaches a board without a sentence is a marker the player can only read by
            -- walking onto it, which is the failure Encounter.GLOSS exists to prevent. Asked through
            -- the same lookup the map's hover readout and the step's modal both use.
            local said = Encounter.gloss({ kind = "road" })
            assert(said and #said > 0, "the road stop has no gloss, so neither surface can say what it is")

            local listed = false
            for _, kind in ipairs(Encounter.MARKER_KINDS) do
                if kind == "road" then listed = true end
            end
            assert(listed, "`road` is missing from Encounter.MARKER_KINDS, so the gloss sweep skips it")
        end,
    },

    {
        name = "the class screen waits for the city: Act 0 opens nothing, the Champion included",
        fn = function()
            -- IT USED TO OPEN AT THE CHAMPION (2026-10-16 to 2026-10-23), when the trip down was for the
            -- class requirements. Act 0 now banks nothing toward a class (`classCredit = false`), and the
            -- avatar's first class is Rowan's recommendation, picked in the city (states/hub.lua) -- so
            -- the only thing that opens the tab is reaching the town.
            local p = Player.new()
            p.cityReached, p.classesOpen = nil, nil
            assert(not Descent.classesUnlocked(p), "the Roll must be shut through Act 0")
            Descent.markCityReached(p)
            assert(Descent.classesUnlocked(p), "reaching the city opens the Roll")
        end,
    },

    {
        name = "the tab's window is its own ledger, and still resolves",
        fn = function()
            local Locale = require("models.locale")
            for _, id in ipairs({ "classes_title", "classes_body" }) do
                local text = Locale.line("conversation_tutorial_notes", id)
                assert(type(text) == "string" and #text > 0,
                    id .. " resolves to nothing -- the window would open blank")
            end
            -- TWO LEDGERS, AND THEY ARE NOT THE SAME QUESTION: "the tab exists" and "the lesson behind
            -- it has been read". Conflating them would open the tab already silent.
            local p = Player.new()
            p.cityReached, p.classesOpen, p.classesTaught = nil, nil, nil
            Descent.markCityReached(p)
            assert(not Descent.classesTaught(p),
                "opening the tab must not silently count as having read its lesson")
            Descent.markClassesTaught(p)
            assert(Descent.classesTaught(p), "reading the window spends the tab's pip")
        end,
    },

    {
        name = "the road owes the avatar its first class: prologue fights are flagged classCredit = false",
        fn = function()
            -- Read off the source, because the flag rides two launch sites the suite cannot play: the
            -- village fight (states/prologue.lua) and every fight on the flight leg (states/game.lua,
            -- keyed off Act 0's xpCap). A site that loses it teaches a class in Act 0 again.
            local function src(path)
                local f = assert(io.open(path, "r"), "cannot read " .. path)
                local text = f:read("*a"); f:close(); return text
            end
            assert(src("states/prologue.lua"):find("classCredit = false", 1, true),
                "the village fight must bank no class")
            assert(src("states/game.lua"):find("classCredit = not game.xpCap", 1, true),
                "the flight leg's fights must bank no class")
            assert(not src("states/game.lua"):find("markClassesOpen", 1, true),
                "the Champion must not open the Roll")
        end,
    },

    {
        name = "the guild's counter: the arrival casts the attendant, the horn is carried home and handed over",
        fn = function()
            local Vendor = require("models.vendor")
            local Material = require("models.material")
            assert(Vendor.defs.guild and Vendor.defs.guild.sells == false,
                "the guild attendant is a keeper without a shelf (data/vendors/guild.lua)")
            assert(Material.get("material_champion_horn"), "the Champion's horn is a material")

            local scene = require("data.conversations.prologue.conversation_prologue_arrival")
            local cast = {}
            for _, id in ipairs(scene.cast) do cast[id] = true end
            assert(cast.guild and cast.character_rowan and cast.character_avatar,
                "the arrival is the attendant, Rowan and the avatar")
            assert(scene.script[#scene.script][1] == "guild",
                "it ends on the attendant, because the forced pick follows on the next frame")

            local function src(path)
                local f = assert(io.open(path, "r"), "cannot read " .. path)
                local text = f:read("*a"); f:close(); return text
            end
            assert(src("states/prologue.lua"):find("Player.addMaterial(Player.active, prologue.HORN_ID, 1)", 1, true),
                "the Champion's fall must hand over the horn")
            assert(src("states/hub.lua"):find("spendMaterials(hub.player, { material_champion_horn = 1 })", 1, true),
                "the arrival must take the horn as proof")
            assert(src("states/gate.lua"):find('Keeper.draw("guild"', 1, true),
                "the attendant stands behind the Gate's counter")
        end,
    },

    {
        name = "every prologue fight opens on a scene, and the floor's fights stand off the door",
        fn = function()
            local prologue = require("states.prologue")
            local Conversation = require("models.conversation")
            local Tutorial = require("models.tutorial")
            local function exists(id) return id and Conversation.defs[id] ~= nil end

            assert(exists((Tutorial.defs[prologue.VILLAGE_MAP.tutorial] or {}).opening),
                "the village fight opens on a scene")
            local quest = prologue.FLIGHT_QUEST
            assert(exists(quest.map.objective.opening), "the Champion opens on a scene")
            local prowl = quest.map.encounters.prowl
            assert(#prowl == 2, "floor one deals two rescue fights")
            for _, e in ipairs(prowl) do
                assert(exists(e.opening), e.id .. " must open on a scene of its own")
            end
            -- Where the author placed them on the floor (2026-10-23): the first 12 steps from the door,
            -- the second 8 past it. Fewer is the "too close to the entrance" that was reported twice.
            assert(prowl[1].after >= 12, "the first fight must not find the company near the door")
            assert(prowl[2].after >= 8, "and the second must not follow straight on from the first")
        end,
    },
}
