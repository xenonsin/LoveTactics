-- Tests the prologue's DATA and model wiring (states/prologue.lua drives the flow; its love.graphics
-- side is verified in-window, not here). Proves the pieces the sequencer leans on exist and behave:
-- the avatar and companion blueprints, the recruit path, the avatar-name override, and the debut
-- quest's Saber objective. Headless, pure.

local Character = require("models.character")
local Player = require("models.player")
local Quest = require("models.quest")
local Conversation = require("models.conversation")

-- Every conversation the prologue plays, in order.
local PROLOGUE_SCENES = {
    "prologue_intro", "prologue_flee", "prologue_arrival",
    "prologue_arena", "prologue_victory",
}

return {
    {
        name = "the avatar blueprint loads: a class-less swordbearer named Stranger",
        fn = function()
            local avatar = Character.instantiate("character_avatar")
            assert(avatar.name == "Stranger", "the unnamed avatar is 'Stranger', got " .. tostring(avatar.name))
            assert(avatar.class == nil, "the avatar has no class (grows neutral)")
            -- It opens with a sword and only a sword (the tutorial drips the rest in).
            local weapons = 0
            for cell = 1, Character.MAX_INVENTORY do
                if avatar.inventory[cell] then weapons = weapons + 1 end
            end
            assert(weapons == 1, "the avatar starts with exactly one item, got " .. weapons)
        end,
    },
    {
        name = "the prologue's two recruits build the party through play",
        fn = function()
            local p = Player.new()
            -- Mirror prologue.begin: the roster is just the avatar to start.
            p.roster = { Character.instantiate("character_avatar") }
            p.party = { p.roster[1] }

            local rowan = Player.recruit(p, "character_knight")
            assert(rowan and rowan.name == "Rowan", "Rowan joins as the first recruit")
            local saber = Player.recruit(p, "character_saber")
            assert(saber and saber.name == "Saber", "Saber joins as the second recruit")
            assert(#p.party == 3, "avatar + two recruits are all deployed, got " .. #p.party)
        end,
    },
    {
        name = "the avatar can be named, and the name is what the roster shows",
        fn = function()
            local avatar = Character.instantiate("character_avatar")
            avatar.name = "Wend" -- what prologue.startNameEntry writes on submit
            assert(avatar.name == "Wend", "the typed name lands on the instance")
        end,
    },
    {
        name = "the debut quest's boss is Saber",
        fn = function()
            local def = Quest.defs["arena_debut"]
            assert(def, "arena_debut exists")
            local list = def.map.objective.composition({ prestige = 1 })
            local hasSaber = false
            for _, id in ipairs(list) do if id == "character_saber" then hasSaber = true end end
            assert(hasSaber, "the debut objective fields Saber")
            assert(def.map.objective.win.type == "killAll", "the debut is a killAll bout")
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
}
