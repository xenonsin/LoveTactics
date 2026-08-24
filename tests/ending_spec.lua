-- The ending: the last fight's scene, the route into the credits, the licence obligation the credits
-- carry, and New Game+.
--
-- WHERE THE ENDING LIVES MOVED, and these cases moved with it. It used to be a QUEST -- the Gate Below,
-- reached off the board on the fortieth day, carrying `endsCampaign` for states/game.lua to route on.
-- The board is cut and that quest with it. The ending is the Hollow Crown at the bottom of a descent
-- now, and the flag is `endsDescent` on the floor descriptor models/descent.lua synthesizes.
--
-- The reason most of this is pinned at all has not changed: the finale shipped for a long time with no
-- conversation of any kind and no post-game state, and nothing anywhere went red about it. A silent
-- boss and a game that stops mid-air are both perfectly valid data. So the cases below assert the
-- things that have no other alarm -- above all `Conversation.play` asserts on an unknown id, which
-- turns a typo into a crash at the exact moment a player finishes the game.

local Quest = require("models.quest")
local Player = require("models.player")
local Conversation = require("models.conversation")
local Save = require("models.save")
local Descent = require("models.descent")

-- The bottom floor's descriptor, which is what the Crown fight actually is.
local function crownFloor()
    local p = Player.new()
    local run = Descent.new(p)
    for _ = 2, Descent.FLOORS do Descent.advance(run) end
    return Descent.floorQuest(run, p)
end

return {
    {
        name = "the campaign has an ending, and the floor that is it says so rather than a known id",
        fn = function()
            local floor = crownFloor()
            assert(floor, "the descent should synthesize a bottom floor")
            assert(floor.endsDescent,
                "the deepest floor does not set endsDescent -- the game has no ending to route to")

            -- The Crown's only speaking seam is the objective's `opening`: by the time an outro would
            -- run, the target of an `assassinate` win is already dead.
            local opening = floor.map and floor.map.objective and floor.map.objective.opening
            assert(opening, "the last fight ends the game and plays no scene over it")
            assert(Conversation.defs[opening], "the ending names a missing scene: " .. tostring(opening))
        end,
    },
    {
        -- What states/game.lua routes on. It reads `endsDescent` off the quest it was handed, banks the
        -- win with Player.finishCampaign and switches to the credits -- so the flag has to survive onto
        -- the runtime descriptor, not merely exist somewhere in the model.
        name = "endsDescent reaches the runtime floor, so the ending can route off it",
        fn = function()
            local shallow = crownFloor()
            assert(shallow.endsDescent, "the bottom floor must carry the flag the router reads")

            -- ...and ONLY the bottom one, or a landing halfway down would roll the credits.
            local p = Player.new()
            local run = Descent.new(p)
            for depth = 1, Descent.FLOORS - 1 do
                local floor = Descent.floorQuest(run, p)
                assert(not floor.endsDescent,
                    "floor " .. depth .. " ends the game, and only the deepest may")
                Descent.advance(run)
            end
        end,
    },
    -- ("the final boss gets a voice -- the objective carries an opening scene" stood here, walked over
    -- every endsCampaign quest. The first case above asserts exactly that of the floor which IS the
    -- ending now, so it would be the same assertion twice.)
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
