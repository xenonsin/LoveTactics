-- THE RIFT'S ADVENTURERS (models/adventurers.lua): rival parties of people on every floor, approved over
-- three review rounds on 2026-10-09. Each case below is one promise the review page made, measured
-- through the model rather than read back out of the blueprints.

local Adventurers = require("models.adventurers")
local Class = require("models.class")
local Character = require("models.character")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Spoils = require("models.spoils")
local Descent = require("models.descent")
local Player = require("models.player")

-- Every class a party may field: all of them but the creature bucket.
local function classes()
    local out = {}
    for id in pairs(Class.defs) do
        if id ~= "creature" then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

local function parties()
    local out = {}
    for id, def in pairs(Encounter.defs) do
        if def.party then out[#out + 1] = { id = id, def = def } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- The ones that keep a party standing rather than end the exchange (round 1: at most one per three).
local SUSTAIN = { priest = true, apothecary = true, paladin = true, sentinel = true, totemist = true }

return {
    { name = "every class leans to at least one race, and only playable races lean", fn = function()
        local Race = require("models.race")
        for _, race in ipairs(Adventurers.RACES) do
            assert(Race.isPlayable(race), race .. " is not a playable race")
            for _, c in ipairs(Adventurers.LEAN[race]) do
                assert(Class.defs[c], race .. " leans to an unknown class " .. c)
            end
        end
        for _, c in ipairs(classes()) do
            assert(#Adventurers.leaningRaces(c) > 0, c .. " has no leaning race")
        end
    end },

    { name = "every class has a race-free adventurer body of its own class", fn = function()
        for _, c in ipairs(classes()) do
            local id = Adventurers.bodyOf(c)
            local def = rawget(Character.defs, id)
            assert(def, "no adventurer body " .. id)
            assert(def.adventurer == true, id .. " is not marked adventurer = true")
            assert(not def.boss, id .. " is boss-flagged; adventurers are traffic")
            local own = def.discipline or def.class
            assert(own == c, id .. " walks " .. tostring(own) .. ", not " .. c)
            local n = 0
            for _ in pairs(def.startingItems or {}) do n = n + 1 end
            -- Room for the race grant and the race item, which the variant adds.
            assert(n <= 7, id .. " carries " .. n .. " items; an adventurer leaves two cells free")
        end
    end },

    { name = "a fielded id wears its race, and the sweep over blueprints never sees it", fn = function()
        local def = Character.defs["character_adv_bulwark@dwarf"]
        assert(def and def.race == "dwarf" and def.kind == "humanoid", "the dwarf bulwark did not resolve")
        local carries = false
        for _, it in ipairs(def.startingItems) do
            if it == "utility_mountains_root" then carries = true end
        end
        assert(carries, "a dwarf bulwark should carry Mountain's Root")
        local goblin = Character.defs["character_adv_bulwark@goblin"]
        for _, it in ipairs(goblin.startingItems) do
            assert(it ~= "utility_mountains_root", "a goblin bulwark carries the dwarf's race item")
        end
        assert(Character.defs["character_adv_bulwark@dragon"] == nil, "a creature race resolved")
        for id in pairs(Character.defs) do
            assert(not id:find("@", 1, true), "a derived id leaked into the blueprint sweep: " .. id)
        end
        local unit = Character.instantiate("character_adv_bulwark@dwarf")
        assert(unit.race == "dwarf", "the instantiated body lost its race")
    end },

    { name = "every race item names its race and sits on its pairing's class shelf", fn = function()
        for race, byClass in pairs(Adventurers.RACE_ITEMS) do
            for class, itemId in pairs(byClass) do
                local def = Item.defs[itemId]
                assert(def, "missing race item " .. itemId)
                assert(def.race == race, itemId .. " should be gated to " .. race)
                assert(def.class == class, itemId .. " should sit on the " .. class .. " shelf")
                assert(def.description and #def.description <= 120, itemId .. " description over 120")
            end
        end
    end },

    { name = "a race item refuses every other race, and nothing else is gated", fn = function()
        local dwarf = Character.instantiate("character_adv_bulwark@dwarf")
        local elf = Character.instantiate("character_adv_bulwark@elf")
        local root = Item.instantiate("utility_mountains_root")
        assert(Character.canCarry(dwarf, root), "a dwarf refused a dwarf item")
        local ok, why = Character.canCarry(elf, root)
        assert(not ok and why:find("dwarves"), "an elf carried a dwarf item: " .. tostring(why))
        assert(Character.addItem(elf, Item.instantiate("utility_mountains_root")) == false,
            "addItem landed a dwarf item on an elf")
        local plain = 0
        for _, def in pairs(Item.defs) do
            if def.race then plain = plain + 1 end
        end
        assert(plain == 16, "expected 16 race-gated items, found " .. plain)
    end },

    { name = "a body drops half its own class and half its parents'", fn = function()
        local sub = Spoils.lootSharesOf({ class = "rogue", discipline = "assassin" })
        assert(sub.assassin == 0.5 and sub.rogue == 0.5, "assassin should split 50/50 with rogue")
        local cross = Spoils.lootSharesOf({ class = "knight", discipline = "paladin" })
        assert(cross.paladin == 0.5 and cross.knight == 0.25 and cross.priest == 0.25,
            "paladin should split 50 / 25 / 25")
        local root = Spoils.lootSharesOf({ class = "knight" })
        assert(root.knight == 1, "a root pays its own shelf whole")
    end },

    { name = "each party opens where its highest core class does, and caps at six", fn = function()
        local list = parties()
        assert(#list == 24, "expected 24 parties, found " .. #list)
        for _, p in ipairs(list) do
            assert(p.def.depth == Adventurers.openingFloor(p.def.core), p.id .. " opens on the wrong floor")
            assert(p.def.kind == "combat" and not p.def.rung and not p.def.condition,
                p.id .. " should be floating ordinary traffic")
            assert(Encounter.capOf(p.def) == Adventurers.MAX, p.id .. " does not carry its own cap")
            for depth = p.def.depth, Descent.FLOORS do
                local ids = p.def.composition({ depth = depth })
                assert(#ids == math.min(Adventurers.sizeAt(depth), #ids) and #ids <= Adventurers.MAX,
                    p.id .. " fields " .. #ids .. " on floor " .. depth)
                assert(#ids >= 3, p.id .. " fields fewer than its core on floor " .. depth)
                for _, id in ipairs(ids) do
                    assert(Character.defs[id], p.id .. " fields an unknown body " .. id)
                end
            end
        end
    end },

    { name = "every floor fields every class open on it", fn = function()
        for floor = 1, Descent.FLOORS do
            local seen = {}
            for _, p in ipairs(parties()) do
                if p.def.depth <= floor then
                    for _, c in ipairs(Adventurers.members(p.def.core, p.def.grow, floor)) do seen[c] = true end
                end
            end
            for _, c in ipairs(classes()) do
                if Adventurers.floorOf(c) <= floor then
                    assert(seen[c], c .. " is open on floor " .. floor .. " and stands in no party there")
                end
            end
        end
    end },

    { name = "no party carries more than one sustain body per three", fn = function()
        for _, p in ipairs(parties()) do
            for floor = p.def.depth, Descent.FLOORS do
                local members = Adventurers.members(p.def.core, p.def.grow, floor)
                local n = 0
                for _, c in ipairs(members) do if SUSTAIN[c] then n = n + 1 end end
                assert(n <= math.floor(#members / 3), string.format(
                    "%s carries %d sustain bodies in %d on floor %d", p.id, n, #members, floor))
            end
        end
    end },

    { name = "a seeded party rolls races, half from the leaning ones, and repeats on a reload", fn = function()
        local def = Encounter.get("encounter_party_hold")
        local a = def.composition({ depth = 12, seed = 4242 })
        local b = def.composition({ depth = 12, seed = 4242 })
        assert(table.concat(a, ",") == table.concat(b, ","), "the same seed fielded different people")
        local races, leaning, total = {}, 0, 0
        for seed = 1, 200 do
            for _, id in ipairs(def.composition({ depth = 12, seed = seed })) do
                local _, race = Adventurers.split(id)
                races[race] = true
                total = total + 1
                for _, r in ipairs(Adventurers.leaningRaces(Adventurers.classOf(id))) do
                    if r == race then leaning = leaning + 1 break end
                end
            end
        end
        local n = 0
        for _ in pairs(races) do n = n + 1 end
        assert(n == 8, "200 seeds fielded only " .. n .. " races")
        local share = leaning / total
        assert(share > 0.5 and share < 0.75, string.format("leaning share %.2f is off the half-plus", share))
    end },

    { name = "parties take a fifth of a floor's ordinary draws", fn = function()
        local player = Player.new()
        local run = Descent.new(player, 7)
        for _, floor in ipairs({ 1, 5, 12 }) do
            run.floor = floor
            local quest = Descent.floorQuest(run, player)
            local ctx = { depth = floor, rung = Descent.floorWithinCircle(floor), biome = quest.map.biome,
                quest = quest }
            local partyW, all = 0, 0
            for _, e in ipairs(Descent.floorPool(ctx)) do
                if e.kind == "combat" then
                    all = all + e.weight
                    if Encounter.get(e.id).party then partyW = partyW + e.weight end
                end
            end
            assert(math.abs(partyW / all - Adventurers.SHARE) < 0.001, string.format(
                "floor %d deals parties at %.3f of its ordinary draws", floor, partyW / all))
        end
    end },
}
