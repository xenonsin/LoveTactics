-- The debut's aftermath leg: after the bout is won, arena_debut hands off to a short scripted overworld
-- walk (its inline `followUp`) where Saber catches the party at the gate out and asks in. This pins the
-- data wiring states/game.lua leans on -- the meet objective, its join scene, and the held-then-drained
-- join banner -- so the flow can't rot without a test going red. Headless, pure. See
-- data/quests/arena_debut.lua, data/conversations/arena_saber_joins.lua, states/game.lua.

local Quest = require("models.quest")
local Player = require("models.player")
local Character = require("models.character")
local Conversation = require("models.conversation")

local JOIN_SCENE = "arena_saber_joins"

local function clearJoins()
    for i = #Conversation.pendingJoins, 1, -1 do Conversation.pendingJoins[i] = nil end
end

return {
    {
        name = "the debut still earns Saber, and hands off to a scripted follow-up leg",
        fn = function()
            local def = Quest.defs["arena_debut"]
            assert(def, "arena_debut exists")
            assert(def.rewardCharacter == "character_saber", "Saber is still the debut's reward")
            local leg = def.followUp
            assert(type(leg) == "table", "the debut carries an inline followUp leg")
            assert(leg.map and leg.map.scripted, "the leg is scripted (no Back button, no abandon)")
        end,
    },
    {
        name = "the follow-up leg ends on a non-combat meeting that plays the join scene",
        fn = function()
            local obj = Quest.defs["arena_debut"].followUp.map.objective
            assert(obj.meet, "the objective is a non-combat meeting, not a fight")
            assert(obj.conversation == JOIN_SCENE, "reaching it plays Saber's join scene")
            -- A meeting objective needs no composition (there is no battle); a stray one would mean the
            -- leg was authored as a fight by mistake.
            assert(obj.composition == nil, "a meeting objective fields no opponents")
        end,
    },
    {
        name = "the aftermath leg never lands on the Quest Board (it is inline, not a board quest)",
        fn = function()
            -- Only files under data/quests/ are registered in Quest.defs; the leg is a nested table, so
            -- no board id resolves to it. Prove the meeting is unreachable as a standalone quest.
            for id, q in pairs(Quest.defs) do
                local o = q.map and q.map.objective
                assert(not (o and o.meet), "a board quest should never carry a meet objective: " .. id)
            end
        end,
    },
    {
        name = "the join scene is defined, resolves, and casts the whole party",
        fn = function()
            local def = Conversation.defs[JOIN_SCENE]
            assert(def, "the join conversation exists")
            local cast = {}
            for _, entry in ipairs(def.cast or {}) do
                cast[type(entry) == "table" and entry.id or entry] = true
            end
            assert(cast["character_saber"], "Saber speaks")
            assert(cast["character_avatar"], "the avatar is addressed")
            assert(cast["character_knight"], "Rowan is present")
            local resolved = Conversation.resolve(def, Conversation.context(nil))
            assert(#resolved.script > 0, "the scene has playable lines")
        end,
    },
    {
        name = "Saber's held join banner drains onto the meeting scene",
        fn = function()
            clearJoins()
            local p = Player.new()
            p.roster = { Character.instantiate("character_avatar") }
            p.party = { p.roster[1] }
            -- The debut recruits her; the arena outro holds the banner (deferJoins) so it lands here.
            local saber = Player.recruit(p, "character_saber")
            assert(saber, "Saber recruited")
            assert(#Conversation.pendingJoins == 1, "exactly one join is waiting to be announced")

            local resolved = Conversation.resolve(Conversation.defs[JOIN_SCENE], Conversation.context(p))
            local before = #resolved.script
            Conversation.drainJoins(resolved)
            assert(#resolved.script == before + 1, "the banner is appended to the scene")
            local banner = resolved.script[#resolved.script]
            assert(banner.system, "the appended node is a system banner")
            assert(banner.text == "[" .. saber.name .. " has joined your Party]",
                "the banner names the recruit, got: " .. tostring(banner.text))
            assert(#Conversation.pendingJoins == 0, "the queue is drained after the meeting")
            clearJoins()
        end,
    },
}
