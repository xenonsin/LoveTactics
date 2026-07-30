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

local Character = require("models.character")
local Item = require("models.item")
local Growth = require("models.growth")
local Combat = require("models.combat")
local Arena = require("models.arena")
local DraftRun = require("models.draft_run")
local DraftShop = require("models.draft_shop")

local DraftMatch = {}

-- ---------------------------------------------------------------------------
-- The control-node board
-- ---------------------------------------------------------------------------

-- The battle's tick limit and how often the node hops. Six hops over the fight (240 / 40), so a match
-- is a handful of contests over ground that keeps moving, not one long standoff on a fixed tile.
DraftMatch.MAX_TICKS = 240
DraftMatch.MOVE_EVERY = 40

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
function DraftMatch.houseBot(run)
    local pool = DraftRun.pool(run.round)
    if #pool == 0 then return {} end
    local rng = Combat.newRandom((run.rngSeed or 1) * 31 + (run.wins or 0) * 101 + 17)

    local level = DraftMatch.botLevel(run)
    local size = math.min(DraftRun.PARTY_MAX, math.max(1, #DraftRun.party(run)))
    local gearIds = DraftShop.gearCandidates(run.round)
    local gearLevel = DraftShop.gearLevel(run.round)

    local chars = {}
    for i = 1, size do
        local char = Character.instantiate(pool[rng(#pool)])
        Growth.resolve(char, level) -- grown exactly as a drafted, merged unit would be
        -- Arm it like a shop-bought unit would be: one round-scaled weapon in an empty grid cell, if
        -- the round has any gear to hand out. Bound relics on a generic are none, so nothing is displaced.
        if #gearIds > 0 and Character.firstEmptySlot(char) then
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
        enemyChars = (match and match.enemyChars) or {},
        chessClock = callbacks.chessClock, -- seconds per side; nil = untimed (states/battle.lua default)
        draft = true,                      -- marks this as a draft battle (PvP HUD: scores + clocks)
        quest = { map = { biome = "castle", objective = {
            name = author.name or "A rival draft",
            win = DraftMatch.controlObjective(),
        } } },
        onWin = callbacks.onWin,
        onLoss = callbacks.onLoss,
    }
end

return DraftMatch
