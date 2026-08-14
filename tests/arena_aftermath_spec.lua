-- The debut's aftermath leg: after the bout is won, arena_debut hands off to a short scripted overworld
-- walk (its inline `followUp`) where Saber catches the party at the gate out and asks in. This pins the
-- data wiring states/game.lua leans on -- the meet objective, its join scene, and the held-then-drained
-- join banner -- so the flow can't rot without a test going red. Headless, pure. See
-- data/quests/colosseum/quest_colosseum_slot_01.lua, data/conversations/arena_saber_joins.lua, states/game.lua.

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
        name = "the debut still earns Saber, and hands off to a scripted follow-up leg",
        fn = function()
            local def = Quest.defs["quest_colosseum_slot_01"]
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
            local obj = Quest.defs["quest_colosseum_slot_01"].followUp.map.objective
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

    -- THE PADDED CARD'S AFTERMATH. Slot 2 has no outro at all: its killing is not narrated after the
    -- fight, it IS the fight (the objective's `overrule` walks Ira onto the board the moment the win
    -- would be declared, and the party is wiped by her). So the only scene on the far side is the
    -- `epilogue`, which plays over the black frame the fight fades to and opens in the Cathedral, where
    -- the acolyte who raised them asks to come along. Same rule underneath as the debut's meeting: the
    -- recruit is announced in the scene the author put her in, never the one before it.
    {
        name = "the padded card earns Amana, and hands off to an epilogue scene",
        fn = function()
            local def = Quest.defs["quest_colosseum_slot_02"]
            assert(def, "the padded card exists")
            assert(def.rewardCharacter == "character_amana",
                "Amana is recruited at the revival, not in the Cathedral's own line")
            assert(def.outro == nil, "there is no outro: the fight's own ending is the scene before it")
            assert(def.epilogue == "conversation_colosseum_slot_02_join", "the waking is the epilogue")
            assert(def.followUp == nil, "there is no overworld leg before it")
            assert(Conversation.defs[def.epilogue], "the epilogue scene is defined")
        end,
    },
    -- THE OVERRULE, as data. The whole beat hangs off this block: without it the last carded killer
    -- falling is an ordinary victory and Ira never walks out at all. Pinned here rather than trusted to
    -- a pair of ids typed into two files -- states/battle.lua's battle.fireOverrule reads every field
    -- below by name, and a rename on either side is silent otherwise.
    {
        name = "the padded card's win is overruled by Ira, who cannot be killed",
        fn = function()
            local def = Quest.defs["quest_colosseum_slot_02"]
            local win = def.map.objective.win
            assert(win.protect == "character_survivor", "the refugees are the protect while it is a bout")
            local ov = win.overrule
            assert(ov, "the win is overruled")
            assert(ov.composition[1] == "character_general_wrath", "the house sends its patron")
            assert(Character.defs[ov.composition[1]], "and she is a real blueprint")
            assert(ov.scene == "conversation_colosseum_slot_02_overrule", "she is announced over the board")
            assert(Conversation.defs[ov.scene], "the overrule scene is defined")
            assert(ov.fell == "character_survivor", "the refugees go down as that scene closes")
            assert(ov.unkillable == "character_general_wrath",
                "a scripted loss the party can fight their way out of is not a scripted loss")
            assert(ov.win and ov.win.protect == nil,
                "the protect goes with the objective it belonged to, or felling the refugees reads as a defeat")
            assert(ov.win.text, "the banner says what is on the sand rather than naming a target")
        end,
    },
    {
        name = "Amana's banner is held across the overrule scene and lands on the waking",
        fn = function()
            clearJoins()
            local p = Player.new()
            p.roster = { Character.instantiate("character_avatar") }
            local amana = Player.recruit(p, "character_amana")
            assert(amana, "Amana recruited")

            -- states/battle.lua plays the overrule scene with deferJoins, which is what keeps a recruit
            -- out of the scene before everyone dies.
            local ov = Conversation.resolve(Conversation.defs["conversation_colosseum_slot_02_overrule"],
                Conversation.context(p))
            local ovLines = #ov.script
            assert(#Conversation.pendingJoins == 1, "the join is still waiting after that scene resolves")

            local waking = Conversation.resolve(Conversation.defs["conversation_colosseum_slot_02_join"],
                Conversation.context(p))
            local before = #waking.script
            Conversation.drainJoins(waking)
            assert(#waking.script == before + 1, "the banner is appended to the waking scene")
            assert(waking.script[#waking.script].text == "[" .. amana.name .. " has joined your Party]",
                "the banner names her")
            assert(ovLines > 0, "the overrule scene still has its own lines")
            clearJoins()
        end,
    },
    {
        name = "the Cathedral's door and its line both wait on the padded card",
        fn = function()
            -- The player is carried into that building; they do not walk into it. Both gates read the
            -- same quest so the shop and the work arrive on the scene that opens them.
            local Building = require("models.building")
            local cathedral = Building.defs["cathedral"]
            assert(cathedral.unlockQuest == "quest_colosseum_slot_02", "the door waits on the revival")
            assert(Quest.defs["quest_cathedral_slot_01"].requiredQuests[1] == "quest_colosseum_slot_02",
                "so does the first job behind it")
            -- And she is no longer recruited inside her own line, which would hand the player a second
            -- copy of a companion they already have.
            for id, q in pairs(Quest.defs) do
                if id ~= "quest_colosseum_slot_02" then
                    assert(q.rewardCharacter ~= "character_amana",
                        "only the padded card recruits Amana, found another: " .. id)
                end
            end
        end,
    },
}
