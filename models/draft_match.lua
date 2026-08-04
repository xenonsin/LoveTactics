-- Draft-mode matchmaking + battle setup: who you face each round, and the board you face them on.
--
-- The round is fought on a MULTIPLAYER-ONLY map whose objective is a moving score node (the `control`
-- objective, models/combat.lua): each side banks a point per tick it solely holds the node, the node
-- relocates on a schedule, and the higher score at the tick limit wins. This module authors that
-- objective and hands states/battle.lua the opts to switch into, the same shape ui/panels/pvp.lua's
-- findMatch builds -- but WITHOUT Build normalization, because a draft is decided by the levels and
-- gear you drafted, and flattening both sides to level 1 would erase the whole point of the mode.
--
-- The opponent seam (DraftMatch.find) returns a party of live enemy character instances. v1 synthesizes
-- a round-scaled "house bot" drafted from the same pool, so the loop is playable with nobody else
-- online; a stored other-player build (async) or a live opponent (lockstep) slot in AHEAD of the house
-- bot behind this one function later, exactly as the plan's Phase B describes. Pure model except for the
-- battle-opts factory, which names states by require path only when called.
--
-- The bot drafts the way the PLAYER drafts, and that symmetry is load-bearing: its units are stripped to
-- their chassis (models/draft_chassis.lua) and then armed round-by-round off the same run shelf. Break
-- either half -- leave the bot its blueprint kit, or let it shop a pool the player cannot reach -- and
-- the ladder stops measuring the player's draft.

local Character = require("models.character")
local Item = require("models.item")
local Growth = require("models.growth")
local Combat = require("models.combat")
local Arena = require("models.arena")
local DraftRun = require("models.draft_run")
local DraftShop = require("models.draft_shop")
local DraftChassis = require("models.draft_chassis")

local DraftMatch = {}

-- ---------------------------------------------------------------------------
-- The control-node board
-- ---------------------------------------------------------------------------

-- The battle's tick limit and how often the node hops: the node walks its three waypoints once (30 / 10)
-- and the fight is over. Short on purpose. At the 240 this started on, the limit was so far out that
-- WIPING the other side -- which wins outright, Combat.outcomeFor -- was simply the faster way to end a
-- round, and the node was scenery. At 30 the objective is the clock, so a kill has to be worth the
-- tempo it costs. A tick is elapsed INITIATIVE (Combat.rebase), not a turn: at ordinary weapon speeds a
-- round of 30 is a handful of turns each, so a unit that walks to the node instead of hunting is
-- spending a real fraction of the match on it.
DraftMatch.MAX_TICKS = 30
DraftMatch.MOVE_EVERY = 10

-- The score node's waypoints on the 8x8 board (Arena.COLS/ROWS): a 2x2 cluster that hops center ->
-- toward the far (enemy) side -> toward the near (party) side, so neither team can camp it and both
-- must cross open ground to contest each hop. Authored in board coords directly; the control objective
-- reads obj.nodes as-is (no region resolution), so these ARE the tiles fought over.
local function cluster(cx, cy)
    return { { x = cx, y = cy }, { x = cx + 1, y = cy }, { x = cx, y = cy + 1 }, { x = cx + 1, y = cy + 1 } }
end

function DraftMatch.controlObjective()
    return {
        type = "control",
        maxTicks = DraftMatch.MAX_TICKS,
        moveEvery = DraftMatch.MOVE_EVERY,
        nodes = {
            cluster(4, 4), -- center
            cluster(4, 2), -- toward the far edge
            cluster(4, 6), -- toward the near edge
        },
    }
end

-- ---------------------------------------------------------------------------
-- The opponent
-- ---------------------------------------------------------------------------

-- The level a house bot's units are drafted at for a run this deep, and how much of the bench it
-- fields: it tracks the player's wins so the challenge climbs with the run rather than sitting still.
function DraftMatch.botLevel(run)
    return math.min(DraftRun.MAX_UNIT_LEVEL, 1 + math.floor((run.wins or 0) / 2))
end

-- A synthesized opponent party, drafted from the same pool the player draws from and grown to the
-- round's power. Deterministic from the run's seed + wins, so a given run faces a reproducible ladder.
-- Returns a list of live, AI-run character instances (their control is set enemy-side by Combat.new).
-- How many pieces of gear the bot hangs on each of its units in `round`. The player's binding constraint
-- is GRID SLOTS, not gold: the cumulative budget through round 5 is ~70g against 3g gear, so a player
-- who bought four units still has change for far more gear than eight free cells can hold. So the bot's
-- count tracks the ROUND, not a wallet. It trails by one because the player also pays for rerolls, for
-- duplicates chased for a merge, and for the units themselves.
--
-- A first guess, and the knob most likely to move after play-testing -- the strip took three to eight
-- items off every unit on both sides, and where that leaves the matchup is a question for the board.
function DraftMatch.gearPerUnit(round)
    return math.max(0, math.min(Character.MAX_INVENTORY, (round or 1) - 1))
end

-- What LEVEL that gear is at. The shelf's offered level is the floor -- the bot shops where the player
-- shops -- but the player has a second lane the bot does not: combining duplicate units now cascades
-- into the grid and upgrades the gear the two copies share (DraftRun.mergeUnit), and stash merges push
-- pieces further still, so a player's kit can climb past the round's shelf level while the bot's never
-- would. So wins fold in here the way they already do in botLevel, and now at the SAME rate: a gear
-- merge asks for a second copy of the same id, no harder to land than the unit merge botLevel tracks,
-- and every copy is flatly one level (DraftRun.canMergeItems). The rate was half that while gear also
-- had to match LEVELS -- a binary tree, in which a third duplicate bought nothing at all.
--
-- A first guess and a play-test knob, exactly like gearPerUnit above it.
function DraftMatch.botGearLevel(run)
    local base = DraftShop.gearLevel(run.round)
    return math.min(Item.MAX_LEVEL, base + math.floor((run.wins or 0) / 2))
end

function DraftMatch.houseBot(run)
    local pool = DraftRun.pool(run.round)
    if #pool == 0 then return {} end
    local rng = Combat.newRandom((run.rngSeed or 1) * 31 + (run.wins or 0) * 101 + 17)

    local level = DraftMatch.botLevel(run)
    local size = math.min(DraftRun.PARTY_MAX, math.max(1, #DraftRun.party(run)))
    local gearIds = DraftShop.gearCandidates(run)
    local gearLevel = DraftMatch.botGearLevel(run)
    local gearCount = DraftMatch.gearPerUnit(run.round)

    local chars = {}
    for i = 1, size do
        -- Stripped to a chassis exactly as a shop-bought unit is (models/draft_chassis.lua). This is not
        -- optional politeness: the player's units lose three to eight blueprint items to the strip, so a
        -- bot still wearing its whole authored kit would win the match on that alone.
        local char = DraftChassis.instantiate(pool[rng(#pool)])
        Growth.resolve(char, level) -- grown exactly as a drafted, merged unit would be
        -- Then arm it the way the round's shopping would have: round-scaled pieces off the same run
        -- shelf the player is buying from, into the cells the strip just emptied.
        for _ = 1, gearCount do
            if #gearIds == 0 or not Character.firstEmptySlot(char) then break end
            Character.addItem(char, Item.instantiate(gearIds[rng(#gearIds)], nil, gearLevel))
        end
        chars[i] = char
    end
    return chars
end

-- Who the player faces this round. v1 always returns the house bot; a stored or live opponent slots in
-- ahead of this later (Phase B). Returns { enemyChars, author = { name } }.
function DraftMatch.find(run, player)
    return {
        enemyChars = DraftMatch.houseBot(run),
        author = { name = "House Bot -- Round " .. (run.round or 1) },
    }
end

-- ---------------------------------------------------------------------------
-- Battle setup
-- ---------------------------------------------------------------------------

-- The opts to State.switch(states.battle, ...) with: the player's DRAFTED party (not normalized), the
-- matched opponent as the far side, and the control objective on a neutral board. `callbacks.onWin` /
-- `callbacks.onLoss` fire from Combat.evaluate exactly as a campaign fight's do. `chessClock` (seconds
-- per side) rides along for states/battle.lua to run its real-time flag-fall on top of the tick model.
function DraftMatch.battleOpts(run, match, callbacks)
    callbacks = callbacks or {}
    local author = (match and match.author) or {}
    return {
        encounter = { kind = "objective" },
        biome = "castle",
        -- Draft units keep the levels and gear they were drafted with -- see the file header on why
        -- this fight is deliberately NOT normalized. `prestige` only scales the arena's own flavor.
        prestige = run.round or 1,
        party = DraftRun.party(run),
        -- Seat the party by the marching formation the player arranged (front row faces the enemy).
        -- Pre-resolved {col,row} slots parallel to `party`, not an id-map -- draft can field two
        -- un-merged duplicates whose shared id would collide in an id-keyed map (see models/draft_run).
        formationSlots = DraftRun.formationSlots(run),
        formationCols = DraftRun.FORMATION_COLS,
        formationRows = DraftRun.FORMATION_ROWS,
        -- No deployment phase: draft already made that decision, in the shop, on its own grid -- and it
        -- is a timed match against another team, which is no place to re-open a placement screen.
        deploy = false,
        enemyChars = (match and match.enemyChars) or {},
        chessClock = callbacks.chessClock, -- seconds per side; nil = untimed (states/battle.lua default)
        draft = true,                      -- marks this as a draft battle (PvP HUD: scores + clocks)
        -- The battle purse over the run's own wallet, so a drafted money ability (The Gilded Wound) can
        -- spend real run gold in-fight and the debug Add gold tool funds it. This gold is discarded at
        -- round end anyway (DraftRun.advanceRound), so spending it mid-fight banks nothing. See the purse
        -- block in states/battle.lua.
        purse = {
            get = function() return run.gold or 0 end,
            spend = function(n) DraftRun.spend(run, math.min(n or 0, run.gold or 0)) end,
            add = function(n) DraftRun.addGold(run, n) end,
        },
        quest = { map = { biome = "castle", objective = {
            name = author.name or "A rival draft",
            win = DraftMatch.controlObjective(),
        } } },
        onWin = callbacks.onWin,
        onLoss = callbacks.onLoss,
    }
end

return DraftMatch
