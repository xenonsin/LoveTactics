-- Tests for the party-join announcement: a recruit queues a "[<name> has joined your Party]" banner
-- that the next conversation to play folds onto its end (models/conversation.lua). This is the model
-- half only -- the banner's rendering is love.graphics-bound (ui/dialogue.lua) and not exercised here.
-- What is pinned below is the wiring that makes "any companion who joins is announced in a scene" hold:
-- Player.recruit queues, a refused duplicate does not, and drainJoins appends once and clears.

local Player = require("models.player")
local Conversation = require("models.conversation")

-- Start every case from an empty queue: it is module-global and other specs recruit too.
local function reset()
    for i = #Conversation.pendingJoins, 1, -1 do Conversation.pendingJoins[i] = nil end
end

return {
    {
        name = "recruiting a companion queues a pending join",
        fn = function()
            reset()
            local p = Player.new()
            local saber = Player.recruit(p, "character_saber")
            assert(saber, "the recruit should return an instance")
            assert(#Conversation.pendingJoins == 1, "the recruit should queue exactly one join")
            assert(Conversation.pendingJoins[1].name == saber.name, "the queued join names the recruit")
        end,
    },
    {
        name = "a refused duplicate recruit queues nothing",
        fn = function()
            reset()
            local p = Player.new()
            Player.recruit(p, "character_saber")
            local before = #Conversation.pendingJoins
            assert(Player.recruit(p, "character_saber") == nil, "a duplicate recruit is refused")
            assert(#Conversation.pendingJoins == before, "a refused recruit must not queue a join")
        end,
    },
    {
        name = "drainJoins appends one banner per join, at the end of the scene, and clears the queue",
        fn = function()
            reset()
            local p = Player.new()
            local saber = Player.recruit(p, "character_saber")
            local resolved = { script = { { by = "character_saber", text = "I'll follow." } } }
            Conversation.drainJoins(resolved)
            assert(#resolved.script == 2, "the banner should be appended after the authored line")
            local banner = resolved.script[2]
            assert(banner.system == true, "the appended node is a system banner")
            assert(banner.by == nil, "a system banner has no speaker")
            assert(banner.text == "[" .. saber.name .. " has joined your Party]",
                "the banner reads the recruit's name, got: " .. tostring(banner.text))
            assert(#Conversation.pendingJoins == 0, "the queue is drained after announcing")
        end,
    },
    {
        name = "drainJoins on an empty queue leaves the scene untouched",
        fn = function()
            reset()
            local resolved = { script = { { by = "character_knight", text = "We shall hold." } } }
            Conversation.drainJoins(resolved)
            assert(#resolved.script == 1, "no pending joins means no appended banner")
        end,
    },
    {
        name = "two recruits before a scene both get announced, in order",
        fn = function()
            reset()
            local p = Player.new()
            -- Both absent from the default starting roster, so neither recruit is refused as a duplicate.
            local a = Player.recruit(p, "character_saber")
            local b = Player.recruit(p, "character_amana")
            local resolved = { script = {} }
            Conversation.drainJoins(resolved)
            assert(#resolved.script == 2, "both joins should be announced")
            assert(resolved.script[1].text:find(a.name, 1, true), "first recruit announced first")
            assert(resolved.script[2].text:find(b.name, 1, true), "second recruit announced second")
        end,
    },
}
