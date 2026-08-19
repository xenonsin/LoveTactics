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

    { name = "two deaths on ONE tile merge, because a second marker there would be invisible", fn = function()
        -- states/game.lua's markBodies never draws a pack over a cell that already has an encounter, so
        -- a second entry on the same square would sit on the run unreachable forever. Different tiles
        -- are different piles; the same tile is one pile that got bigger.
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
}
