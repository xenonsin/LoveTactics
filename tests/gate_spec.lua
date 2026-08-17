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

return {
    { name = "a night at the inn restores the company and sets every bone", fn = function()
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
        assert(Wound.count(p, char.id) == 0, "the bone is set")
        assert(char.stats.health.current == char.stats.health.max,
            "and they are whole -- not capped at the wounded ceiling, which is the ordering this " ..
            "function exists to get right")
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

    { name = "a second death destroys the first pile, wherever it was lying", fn = function()
        -- THE RULE THAT MAKES THE WALK BACK MATTER, and it is the answer to "what stops the player
        -- simply walking back". Nothing stops them -- what the game does instead is make the walk the
        -- most dangerous thing they will do, because failing it costs twice: the new pack plus the old
        -- one, permanently. Dark Souls' bloodstain exactly.
        local Item = require("models.item")
        local run = Descent.new(company(1, 0), 5)

        Descent.dropPack(run, 3, 4, 4, { Item.instantiate("weapon_iron_sword") })
        assert(#Descent.dropsOn(run, 3) == 1, "the first pile is on floor 3")

        Descent.dropPack(run, 6, 9, 9, { Item.instantiate("consumable_healing_potion") })
        assert(#Descent.dropsOn(run, 3) == 0, "the first pile is gone for good")
        assert(#Descent.dropsOn(run, 6) == 1, "and only the second is on the floor")
        assert(#(run.drops or {}) == 1, "one pile exists at a time, ever")

        local back = Descent.takePack(run, Descent.dropsOn(run, 6)[1])
        assert(back[1].id == "consumable_healing_potion", "and it is the second death's, not the first's")
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
}
