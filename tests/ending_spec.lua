-- The ending: the finale's two scenes, the route off the board into the credits, the licence
-- obligation the credits carry, and New Game+.
--
-- The reason most of this is pinned at all: the finale shipped for a long time with no conversation of
-- any kind and no post-game state, and nothing anywhere went red about it. A silent boss and a game
-- that stops mid-air are both perfectly valid data. So the cases below assert the things that have no
-- other alarm -- above all `Conversation.play` asserts on an unknown id, which turns a typo in a quest
-- into a crash at the exact moment a player finishes the game.

local Quest = require("models.quest")
local Conversation = require("models.conversation")
local Player = require("models.player")
local Save = require("models.save")

-- The campaign-ending quest, found by its flag rather than by id -- the same way states/game.lua finds
-- it. If a second ending is ever authored this case covers it too, and if the flag is dropped the
-- first case below fails loudly.
local function endingQuests()
    local out = {}
    for id, def in pairs(Quest.defs) do
        if def.endsCampaign then out[#out + 1] = { id = id, def = def } end
    end
    return out
end

return {
    {
        name = "the campaign has an ending, and it is a quest that says so rather than a known id",
        fn = function()
            local endings = endingQuests()
            assert(#endings > 0, "no quest sets endsCampaign -- the game has no ending to route to")
            for _, q in ipairs(endings) do
                assert(q.def.outro, q.id .. " ends the campaign but plays no closing scene")
                assert(Conversation.defs[q.def.outro],
                    q.id .. " names a missing outro: " .. tostring(q.def.outro))
            end
        end,
    },
    {
        -- The Crown's only speaking seam. `intro` plays over the hub before the party is even picked,
        -- and by the time `outro` runs an assassinate target is dead, so if the objective carries no
        -- `opening` the final boss cannot say anything at all.
        name = "the final boss gets a voice -- the objective carries an opening scene",
        fn = function()
            for _, q in ipairs(endingQuests()) do
                local objective = q.def.map and q.def.map.objective
                assert(objective, q.id .. " has no objective")
                assert(objective.opening,
                    q.id .. "'s boss fights in silence: the objective names no opening scene")
                assert(Conversation.defs[objective.opening],
                    q.id .. " names a missing opening: " .. tostring(objective.opening))
            end
        end,
    },
    {
        -- A general guard, not specific to the ending: Conversation.play raises on an unknown id, so a
        -- dead reference anywhere on the board is a crash the player finds before any test does.
        name = "every scene any quest names actually exists",
        fn = function()
            local missing = {}
            for id, def in pairs(Quest.defs) do
                local named = {
                    intro = def.intro,
                    outro = def.outro,
                    opening = def.opening,
                    objectiveOpening = def.map and def.map.objective and def.map.objective.opening,
                }
                for field, convo in pairs(named) do
                    if convo and not Conversation.defs[convo] then
                        missing[#missing + 1] = id .. "." .. field .. " -> " .. convo
                    end
                end
            end
            assert(#missing == 0, "quests name scenes that do not exist: " .. table.concat(missing, ", "))
        end,
    },
    {
        -- The flag has to survive the blueprint -> runtime copy in Quest.available, or the route in
        -- states/game.lua never fires and the finale quietly walks back to the hub.
        name = "endsCampaign reaches the runtime quest, so the ending can route off the board",
        fn = function()
            local endings = endingQuests()
            local target = endings[1]

            local player = Player.new()
            -- Clear its gate. For the finale that is the CALENDAR, not a set of keys: he arrives on the
            -- last day whichever generals are still alive (models/calendar.lua). Any other
            -- `endsCampaign` quest still clears its prerequisites the old way.
            if target.def.finale then
                player.day = require("models.calendar").DAYS
            end
            for _, questId in ipairs(target.def.requiredQuests or {}) do
                player.completedQuests[questId] = true
            end

            local found
            for _, quest in ipairs(Quest.available(player)) do
                if quest.id == target.id then found = quest end
            end
            assert(found, target.id .. " is not offered to a player who has cleared its gate")
            assert(not found.locked, target.id .. " is still locked with every key held")
            assert(found.endsCampaign,
                "endsCampaign was dropped by Quest.available -- the finale would return to the hub")
        end,
    },
    {
        -- Attribution is a CONDITION of the icons' CC BY 3.0 licence and is owed to players, not to the
        -- repository (see docs/credits-icons.md). Every generated author must reach the roll; an
        -- artist silently dropped is a licence breach, not a cosmetic bug.
        name = "the credits roll carries the whole game-icons attribution",
        fn = function()
            local credits = require("states.credits")
            local def = require("data.credits")
            local icons = require("data.credits_icons")

            local lines = credits.buildLines(def, icons)
            local text = {}
            for _, entry in ipairs(lines) do
                if entry.text then text[#text + 1] = entry.text end
            end
            local blob = table.concat(text, "\n")

            assert(#icons.authors > 0, "the generated attribution names no authors")
            for _, author in ipairs(icons.authors) do
                assert(blob:find(author.name, 1, true),
                    "icon artist missing from the credits roll: " .. author.name)
            end
            assert(blob:find(icons.licence, 1, true), "the roll does not name the licence")
            assert(blob:find(icons.url, 1, true), "the roll does not name where the icons came from")
        end,
    },
    {
        -- Same tolerance models/sprite.lua shows a missing image: a build whose generated attribution
        -- has not been written yet still rolls, rather than crashing on the last screen of the game.
        name = "the roll survives a build with no generated attribution",
        fn = function()
            local credits = require("states.credits")
            local lines = credits.buildLines(require("data.credits"), nil)
            assert(#lines > 0, "an authored roll with no icon data came out empty")
            assert(credits.totalHeight(lines) > 0, "the roll has no height to scroll")
        end,
    },
    {
        name = "New Game+ puts the ladder back and keeps the company that climbed it",
        fn = function()
            local player = Player.new()
            player.prestige = 12
            player.gold = 4321
            player.completedQuests = { quest_colosseum_slot_10 = true, quest_the_gate_below = true }
            player.visitedVendors = { bastion = true }
            player.pendingSummary = { "stale" }
            local rosterSize = #player.roster

            Player.newGamePlus(player)

            assert(player.ngPlus == 1, "the first carry-forward should read as New Game+ 1")
            -- Clearing the completed-quest ledger is the whole reset: the board refills, the Gate re-locks,
            -- and -- because a vendor's standing IS its finished-quest count -- every shelf drops back to
            -- its opening stock.
            assert(next(player.completedQuests) == nil,
                "completed quests survived -- the board would still be empty, the Gate open, and every quest-gated shelf still unlocked")
            assert(player.prestige == 12, "prestige must carry: it is the company's level")
            assert(player.gold == 4321, "gold must carry")
            assert(#player.roster == rosterSize, "the roster must carry -- these are the same people")
            assert(player.visitedVendors.bastion, "shop intros should not replay on a second run")
            assert(player.pendingSummary == nil, "the last run's advancement overlay must not follow")
        end,
    },
    {
        name = "a second New Game+ counts up rather than resetting",
        fn = function()
            local player = Player.new()
            Player.newGamePlus(player)
            Player.newGamePlus(player)
            assert(player.ngPlus == 2, "expected New Game+ 2, got " .. tostring(player.ngPlus))
        end,
    },
    {
        -- Purely additive, so Save.VERSION deliberately does not move (see models/save.lua). That makes
        -- the round trip the only thing standing between a finished campaign and a forgotten one.
        name = "the New Game+ count survives a save round trip",
        fn = function()
            local player = Player.new()
            player.ngPlus = 3
            local restored = Save.restore(Save.snapshot(player))
            assert(restored, "the snapshot did not restore")
            assert(restored.ngPlus == 3, "expected 3, got " .. tostring(restored.ngPlus))
        end,
    },
    {
        name = "a save from before New Game+ loads as a first run rather than as nil",
        fn = function()
            local player = Player.new()
            local snap = Save.snapshot(player)
            assert(snap.ngPlus == nil, "a run that never finished should not write the field at all")

            local restored = Save.restore(snap)
            assert(restored, "the snapshot did not restore")
            assert(restored.ngPlus == 0, "an absent count must read as 0, got " .. tostring(restored.ngPlus))
        end,
    },
}
