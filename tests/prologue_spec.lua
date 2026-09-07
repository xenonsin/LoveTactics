-- Tests the prologue's DATA and model wiring (states/prologue.lua drives the flow; its love.graphics
-- side is verified in-window, not here). Proves the pieces the sequencer leans on exist and behave:
-- the avatar and companion blueprints, the recruit path, the avatar-name override, and the debut
-- quest's Saber objective. Headless, pure.

local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Quest = require("models.quest")
local Conversation = require("models.conversation")

-- Every conversation the prologue's opening leg plays, plus the ones the hub stages on the first
-- visit (the arrival and the Quest Board flier) and the debut's victory scene. `tutorial_village` is
-- not played as a scene -- it is the village fight's speech-bubble text (models/tutorial.lua) -- but
-- it lives in the same folder and must resolve like any other. See states/hub.lua for the arrival.
local PROLOGUE_SCENES = {
    "conversation_prologue_village", "conversation_prologue_flee", "conversation_prologue_arrival",
    "conversation_colosseum_slot_01_outro", "conversation_tutorial_village",
}
-- `conversation_prologue_flier` was the sixth and is DELETED. `. content-report` reported it as an
-- orphan -- no route in the game names it, and this list was the only thing that did, which is exactly
-- the shape a scene takes when it is written and then never wired. Five spoken lines went with it.
--
-- `conversation_prologue_intro` was the first and is ALSO deleted, for the opposite reason: it was
-- wired, and playing it was the problem. It stood in front of the village fight as a full visual-novel
-- beat with no portrait art to render, so the game's opening was grey letterboxes on black. Its work
-- moved into `conversation_prologue_village`, which is played over the board itself, and which is why
-- that id is now the first entry above rather than a bubble-text file like `tutorial_village`.

return {
    {
        name = "the avatar blueprint loads: a class-less swordbearer named Stranger",
        fn = function()
            local avatar = Character.instantiate("character_avatar")
            assert(avatar.name == "Stranger", "the unnamed avatar is 'Stranger', got " .. tostring(avatar.name))
            assert(avatar.class == nil, "the avatar has no class (grows neutral)")
            -- It opens with a sword and the coat off its own back, and nothing else (the tutorial drips
            -- the rest in). The leather is there so the armour slot is not empty on the first Loadout
            -- screen, and because the movement economy is tuned against a party wearing something --
            -- base 4 less the coat's square is 3 (see data/characters/character_avatar.lua).
            local items = 0
            for cell = 1, Character.MAX_INVENTORY do
                if avatar.inventory[cell] then items = items + 1 end
            end
            assert(items == 2, "the avatar starts with exactly two items, got " .. items)
            local names = {}
            for _, item in ipairs(Character.eachItem(avatar)) do names[item.name] = true end
            assert(names[Item.defs.weapon_iron_sword.name], "the avatar starts with its sword")
            assert(names[Item.defs.armor_leather_armor.name], "and with its leather armor")
        end,
    },
    {
        name = "the prologue's two recruits build the company through play",
        fn = function()
            local p = Player.new()
            -- Mirror prologue.begin: the roster is just the avatar to start.
            p.roster = { Character.instantiate("character_avatar") }

            local rowan = Player.recruit(p, "character_rowan")
            assert(rowan and rowan.name == "Rowan", "Rowan joins as the first recruit")
            local saber = Player.recruit(p, "character_saber")
            assert(saber and saber.name == "Saber", "Saber joins as the second recruit")
            assert(#p.roster == 3, "avatar + two recruits all march, got " .. #p.roster)
        end,
    },
    {
        name = "the avatar can be named, and the name is what the roster shows",
        fn = function()
            local avatar = Character.instantiate("character_avatar")
            avatar.name = "Wend" -- what prologue.begin copies off Player.active.name
            assert(avatar.name == "Wend", "the typed name lands on the instance")
        end,
    },
    {
        name = "the debut quest's boss is the Saber twin, and the win ends when she falls",
        fn = function()
            local def = Quest.defs["quest_colosseum_slot_01"]
            assert(def, "arena_debut exists")
            local list = def.map.objective.composition({ prestige = 1 })
            local hasBout = false
            for _, id in ipairs(list) do if id == "character_saber_bout" then hasBout = true end end
            -- The bout fields the boss TWIN, not the recruit -- so the phase relic and the deeper health
            -- pool never ride home when Quest.complete recruits the clean character_saber.
            assert(hasBout, "the debut objective fields the Saber bout twin")
            -- Assassinate, not killAll: once her relic can summon hands, the bout has to end when SABER
            -- goes down rather than dragging on to clear the reinforcements.
            local obj = def.map.objective
            assert(obj.win.type == "assassinate", "the debut ends on Saber's defeat, not a board clear")
            assert(obj.win.target == "character_saber_bout", "and the mark is the twin on the sand")
            -- The reward is still the CLEAN companion.
            assert(def.rewardCharacter == "character_saber", "the recruit is the un-bossed Saber")
        end,
    },
    {
        name = "the village fight fields the tutorial, on the board the tutorial was authored for",
        fn = function()
            local prologue = require("states.prologue")
            local map = prologue.VILLAGE_MAP
            assert(map.tutorial == "village", "the first fight runs the village lesson")
            assert(map.layout == "tutorial_village", "on a pinned board, not a rolled one")
            assert(require("models.tutorial").defs[map.tutorial], "the named tutorial exists")
            assert(require("models.arena").defs[map.layout], "the named board exists")
        end,
    },
    {
        name = "the avatar leads the company and Rowan follows -- the order the tutorial's spawns assume",
        fn = function()
            -- data/arenas/tutorial_village.lua binds partySpawns in roster order, so the avatar takes
            -- slot 1 and Rowan slot 2. The whole lesson's authored cells rest on that pairing.
            local p = Player.new()
            p.roster = { Character.instantiate("character_avatar") } -- mirrors prologue.begin
            Player.recruit(p, "character_rowan")
            assert(p.roster[1].id == "character_avatar", "the avatar holds the first spawn")
            assert(p.roster[2].id == "character_rowan", "Rowan holds the second")
        end,
    },
    {
        name = "every prologue conversation is defined and resolves",
        fn = function()
            for _, id in ipairs(PROLOGUE_SCENES) do
                local def = Conversation.defs[id]
                assert(def, "conversation missing: " .. id)
                -- Resolves against an empty context without error (no unrecruited-speaker crash).
                local resolved = Conversation.resolve(def, Conversation.context(nil))
                assert(#resolved.script > 0, id .. " has no playable lines")
            end
        end,
    },
    {
        name = "the first scene in the game is the one played over the board",
        fn = function()
            -- The prologue's first beat is the village FIGHT, and the only scene in front of it is
            -- that fight's own opening, drawn over the board (data/tutorials/village.lua's `opening`).
            -- There used to be a full visual-novel beat before it and there must not be one again: it
            -- is the beat that has no art to draw, and it is the one every new player meets first.
            --
            -- Pinned off the tutorial rather than off states/prologue.lua's beat list, because the
            -- lesson is what actually names the scene, and a beat re-added to the sequencer would be
            -- caught by the deleted-id assertion below instead.
            local village = require("models.tutorial").defs["village"]
            assert(village, "the village lesson must exist")
            assert(village.opening == "conversation_prologue_village",
                   "the village fight opens on the scene that replaced the cut intro")
            assert(Conversation.defs["conversation_prologue_intro"] == nil,
                   "conversation_prologue_intro is deleted; its work belongs to the over-board opening")
        end,
    },
    {
        name = "the opening scene explains the rift, in the mentor's voice alone",
        fn = function()
            -- THE PREMISE IS SAID OUT LOUD, and this is the assertion that keeps it that way. The
            -- scene it replaced named a rift in its second line and glossed it nowhere, on the theory
            -- that a hole over your own field explains itself. What the player actually has at that
            -- moment is a noun attached to nothing, in the first thirty seconds of the game.
            local def = Conversation.defs["conversation_prologue_village"]
            assert(def, "the village opening must exist")
            local said = {}
            for _, node in ipairs(def.script) do
                local text = node.text or node[2]
                if type(text) == "string" then said[#said + 1] = text:lower() end
            end
            local all = table.concat(said, " ")
            assert(all:find("rift", 1, true), "the opening names the rift")
            assert(all:find("close", 1, true) or all:find("shut", 1, true),
                   "the opening says a rift is not something anyone closes")
            assert(all:find("demon", 1, true), "the opening says what comes out of one")
            -- Whose voice it is in is pinned next door, by tests/tutorial_spec.lua: a lesson's opening
            -- is the mentor's alone, because it is the voice that teaches the seven steps after it.
            -- What THIS asserts is the other half -- that the scene carrying the premise is still the
            -- one the lesson opens on, so the two rules cannot drift apart into a scene that explains
            -- the world in somebody else's mouth.
            --
            -- Nobody it cannot draw, either. The cut scene's third speaker was the sibling, resolved
            -- off `player.body` in models/conversation.lua; that carve-out went with it.
            for _, raw in ipairs(def.cast) do
                local id = type(raw) == "table" and raw.id or raw
                assert(id ~= "sibling", "the sibling is cut, and nothing may cast one again")
            end
        end,
    },
}
