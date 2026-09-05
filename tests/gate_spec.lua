-- Tests for models/gate.lua and the pieces of the descent that only mean anything because there is a
-- town at the top of the stair: the bones the surface sets for free, the pack a wipe leaves behind, and
-- the floors a company keeps.
--
-- Driven through the models rather than states/gate.lua, which cannot run headless. What is pinned here
-- is every decision underneath that screen.

local Descent = require("models.descent")
local Gate = require("models.gate")
local Player = require("models.player")
local Save = require("models.save")
local Wound = require("models.wound")

local function reserialize(data)
    return Save.decode("return " .. Save.encode(data, 0))
end

-- A descent company with `n` bodies on it, at a known purse.
local function company(n, gold)
    local Character = require("models.character")
    local chars = {}
    for i = 1, (n or 1) do
        chars[i] = Character.instantiate(i == 1 and "character_knight" or "character_archer")
        -- Distinct ids per body would need distinct blueprints; two is enough for every case here and
        -- the roster only ever holds one of each (Player.recruit refuses a duplicate).
    end
    local p = Descent.newProfile(chars)
    p.gold = gold or 1000
    return p
end

-- A bare floor to seat markers on: every tile open trail, nothing standing on any of them. Built
-- through Overworld.fromSnapshot rather than the generator because what is under test is where a marker
-- lands, and a rolled board would put its own stops in the way of the answer.
local function board(cols, rows)
    local Overworld = require("models.overworld")
    local cells = {}
    for y = 1, rows do
        cells[y] = {}
        for x = 1, cols do cells[y][x] = { tile = "path" } end
    end
    return Overworld.fromSnapshot({
        cols = cols, rows = rows, tilesetId = "forest", start = { x = 1, y = 1 }, cells = cells,
    })
end

-- The tile the marker for `pile` is actually drawn on, or nil if the board has none.
local function markerOf(grid, pile)
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local e = grid.cells[y][x].encounter
            if e and e.kind == "pack" and e.drop == pile then return grid.cells[y][x] end
        end
    end
    return nil
end

return {
    { name = "reaching a town sets every bone, free and unasked", fn = function()
        -- THE LAW THE INN BROKE. A cost on recovery is a tax on needing to recover, and a wipe wounds
        -- the whole expedition by construction -- so the company least able to pay was always the one
        -- handed the bill (models/wound.lua, docs/the-count.md). What replaces it is scope: a wound
        -- lasts the expedition it was taken on, and the two town screens end it on the way in.
        --
        -- Driven through Wound.clear + Player.restore in that order, which is exactly the pair
        -- states/hub.lua and states/gate.lua each run at their door. Order is load-bearing: clear first,
        -- or the refill fills to a wounded ceiling that is about to stop existing.
        local p = company(1, 0) -- and NO GOLD, which is the whole point: recovery is not for sale
        local char = p.roster[1]
        for _ = 1, 3 do Wound.inflict(p, { char }) end
        char.stats.health.current = 1
        assert(Wound.count(p, char.id) == 3, "precondition: somebody is badly hurt")

        local mended = Wound.clear(p)
        Player.restore(p)
        assert(#mended == 1 and mended[1] == char.id, "the clear names who it set")
        assert(Wound.count(p, char.id) == 0, "and left nothing on the ledger")
        assert(char.woundShare == nil, "nor any reserve stamped on the body")
        assert(char.stats.health.current == char.stats.health.max,
            "and the refill fills the WHOLE pool, not the wounded ceiling it walked in with")
        assert(p.gold == 0, "and it took nothing to do it")
    end },

    { name = "a town tops up what a body holds, never what it drank", fn = function()
        -- COMING HOME TOPS UP THE BODY, NOT THE PACK. Health, mana and stamina are what the fighting
        -- SPENT out of a person and what resting gives back; a flask is a thing that was owned and is
        -- now gone, and a town that refilled it would be handing out free consumables to anyone who
        -- walked in -- which would make buying any of them a mistake.
        --
        -- Pinned here because nothing in Player.restore names consumables, so the rule holds today only
        -- by not being written down. The DRAFT mode does restock between rounds (models/draft_run.lua),
        -- which is right there and is exactly the edit that could arrive here by analogy.
        local Character, Item = require("models.character"), require("models.item")
        local p = company(1, 1000)
        local char = p.roster[1]
        Character.addItem(char, Item.instantiate("consumable_healing_potion", 3))

        local flask
        for _, item in ipairs(Character.eachItem(char)) do
            if item.id == "consumable_healing_potion" then flask = item end
        end
        assert(flask, "precondition: the body is carrying a draught")
        flask.quantity = 1
        char.stats.health.current = 1

        Wound.clear(p)
        Player.restore(p)
        assert(char.stats.health.current == char.stats.health.max,
            "precondition: an unwounded body tops all the way up, so this case ran a real rest")
        assert(flask.quantity == 1, "coming home refilled the flask: the town is now the cheapest " ..
            "shelf in the game")
    end },

    -- TEN PILE CASES STOOD HERE AND ARE DELETED WITH THE FEATURE THEY GUARDED. A wipe dropped a guarded
    -- pack on the tile the party fell on; these pinned every edge of it -- picked up exactly once, two
    -- deaths on one tile merging, a pile sliding off a tile that was already a fight, the guard drawn
    -- once and kept so the second attempt was the same fight, a pack taken by id so a marker rebuilt
    -- after a save still found its pile.
    --
    -- None of it survives, because a wipe no longer takes anything to drop: the company wakes at the
    -- Gate holding what it was holding, and the bill is two marks on the count (models/descent.lua's
    -- COUNT_WIPE). Deleting the cases with the code is the honest move -- a spec kept alive against a
    -- feature nobody can reach is a green tick for a promise the game does not make.
    --
    -- What this file still guards is everything a wipe did NOT stop doing: the town setting bones, the
    -- floors a company keeps, and the rift closing behind both exits alike.
    { name = "coming back to a floor wakes its fights and nothing else", fn = function()
        -- THE MAZE IS PERMANENT, THE MONSTERS ARE NOT -- Wizardry's own split, and the reason its floors
        -- stay dangerous forever. Without it a floor a company had finished is an empty corridor and the
        -- walk back to a dropped pack costs nothing but time.
        --
        -- What must NOT wake is anything that was a PLACE: waking a beaten general would un-earn the
        -- boon her circle already paid, and re-sealing a found door would delete the point of keeping
        -- the floor at all.
        local Overworld = require("models.overworld")
        local p = company(1, 0)
        local run = Descent.new(p, 21)
        local mp = Descent.floorQuest(run, p).map
        local grid = Overworld.generate({
            biome = mp.biome, cols = mp.cols, rows = mp.rows, layout = mp.carve, spacing = mp.spacing,
            seed = 21, ascent = true, keyCount = 0,
            encounterCount = mp.encounters, cacheCount = mp.cacheCount,
            encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
            secrets = mp.secrets, exitAtStart = mp.exitAtStart,
        })

        -- Walk the whole floor: everything cleared, every door found.
        local fights, places = 0, 0
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local c = grid.cells[y][x]
                c.secret = nil
                if c.encounter then
                    c.cleared = true
                    if c.encounter.kind == "combat" or c.encounter.kind == "elite" then
                        fights = fights + 1
                    else
                        places = places + 1
                    end
                end
            end
        end
        assert(fights > 0 and places > 0, "precondition: the floor holds both kinds")

        local woken = Descent.rearmFloor(grid)
        assert(woken >= fights, "every fight is on its feet again, got " .. woken .. " of " .. fights)

        local stillUp, stillSpent = 0, 0
        for y = 1, grid.rows do
            for x = 1, grid.cols do
                local c = grid.cells[y][x]
                if c.encounter then
                    local fight = c.encounter.kind == "combat" or c.encounter.kind == "elite"
                    if fight and not c.cleared then stillUp = stillUp + 1 end
                    if not fight and c.cleared then stillSpent = stillSpent + 1 end
                    if not fight then
                        assert(c.cleared, c.encounter.kind ..
                            " woke up: a place is not an inhabitant, and a beaten general must stay beaten")
                    end
                end
                assert(not c.secret, "a found door re-sealed itself")
            end
        end
        assert(stillUp == fights, "the fights are the ones standing")
        assert(stillSpent == places, "and the places are the ones still spent")
    end },

    { name = "a company keeps the floors it has walked", fn = function()
        -- A Wizardry floor is the SAME maze every time, which is the whole reason mapping one is worth
        -- doing -- a secret door found on the third trip is something you found rather than something
        -- that was rolled. A board cannot be rebuilt from its seed here (Overworld:snapshot says why),
        -- so keeping a floor means literally keeping it.
        local Overworld = require("models.overworld")
        local p = company(1, 0)
        local run = Descent.new(p, 21)
        local mp = Descent.floorQuest(run, p).map

        local grid = Overworld.generate({
            biome = mp.biome, cols = mp.cols, rows = mp.rows, layout = mp.carve, spacing = mp.spacing,
            seed = 21, ascent = true, keyCount = 0,
            encounterCount = mp.encounters, cacheCount = mp.cacheCount,
            encounters = { { kind = "combat", weight = 1 } },
        })
        grid:reveal(grid.start.x, grid.start.y, 3)
        assert(Descent.floorBoard(run, 1) == nil, "a floor never walked is not kept")

        Descent.keepFloor(run, 1, grid:snapshot())
        assert(Descent.floorBoard(run, 1), "the floor is kept once it is left")
        assert(Descent.floorBoard(run, 2) == nil, "and only the one that was left")

        -- KEYED BY STRING, deliberately: a numeric key round-trips through the encoder as a string on
        -- some paths and an integer on others, so a board stored under 3 and looked up under "3" would
        -- silently re-roll every floor after a load -- exactly the bug this feature exists to prevent,
        -- and invisible until somebody notices their map is gone.
        local back = Descent.restore(reserialize(Descent.snapshot(run)))
        assert(Descent.floorBoard(back, 1), "and the board survives a save under the same key")
        local restored = Overworld.fromSnapshot(Descent.floorBoard(back, 1))
        assert(restored.cols == grid.cols and restored.rows == grid.rows, "as the same board")
        assert(restored:startCell().seen, "with the fog the company lifted still lifted")
    end },

    { name = "a wipe puts the floor away like every other way off it", fn = function()
        -- WHY THIS IS WRITTEN AGAINST THE SOURCE. There are three routes off a floor -- the stair down,
        -- the way up, and a wipe -- and all three are branches inside states/game.lua, the last of them
        -- a closure hanging off a battle panel's `onLoss`. None can be reached from a headless spec, so
        -- the invariant is stated where it CAN be checked: the branch that sends a wiped company up to
        -- the Gate keeps its board on the way.
        --
        -- It shipped without one, and the shape of the miss is the reason for the tripwire: the other
        -- routes all kept their board, so the feature worked everywhere anybody looked. What a
        -- wipe did instead was roll a fresh floor N for the walk back -- against a Gate that had just
        -- promised "they are still there, and so is everything they were carrying", with the pile
        -- seated onto the new ground by the coordinates it fell on (states/game.lua's markBodies), so
        -- the thing the company came back for could be standing inside a wall.
        local src = assert(love.filesystem.read("states/game.lua"), "should be able to read the state")

        -- The nearest `onLoss` above the switch that carries `wiped`, which brackets the branch without
        -- pinning a line number that every edit to the file would move.
        local function lastBefore(needle, pos)
            local at, from = nil, 1
            while true do
                local i = src:find(needle, from, true)
                if not i or i > pos then break end
                at, from = i, i + 1
            end
            return at
        end

        local switch = src:find("wiped = floor", 1, true)
        assert(switch, "nothing sends a wiped company to the Gate any more -- retarget this case")
        local branch = src:sub(lastBefore("onLoss = ", switch) or 1, switch)

        -- THE RIFT CLOSES ON A WIPE, so there is no board to keep and this looked for `keepFloor`
        -- until it did. Both exits reset now, and the symmetry is the load-bearing half: if dying kept
        -- the floor stack and leaving did not, a company standing deep with a thin haul would be
        -- better off letting itself be killed.
        --
        -- WHAT MUST SURVIVE INSTEAD IS THE BILL, and that is what this case guards now. It guarded the
        -- pile for a while -- the Gate promised a wiped company that everything they were carrying was
        -- still down there, and a wipe that dropped a pack into a run it then threw away would have
        -- broken that promise silently. Piles are deleted; the company simply keeps its things.
        --
        -- So what a wipe must not lose is the only cost it has left. Two marks, against the stair's
        -- one: if the branch stopped charging them, dying would become the cheaper way home -- it
        -- happens where the company stands and the stair has to be walked back to -- and the game's
        -- best move would be to loot until threatened and then throw the fight.
        assert(branch:find("Descent.countBy(game.player, Descent.COUNT_WIPE)", 1, true),
            "a wipe charges nothing at all: with no pack to drop and no cut to take, an uncharged " ..
            "rout is a free ride home and dying becomes the optimal exit")

        -- ...and the run itself is let go, or the next descent would resume the one that just ended.
        assert(branch:find("descentRun = nil", 1, true),
            "a wipe leaves the closed rift on the player, so the next dive resumes a dead expedition")
    end },
}
