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
    "prologue_intro", "prologue_flee", "prologue_arrival",
    "prologue_flier", "prologue_victory", "tutorial_village",
}

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
            avatar.name = "Wend" -- what prologue.begin copies off Player.active.name
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
        name = "the avatar leads the party and Rowan follows -- the order the tutorial's spawns assume",
        fn = function()
            -- data/arenas/tutorial_village.lua binds partySpawns in party order, so the avatar takes
            -- slot 1 and Rowan slot 2. The whole lesson's authored cells rest on that pairing.
            local p = Player.new()
            p.roster = { Character.instantiate("character_avatar") } -- mirrors prologue.begin
            p.party = { p.roster[1] }
            Player.recruit(p, "character_knight")
            assert(p.party[1].id == "character_avatar", "the avatar holds the first spawn")
            assert(p.party[2].id == "character_knight", "Rowan holds the second")
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
