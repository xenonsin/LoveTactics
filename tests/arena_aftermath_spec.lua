-- The debut's aftermath leg: after the bout is won, arena_debut hands off to a short scripted overworld
-- walk (its inline `followUp`) where Saber catches the party at the gate out and asks in. This pins the
-- data wiring states/game.lua leans on -- the meet objective, its join scene, and the held-then-drained
-- join banner -- so the flow can't rot without a test going red. Headless, pure. See
-- data/quests/colosseum/quest_colosseum_slot_01.lua, data/conversations/arena_saber_joins.lua, states/game.lua.

-- THE QUEST BLUEPRINTS ARE GONE, AND SO IS WHAT THEY WERE COVERING. data/quests was deleted
-- with the seven house postings (92ff549d), which took companion recruitment, the market's openers,
-- Saber's debut and every `slot_01` with it. The cases below had no data left to run against and
-- were removed on 2026-09-23 rather than left red. Each one is listed so the hole is findable:
--
--   * the debut still earns Saber, and hands off to a scripted follow-up leg
--   * the follow-up leg ends on a non-combat meeting that plays the join scene
--
-- Nothing above is a rule that was decided against; it is coverage that lost its subject. When the
-- replacement for the postings lands, these are the cases it owes back.

local Quest = require("models.quest")
local Player = require("models.player")
local Character = require("models.character")
local Conversation = require("models.conversation")

local JOIN_SCENE = "conversation_colosseum_slot_01_join"

local function clearJoins()
    for i = #Conversation.pendingJoins, 1, -1 do Conversation.pendingJoins[i] = nil end
end

return {
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
            assert(cast["character_rowan"], "Rowan is present")
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

    -- THE PADDED CARD IS GONE. Four cases stood below this line -- that quest_colosseum_slot_02 earned
    -- Xin and handed off to an epilogue, that its win was overruled by an unkillable Ira, that Xin's
    -- join banner survived the overrule scene and landed on the waking, and that the Cathedral's first
    -- job waited on the revival that introduced her.
    --
    -- Slot 2 was reachable only through the Quest Board and went with it. What that costs is worth
    -- writing down rather than quietly losing: Xin has no recruit scene any more, and the beat where
    -- a company is wiped on the sand and wakes on a Cathedral ceiling is not played by anything. She is
    -- met at the Cathedral's own posting like the other six companions (models/vendor_visit.lua reads each
    -- house's `companion`), so the character is reachable and the SCENE is what was lost.
    --
    -- The overrule mechanic itself is not lost with her: data/quests carries it as an objective field
    -- and tests/overrule_spec.lua pins the engine half.
}
