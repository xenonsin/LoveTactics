-- Tests for models/gate.lua and the pieces of the descent that only mean anything because there is a
-- town at the top of the stair: the inn that sets bones, the pack a wipe leaves behind, and the floors a
-- company keeps.
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
    { name = "a night at the inn gives back what the fighting cost, and sets no bone", fn = function()
        -- The inn is the ONLY mender a descent has: wounds cap healing for the rest of a body's life
        -- (models/wound.lua) and nothing underground sets one. Both halves for one bill, because a
        -- four-body company with no bench cannot field around a wounded member.
        local p = company(1, 1000)
        local char = p.roster[1]
        Wound.inflict(p, { char })
        char.stats.health.current = 1
        assert(Wound.count(p, char.id) > 0, "precondition: somebody is wounded")

        local before = p.gold
        assert(Gate.rest(p), "the company can afford a room")
        assert(p.gold < before, "and it is paid for")
        assert(Wound.count(p, char.id) > 0, "a bed is not a surgeon: the wound is still there")
        assert(char.stats.health.current == math.floor(char.stats.health.max * Wound.healShare(p, char.id)),
            "and they top up to their WOUNDED ceiling and no further -- which used to be an ordering " ..
            "hazard this function worked around, and is now the honest result")
    end },

    { name = "an inn that cannot be paid for changes nothing", fn = function()
        local p = company(1, 0)
        local char = p.roster[1]
        Wound.inflict(p, { char })
        char.stats.health.current = 1

        local ok, why = Gate.rest(p)
        assert(not ok and why == "gold", "the room is refused for want of gold")
        assert(Wound.count(p, char.id) > 0, "and nothing was set")
        assert(char.stats.health.current == 1, "and nobody was healed on credit")
    end },

    { name = "a night gives back what a body holds, never what it drank", fn = function()
        -- A NIGHT TOPS UP THE BODY, NOT THE PACK. Health, mana and stamina are what the fighting SPENT
        -- out of a person and what sleeping gives back; a flask is a thing that was owned and is now
        -- gone, and an inn that refilled it would be handing out free consumables at twenty-five gold a
        -- head -- cheaper than the shelf that sells them, and enough to make buying any of them a
        -- mistake.
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

        assert(Gate.rest(p), "the company can afford a room")
        assert(char.stats.health.current == char.stats.health.max,
            "precondition: an unwounded body tops all the way up, so this case ran a real night")
        assert(flask.quantity == 1, "a night refilled the flask: the inn is now the cheapest shelf in " ..
            "the game")
    end },

    { name = "a wipe drops the pack where it fell, and it is picked up exactly once", fn = function()
        -- DARK SOULS' BLOODSTAIN, and the only thing standing between "climb out" and "die" being the
        -- same move. The bodies always come back -- they wake at the temple, wounded -- so what has to
        -- be at stake is everything they were carrying, and it stays on the tile until somebody walks
        -- back down to it.
        --
        -- Snapshotted on the way in, never live instances: an instance can hold loaded images and
        -- Save.encode raises on userdata, so a pack kept live would take the save down the first time a
        -- company wiped. The encode assertion below is the one that catches it.
        local Item = require("models.item")
        local p = company(1, 0)
        local run = Descent.new(p, 3)

        local dropped = {
            Item.instantiate("consumable_healing_potion"),
            Item.instantiate("weapon_iron_sword"),
        }
        Descent.dropPack(run, 4, 7, 9, dropped)
        assert(#Descent.dropsOn(run, 4) == 1, "the pack lies on the floor it was dropped on")
        assert(#Descent.dropsOn(run, 5) == 0, "and on no other")

        local ok = pcall(Save.encode, Descent.snapshot(run), 0)
        assert(ok, "a run carrying a dropped pack still serialises")

        local entry = Descent.dropsOn(run, 4)[1]
        local back = Descent.takePack(run, entry)
        assert(back and #back == 2, "picking it up gives back everything in it")
        assert(back[1].id == "consumable_healing_potion", "as the same items")
        assert(#Descent.dropsOn(run, 4) == 0, "and the floor is clear")
        assert(Descent.takePack(run, entry) == nil,
            "a pack cannot be taken twice -- walking the tile again must not mint a second copy of " ..
            "everything the company owned")
    end },

    { name = "a dropped pack rides out in the run's own snapshot", fn = function()
        local Item = require("models.item")
        local p = company(1, 0)
        local run = Descent.new(p, 11)
        Descent.dropPack(run, 2, 5, 5, { Item.instantiate("consumable_healing_potion") })

        local back = Descent.restore(reserialize(Descent.snapshot(run)))
        assert(back.drops and #back.drops == 1, "the pack comes back with the run")
        assert(back.drops[1].floor == 2 and back.drops[1].x == 5,
            "still on the floor and the tile it was dropped on")
        local items = Descent.takePack(back, Descent.dropsOn(back, 2)[1])
        assert(items and #items == 1, "and is still recoverable after the round trip")
    end },

    { name = "a second death leaves a second pile, and the first is still lying where it fell", fn = function()
        -- THE ONE-PILE RULE IS GONE, and this pins its absence rather than merely not testing it,
        -- because what it did was permanent: dropping a pack destroyed the last one wherever it was
        -- lying, so a bad night on the way back deleted the kit of the night before it. That was Dark
        -- Souls' bloodstain, borrowed from a game where the thing on the ground is a FLOW -- souls come
        -- back by playing. Down here it is kit, kit comes off the floors, and the Gate store sells
        -- draughts, so the deleted pile was something the save could never mint again.
        --
        -- What stops the player simply walking back is a FIGHT now (see the guard case below).
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)

        Descent.dropPack(run, 3, 4, 4, { Item.instantiate("weapon_iron_sword") })
        assert(#Descent.dropsOn(run, 3) == 1, "the first pile is on floor 3")

        Descent.dropPack(run, 6, 9, 9, { Item.instantiate("consumable_healing_potion") })
        assert(#Descent.dropsOn(run, 3) == 1, "and it is STILL on floor 3 after the second death")
        assert(#Descent.dropsOn(run, 6) == 1, "with the second lying on floor 6")
        assert(#(run.drops or {}) == 2, "two deaths, two piles")

        local back = Descent.takePack(run, Descent.dropsOn(run, 3)[1])
        assert(back[1].id == "weapon_iron_sword", "the older pile still holds what was dropped in it")
        assert(#Descent.dropsOn(run, 6) == 1, "and taking one leaves the other where it is")
    end },

    { name = "two deaths on ONE tile merge, because one mistake is one walk", fn = function()
        -- The company went down together, in a heap, and twice on the same square is the same heap.
        -- Different tiles are different piles; the same tile is one pile that got bigger -- which is
        -- also one marker and one guard rather than two of each side by side.
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)

        Descent.dropPack(run, 3, 4, 4, { Item.instantiate("weapon_iron_sword") })
        Descent.dropPack(run, 3, 4, 4, { Item.instantiate("consumable_healing_potion") })
        assert(#Descent.dropsOn(run, 3) == 1, "one pile on the tile, not two")

        local pile = Descent.dropsOn(run, 3)[1]
        assert(pile.count == 2, "holding both deaths' worth, got " .. tostring(pile.count))
        local back = Descent.takePack(run, pile)
        assert(#back == 2, "and it hands over everything in it")
    end },

    { name = "a pile is on the map, and one that fell on a fight slides off it rather than vanishing",
      fn = function()
        -- THE CASE THIS EXISTS FOR IS THE COMMON ONE. A company wipes at a FIGHT; the fight was lost, so
        -- its stop is still armed; the pile lands on a tile that is already spoken for. A marker must
        -- never be drawn over another stop -- it would delete the thing underneath, and the way up is
        -- one of the things it could land on -- so for as long as that was the whole rule, the pack sat
        -- on the run bookkept and INVISIBLE, and the one thing the mode asks you to walk back down for
        -- was a coordinate nobody was ever shown.
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)
        local grid = board(5, 5)
        grid:get(3, 3).encounter = { kind = "combat", name = "The thing that killed you" }

        Descent.dropPack(run, 2, 3, 3, { Item.instantiate("weapon_iron_sword") })
        assert(Descent.markPacks(run, grid, 2) == 1, "the pile is marked")

        assert(grid:get(3, 3).encounter.kind == "combat",
            "and the fight is still standing on its own tile -- the marker never overwrites a stop")

        local pile = Descent.dropsOn(run, 2)[1]
        local cell = markerOf(grid, pile)
        assert(cell, "there is a marker on the board for it")
        assert(math.abs(cell.x - 3) + math.abs(cell.y - 3) == 1,
            "one step from where they fell, not across the floor")
        assert(pile.x == cell.x and pile.y == cell.y,
            "and the run says the pile is where the marker is, so it does not move again next visit")
        assert(cell.encounter.composition == pile.guardIds, "the guard drawn at the wipe is standing on it")
        assert(cell.encounter.id, "and it names a blueprint for the fiction")
    end },

    { name = "a marked pile is lifted off the board when it is picked up", fn = function()
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)
        local grid = board(5, 5)

        Descent.dropPack(run, 1, 2, 2, { Item.instantiate("weapon_iron_sword") })
        Descent.markPacks(run, grid, 1)
        local pile = Descent.dropsOn(run, 1)[1]
        assert(pile.x == 2 and pile.y == 2, "an empty tile seats the marker where they fell")

        -- Twice over: re-entering a floor must not walk the pile one tile further every time.
        Descent.markPacks(run, grid, 1)
        assert(pile.x == 2 and pile.y == 2, "and a second pass leaves it exactly there")
        assert(markerOf(grid, pile), "with one marker on it")

        Descent.takePack(run, pile)
        assert(Descent.markPacks(run, grid, 1) == 0 and not markerOf(grid, pile),
            "and taking it up takes the marker with it")
    end },

    { name = "two piles that want one tile get a tile each", fn = function()
        -- Only reachable because a pile slides: both of these fell on the same fight, on either side of
        -- a save. They cannot merge (dropPack matches on the tile, and the first pile is no longer on
        -- it), so what must not happen is the second one seating on top of the first and being lost.
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)
        local grid = board(5, 5)
        grid:get(3, 3).encounter = { kind = "combat", name = "The thing that killed you twice" }

        Descent.dropPack(run, 2, 3, 3, { Item.instantiate("weapon_iron_sword") })
        Descent.markPacks(run, grid, 2)
        Descent.dropPack(run, 2, 3, 3, { Item.instantiate("consumable_healing_potion") })
        assert(#Descent.dropsOn(run, 2) == 2, "precondition: two piles, because the first one moved")

        assert(Descent.markPacks(run, grid, 2) == 2, "both are marked")
        local a, b = Descent.dropsOn(run, 2)[1], Descent.dropsOn(run, 2)[2]
        assert(not (a.x == b.x and a.y == b.y), "on tiles of their own")
        assert(markerOf(grid, a) and markerOf(grid, b), "and both markers are on the board")
    end },

    { name = "a pile is guarded, and what is standing on it is drawn to how much was spilled", fn = function()
        -- DELETING A LIMITER OBLIGES YOU TO NAME ITS REPLACEMENT. The one-pile rule answered "what stops
        -- the player simply walking back" with a threat to erase what they were walking back for; the
        -- guard answers it with a fight, and prices that fight off the SIZE OF THE PILE rather than off
        -- the depth. So the pack a company leaves on its first bad night draws the circle's own vermin,
        -- and the pack a full company leaves on floor twelve is being worn by somebody else by the time
        -- anyone comes back for it.
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)

        local small = {}
        for _ = 1, 3 do small[#small + 1] = Item.instantiate("consumable_healing_potion") end
        local pile = Descent.dropPack(run, 3, 4, 4, small)
        assert(pile.guard == "drawn",
            "a small pile draws the floor's own small things, got " .. tostring(pile.guard))
        assert(pile.guardIds and #pile.guardIds > 0, "and something is actually standing there")

        local big = {}
        for _ = 1, Descent.PACK_COMPANY_ITEMS do big[#big + 1] = Item.instantiate("weapon_iron_sword") end
        local rich = Descent.dropPack(run, 7, 2, 2, big)
        assert(rich.guard == "scavengers",
            "a company's worth of kit draws a company, got " .. tostring(rich.guard))
        assert(rich.guardIds and #rich.guardIds >= 3, "a rival company is a company, not a body")

        -- A CAST IS PLAIN DATA, which is the whole reason it is resolved at the wipe rather than at the
        -- marker: Save.encode raises on a function value, so a composition closure here would take the
        -- save write down the first time somebody died (models/descent.lua's `drops` note).
        assert(pcall(Save.encode, Descent.snapshot(run), 0), "a guarded pile still serialises")

        -- ...and it does not move under a company standing in front of it. The fight is drawn once.
        local before = table.concat(rich.guardIds, ",")
        local back = Descent.restore(reserialize(Descent.snapshot(run)))
        assert(table.concat(Descent.dropsOn(back, 7)[1].guardIds, ",") == before,
            "the same company is standing there after a save and a reload")
    end },

    { name = "the company stored on a pile is the company that stands on the board", fn = function()
        -- THROUGH THE REAL PRODUCER. A stored list of ids is only a guard if the arena actually fields
        -- it, and the seam between the two is EncounterBattle.spec, which reads a blueprint's
        -- composition for every other encounter in the game. A pack blueprint deliberately has none --
        -- the cast belongs to the pile, not to the fiction -- so if that branch were ever dropped, the
        -- fight would silently open against the composition resolver's default body and nothing above
        -- here would notice.
        local EncounterBattle = require("models.encounter_battle")
        local Item = require("models.item")
        local p = company(1, 0)
        local run = Descent.new(p, 5)
        local pile = Descent.dropPack(run, 3, 4, 4, { Item.instantiate("weapon_iron_sword") })

        -- The cell states/game.lua's markBodies builds over a pile.
        local cell = { kind = "pack", name = "What You Dropped", drop = pile,
            id = "encounter_pack_drawn", composition = pile.guardIds }
        local built = EncounterBattle.build({
            encounter = cell, quest = Descent.floorQuest(run, p), day = 3,
            enemyLevel = Descent.dangerLevel(run), party = p.roster, seed = 5,
        })

        local ids = {}
        for _, u in ipairs(built.enemyUnits or {}) do ids[#ids + 1] = u.char and u.char.id end
        assert(#ids > 0, "the pile fielded nobody")
        local wanted = {}
        for _, id in ipairs(pile.guardIds) do wanted[id] = true end
        for _, id in ipairs(ids) do
            assert(wanted[id], "the board fielded " .. tostring(id) .. ", which is not on the pile")
        end
    end },

    { name = "a pack is taken by ID, so a marker built before a save still finds its pile", fn = function()
        -- The board's marker carries a COPY of the entry -- the grid snapshot stores the encounter
        -- whole, drop and all -- so identity was true exactly until somebody reloaded. It survived the
        -- one-pile rule because there was never a second entry for the copy to be confused with.
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)
        Descent.dropPack(run, 3, 4, 4, { Item.instantiate("weapon_iron_sword") })
        Descent.dropPack(run, 3, 8, 8, { Item.instantiate("consumable_healing_potion") })

        local live = Descent.dropsOn(run, 3)
        assert(#live == 2 and live[1].id ~= live[2].id, "precondition: two piles, two ids")

        -- What the marker would be holding after a round trip: a copy, equal in id and nothing else.
        local copy = { id = live[2].id }
        local back = Descent.takePack(run, copy)
        assert(back and back[1].id == "consumable_healing_potion",
            "the copy finds ITS pile, not the other one")
        assert(#Descent.dropsOn(run, 3) == 1, "and only that one is lifted")
    end },

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

    { name = "an empty drop is not a marker on an empty floor", fn = function()
        -- A company that wiped carrying nothing leaves nothing. Without this the board would grow a
        -- marker promising a pack, and walking to it would hand over an empty list -- which reads as a
        -- bug however correct the bookkeeping is.
        local run = Descent.new(company(1, 0), 7)
        assert(Descent.dropPack(run, 1, 2, 2, {}) == nil, "an empty pack is not dropped")
        assert(#Descent.dropsOn(run, 1) == 0, "and leaves nothing on the floor")
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
        -- WHY THIS IS WRITTEN AGAINST THE SOURCE. There are four routes off a floor -- the stair down,
        -- the way up, a sink, and a wipe -- and all four are branches inside states/game.lua, the last
        -- of them a closure hanging off a battle panel's `onLoss`. None can be reached from a headless
        -- spec, so the invariant is stated where it CAN be checked: the branch that sends a wiped
        -- company up to the Gate keeps its board on the way.
        --
        -- It shipped without one, and the shape of the miss is the reason for the tripwire: the other
        -- three routes all kept their board, so the feature worked everywhere anybody looked. What a
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
        -- WHAT MUST SURVIVE INSTEAD is the pile, and that is what this case guards now. The Gate still
        -- promises a wiped company that everything they were carrying is down there; a wipe that
        -- dropped a pack into a run it then threw away would break that promise silently, and the
        -- player would find out by diving for something that was never seeded.
        local strand = branch:find("Descent.strandPacks(", 1, true)
        assert(strand, "a wipe closes the rift without carrying its piles out: everything the company " ..
            "was holding would be deleted with the run it was holding it in")

        -- AFTER THE DROP, and the ordering is load-bearing rather than tidy: strandPacks moves what is
        -- on the run, so a pile dropped after it would be left behind in the run being discarded.
        local drop = branch:find("Descent.dropPack(", 1, true)
        assert(drop, "a wipe no longer drops a pack -- retarget this case")
        assert(drop < strand, "the piles are carried out before the wipe has dropped its own, so the " ..
            "pack the company just lost is the one that never arrives")

        -- ...and the run itself is let go, or the next descent would resume the one that just ended.
        assert(branch:find("descentRun = nil", 1, true),
            "a wipe leaves the closed rift on the player, so the next dive resumes a dead expedition")
    end },
}
