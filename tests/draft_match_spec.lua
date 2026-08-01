-- Tests for models/draft_match.lua: the round opponent and the control-node battle setup. Pure logic
-- for everything but the battle-opts factory (which only names states lazily); runs headless.

local DraftMatch = require("models.draft_match")
local DraftRun = require("models.draft_run")
local DraftShop = require("models.draft_shop")
local Character = require("models.character")
local Item = require("models.item")

return {
    {
        name = "the control objective is a moving node with a tick limit",
        fn = function()
            local obj = DraftMatch.controlObjective()
            assert(obj.type == "control", "it is the contested control objective")
            assert(obj.maxTicks and obj.maxTicks > 0, "with a tick limit")
            assert(#obj.nodes >= 2 and obj.moveEvery > 0, "and a node that relocates across waypoints")
            -- The limit has to be short enough that outlasting it beats wiping the other side (which
            -- wins outright, Combat.outcomeFor), and long enough for the node to visit every waypoint.
            assert(obj.maxTicks == obj.moveEvery * #obj.nodes,
                "the round is exactly one circuit of the waypoints -- no more, no less")
            for _, node in ipairs(obj.nodes) do
                assert(#node > 0 and node[1].x and node[1].y, "each waypoint is a list of board tiles")
            end
        end,
    },
    {
        name = "a house bot is a real, drafted party grown to the round's power",
        fn = function()
            local run = DraftRun.new(5)
            run.round, run.wins = 4, 6
            DraftRun.addUnit(run, Character.instantiate("character_knight")) -- so party size is 1+
            local foes = DraftMatch.houseBot(run)
            assert(#foes >= 1, "there is an opponent")
            for _, c in ipairs(foes) do
                assert(Character.defs[c.id], "each foe is a real character: " .. tostring(c.id))
                assert((c.level or 1) == DraftMatch.botLevel(run), "grown to the round's bot level")
            end
        end,
    },
    {
        name = "the bot scales with wins, never past the unit ceiling",
        fn = function()
            local early = DraftRun.new(1); early.wins = 0
            local late = DraftRun.new(1); late.wins = 9
            assert(DraftMatch.botLevel(late) >= DraftMatch.botLevel(early), "more wins, tougher bot")
            local capped = DraftRun.new(1); capped.wins = 99
            assert(DraftMatch.botLevel(capped) <= DraftRun.MAX_UNIT_LEVEL, "never past the ceiling")
        end,
    },
    {
        name = "the bot's GEAR level scales with wins too, or the merge cascade outruns it",
        fn = function()
            -- Combining duplicates upgrades the gear the two copies share (DraftRun.mergeUnit), so a
            -- player's kit climbs past the round's shelf level. A bot pinned to that shelf falls behind.
            local early = DraftRun.new(1); early.round, early.wins = 6, 0
            local late = DraftRun.new(1); late.round, late.wins = 6, 9
            assert(DraftMatch.botGearLevel(early) == DraftShop.gearLevel(early.round),
                "with no wins it shops exactly where the player shops")
            assert(DraftMatch.botGearLevel(late) > DraftMatch.botGearLevel(early), "more wins, better gear")

            local capped = DraftRun.new(1); capped.round, capped.wins = 12, 99
            assert(DraftMatch.botGearLevel(capped) <= Item.MAX_LEVEL, "never past the item ceiling")
        end,
    },
    {
        name = "battle opts field the drafted party against the match on the control board",
        fn = function()
            local run = DraftRun.new(2)
            DraftRun.addUnit(run, Character.instantiate("character_mage"))
            local match = DraftMatch.find(run, {})
            local opts = DraftMatch.battleOpts(run, match, { chessClock = 90 })

            assert(opts.party[1].id == "character_mage", "the player's drafted unit takes the field")
            assert(opts.enemyChars == match.enemyChars, "against the matched opponent")
            assert(opts.quest.map.objective.win.type == "control", "on the control objective")
            assert(opts.draft == true and opts.chessClock == 90, "flagged as a draft battle with a clock")
        end,
    },
}
