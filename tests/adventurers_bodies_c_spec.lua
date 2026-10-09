-- THE RIFT'S ADVENTURERS, SLICE C (2026-10-09): the race-free bodies of the seventeen late crossings.
-- tests/adventurers_spec.lua holds every body to the contract; this holds slice C's to being PLAYABLE:
-- each one fields as more than one race, swings its default action, and takes a turn on a bare board --
-- and the combos the party pages promise (a mark knifed, a channel broken, a charge fired, something
-- planted on open ground) are ones its planner actually chooses.

local Adventurers = require("models.adventurers")
local Character = require("models.character")
local Class = require("models.class")
local Combat = require("models.combat")
local Growth = require("models.growth")
local Item = require("models.item")
local Race = require("models.race")
local Status = require("models.status")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local SLICE = {
    "inquisitor", "plague_knight", "shaman", "artificer", "duelist", "ninja", "paladin", "skirmisher",
    "battlemage", "herbalist", "vanguard", "spellbreaker", "totemist", "saboteur", "theurge", "warbrewer",
    "warden",
}

-- A race this class can be fielded as TODAY. The race items are built by another slice, so a pairing
-- whose item is not on disk yet is passed over rather than failed here; adventurers_spec names it.
local function fieldable(class, race)
    local item = Adventurers.raceItemOf(race, class)
    return item == nil or Item.defs[item] ~= nil
end

-- Two races for `class`: its leaning race when it can be fielded, then the first others that can.
local function twoRaces(class)
    local out = {}
    local lean = Adventurers.leaningRaces(class)[1]
    if fieldable(class, lean) then out[1] = lean end
    for _, race in ipairs(Adventurers.RACES) do
        if #out >= 2 then break end
        if race ~= lean and fieldable(class, race) then out[#out + 1] = race end
    end
    return out
end

local function walker(x, y)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = 300, 300
    return spawn
end

-- The body as a fight fields it, at the floor its class opens on, with a company `gap` tiles east.
local function board(class, gap, race)
    local id = Adventurers.variantId(class, race or twoRaces(class)[1])
    local floor = Adventurers.floorOf(class)
    local body = Growth.spawn(id, floor, floor)
    local c = Fixture.combat(Fixture.new(10, 10), { walker(3 + gap, 5), walker(3 + gap, 7) },
        { { char = body, x = 3, y = 5 }, Fixture.unit("character_knight", 2, 5) })
    local me
    for _, u in ipairs(c.units) do if u.char == body then me = u end end
    return c, me
end

local function planOf(c, me)
    Fixture.openTurn(c, me)
    return AI.plan(c, me)
end

local function foeOf(c, me, y)
    for _, u in ipairs(c.units) do
        if u.side ~= me.side and (not y or u.y == y) then return u end
    end
end

return {
    { name = "each slice-C body is honest tier-2 traffic of its own class", fn = function()
        for _, class in ipairs(SLICE) do
            local id = Adventurers.bodyOf(class)
            local def = rawget(Character.defs, id)
            assert(def, "no body " .. id)
            assert(def.tier == 2 and def.adventurer == true and not def.boss, id .. " is not tier-2 traffic")
            assert(def.discipline == class, id .. " walks " .. tostring(def.discipline))
            assert(def.name == Class.displayName(class), id .. " is not named for its class")
            assert(def.race == Adventurers.leaningRaces(class)[1], id .. " names the wrong base race")
            assert(def.drops == nil, id .. " carries a drops list; the class shelves pay it")
            local exemplar = rawget(Character.defs, Class.defs[class].exemplar)
            assert(exemplar and def.class == exemplar.class, id .. " walks a different root from its exemplar")
            assert(def.sprite == exemplar.sprite, id .. " does not borrow its exemplar's sprite")
            local n = #def.startingItems
            for k in pairs(def.startingItems) do
                assert(type(k) == "number" and k >= 1 and k <= n, id .. " has a hole in its grid")
            end
            assert(n <= 7, id .. " carries " .. n .. " items")
            for _, itemId in ipairs(def.startingItems) do
                local it = Item.defs[itemId]
                assert(it, id .. " carries an unknown item " .. itemId)
                assert(not it.bound and not it.race and not it.unstocked, id .. " carries " .. itemId)
                for _, tag in ipairs(it.tags or {}) do
                    assert(tag ~= "signature", id .. " carries a signature relic " .. itemId)
                end
            end
        end
    end },

    { name = "each slice-C body fields as two races, named for both, wielding its default", fn = function()
        for _, class in ipairs(SLICE) do
            local races = twoRaces(class)
            assert(#races == 2, class .. " has fewer than two fieldable races")
            for _, race in ipairs(races) do
                local id = Adventurers.variantId(class, race)
                local unit = Character.instantiate(id)
                assert(unit.race == race, id .. " lost its race")
                assert(unit.name == Race.get(race).name .. " " .. Class.displayName(class), id .. " is misnamed")
                local def = Character.defs[id]
                local default = Fixture.itemNamed(unit, def.defaultAction)
                assert(default and default.type == "weapon", id .. " does not hold a weapon as its default")
            end
        end
    end },

    { name = "each slice-C body can swing its default and takes a turn on a bare board", fn = function()
        for _, class in ipairs(SLICE) do
            local c, me = board(class, 3)
            local default = Fixture.itemNamed(me.char, Character.defs[me.char.id].defaultAction)
            assert(Combat.itemBlockReason(me, default) == nil, class .. " cannot use its default action")
            local plan = planOf(c, me)
            assert(plan and not plan.wait and (plan.item or plan.move),
                class .. " does nothing with a foe three tiles off: " .. tostring(plan and plan.reason))
        end
    end },

    { name = "the inquisitor marks, and knifes the Marked body", fn = function()
        local c, me = board("inquisitor", 1)
        local plan = planOf(c, me)
        assert(plan.item and plan.item.id == "ability_mark_of_heresy", "it brands first: " .. plan.reason)
        c, me = board("inquisitor", 1)
        local far = foeOf(c, me, 7)
        Status.apply(c, foeOf(c, me, 5), "status_mark", {})
        plan = planOf(c, me)
        assert(plan.item and plan.item.id == "weapon_confessors_needle" and plan.ty == 5,
            "the Needle goes at the Marked body, not " .. tostring(far and far.y) .. ": " .. plan.reason)
    end },

    { name = "the spellbreaker breaks the foe that is winding up", fn = function()
        local c, me = board("spellbreaker", 3)
        local caster = foeOf(c, me, 7)
        Status.apply(c, caster, "status_channeling", {})
        caster.channel = { ab = { cost = { stat = "mana", amount = 5 } } }
        local plan = planOf(c, me)
        assert(plan.item and plan.item.id == "ability_mana_sunder" and plan.ty == 7,
            "it goes for the channel: " .. tostring(plan.reason))
    end },

    { name = "the saboteur buries its line, and fires it only on a foe", fn = function()
        local c, me = board("saboteur", 3)
        local plan = planOf(c, me)
        assert(plan.item and plan.item.id == "consumable_sappers_line", "it lays the line: " .. plan.reason)
        c, me = board("saboteur", 6)
        Combat.plantCharge(c, me, 1, 1, {})
        plan = planOf(c, me)
        assert(not (plan.item and plan.item.id == "ability_detonator"), "it fired a charge nobody stands on")
        Combat.plantCharge(c, me, 9, 6, {})
        plan = planOf(c, me)
        assert(plan.item and plan.item.id == "ability_detonator", "it holds a charge a foe stands in")
    end },

    { name = "what a crossing plants on open ground, its planner sets down", fn = function()
        -- How far off the company stands: past the bow and the wand, inside the stake's five.
        local CASES = {
            shaman = { "ability_call_spirit", 6 }, artificer = { "ability_emplace_sentry", 6 },
            warden = { "ability_warding_line", 6 }, totemist = { "ability_carved_stake", 4 },
        }
        for class, case in pairs(CASES) do
            local want = case[1]
            local c, me = board(class, case[2])
            local plan = planOf(c, me)
            assert(plan.item and plan.item.id == want, class .. " did not plant: " .. tostring(plan.reason))
            assert(Combat.unitAt(c, plan.tx, plan.ty) == nil, class .. " aimed its plant at a body")
        end
    end },
}
