-- Tests for THE TOLLKEEPERS ("Sloth's Bestiary", reviewed 2026-10-04, slice F): demons who keep the gates of the
-- lower rift and take their due in what you do, never in gold. Seat bodies (rung 2), and the seat's elite.
--
--   Exit Fee        every Tollkeeper, Mora included: a body that walks out of its reach is struck on the way out;
--                   coming in is free, and a shove carries a body out for nothing
--   Toll-Collector  a pike that skewers two tiles in a line; drops the Collector's Pike
--   Bailiff         the Barrier: Braced at the end of every turn, and its brace covers every Tollkeeper beside it
--                   until its next turn; an impact blow breaks it; drops the Bailiff's Bar
--   Outrider        Ride Past: up to 4 tiles through every body, out the far side; nowhere to come out stops it dead
--                   and Stuns it; drops the Passing Lance
--   The Due         summon only: climbs out of a fallen Tollkeeper and goes for its killer
--   Mora            2x2, never strikes; Toll of Hours Roots a caster within 4 on its next turn; Passage Paid lets an
--                   idle body off the board at her gate, wins the fight when the company has all passed, and keeps
--                   her drop unless she falls; drops the Toll Ledger
--
-- Each case pins a rule the review approved, on a bare board, plus the drops and the fights' rungs.

local AI = require("models.ai")
local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Spoils = require("models.spoils")
local Status = require("models.status")
local Trait = require("models.trait")
local Toll = require("models.toll")
local Fixture = require("tests.support.fixture")

local unit, openTurn, hp = Fixture.unit, Fixture.openTurn, Fixture.hp

local BODIES = {
    character_toll_collector = { tier = 2, drops = { "weapon_collectors_pike" } },
    character_bailiff = { tier = 3, drops = { "armor_bailiffs_bar" } },
    character_outrider = { tier = 3, drops = { "weapon_passing_lance" } },
    character_the_due = { tier = 2, drops = {} },
    character_mora = { tier = 4, drops = { "utility_toll_ledger" } },
}
local DROPS = {
    weapon_collectors_pike = { class = "knight", type = "weapon" },
    armor_bailiffs_bar = { class = "bulwark", type = "armor" },
    weapon_passing_lance = { class = "vanguard", type = "weapon" },
    utility_toll_ledger = { class = "mammonite", type = "utility" },
}
local ORGANS = {
    "utility_exit_fee", "weapon_toll_pike", "weapon_gate_bar", "utility_the_barrier", "weapon_ride_past",
    "weapon_dues_claws", "utility_toll_of_hours",
}
local FIGHTS = {
    encounter_sloth_the_tollgate = { kind = "combat", has = { "character_bailiff", "character_toll_collector" } },
    encounter_sloth_the_outriders = { kind = "combat", has = { "character_outrider", "character_toll_collector" } },
    encounter_sloth_mora = { kind = "elite",
        has = { "character_mora", "character_bailiff", "character_toll_collector" } },
}

-- A company body: a walker on a deep pool, carrying nothing that answers a blow.
local function walker(x, y, opts)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = 300, 300
    for _, id in ipairs((opts and opts.items) or {}) do Character.addItem(spawn.char, Item.instantiate(id)) end
    if opts and opts.mana then spawn.char.stats.mana = { max = opts.mana, current = opts.mana } end
    return spawn
end

-- A Tollkeeper as authored, on a deep pool so a case can strike it without felling it.
local function keeper(id, x, y)
    local spawn = unit(id, x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = 400, 400
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id and u.alive then return u end end
end

local function all(c, id)
    local out = {}
    for _, u in ipairs(c.units) do if u.char and u.char.id == id and u.alive then out[#out + 1] = u end end
    return out
end

local function party(c)
    local out = {}
    for _, u in ipairs(c.units) do if u.side == "party" then out[#out + 1] = u end end
    return out
end

local WALL = { type = "mountain", moveCost = math.huge, walkable = false, sightCost = math.huge }
local function wall(x, y)
    local t = { x = x, y = y }
    for k, v in pairs(WALL) do t[k] = v end
    return t
end

-- Open `u`'s turn the way Combat.startTurn does, and let the field hear it open.
local function beginTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0, startX = u.x, startY = u.y }
    Status.onTurnStart(c, u)
    Trait.onAnyTurnStart(c, u)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "five demon bodies, each wearing the line's organ but the Due, dropping real classes' trophies",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == "demon", id .. " is a demon")
                assert(def.tier == want.tier, id .. " is tier " .. want.tier)
                assert(#(def.drops or {}) == #want.drops, id .. " drops " .. #want.drops)
                for i, d in ipairs(want.drops) do assert(def.drops[i] == d, id .. " drops " .. d) end
                local c = Fixture.combat(Fixture.new(8, 8), walker(1, 1), { unit(id, 4, 4) })
                local body = one(c, id)
                assert((id == "character_the_due") == not Toll.isTollkeeper(body),
                    id .. ": every Tollkeeper carries Exit Fee, and the Due is no Tollkeeper")
            end
            local mora = Character.defs.character_mora
            assert(mora.footprint.w == 2 and mora.footprint.h == 2, "Mora is a two-by-two gate")
            assert(mora.boss and mora.unarmed == false, "Mora is the elite's boss, and has not even a fist")
            for id, want in pairs(DROPS) do
                local def = Item.defs[id]
                assert(def and def.unstocked and not def.price, id .. " is an unstocked trophy")
                assert(def.class == want.class and def.type == want.type, id .. " is a " .. want.class .. "'s " .. want.type)
                assert(def.unlockLevel == 10 and Spoils.depthOf(def) >= 10, id .. " falls on the seat, floor 10")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
        end,
    },
    {
        name = "three fights on the tundra's seat: the Tollgate, the Outriders and Mora's elite",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == want.kind, id .. " is a " .. want.kind)
                assert(e.rung == 2, id .. " stands on the seat")
                assert(e.condition({ biome = "tundra" }) and not e.condition({ biome = "desert" }), id .. " is the tundra's")
                local ids = e.composition({ depth = 10 })
                local set = {}
                for _, b in ipairs(ids) do set[b] = (set[b] or 0) + 1 end
                for _, b in ipairs(want.has) do assert(set[b], id .. " fields " .. b) end
            end
            assert(Encounter.get("encounter_sloth_the_tollgate").weight == 3, "the Tollgate is ordinary traffic")
            assert(Encounter.get("encounter_sloth_the_outriders").weight == 3, "so are the Outriders")
            local gate = Encounter.get("encounter_sloth_the_tollgate").composition({ depth = 10 })
            local n = 0
            for _, b in ipairs(gate) do if b == "character_toll_collector" then n = n + 1 end end
            assert(n == 3, "the Tollgate's centre is three collectors and a Bailiff")
            local riders = 0
            for _, b in ipairs(Encounter.get("encounter_sloth_the_outriders").composition({ depth = 10, seed = 3 })) do
                if b == "character_outrider" then riders = riders + 1 end
            end
            assert(riders == 2, "two Outriders, whatever the roll")
            local court = Encounter.get("encounter_sloth_mora").composition({ depth = 10 })
            assert(court[1] == "character_mora", "Mora leads her fight")
            for _, eid in ipairs({ "encounter_sloth_the_tollgate", "encounter_sloth_the_outriders", "encounter_sloth_mora" }) do
                for seed = 1, 20 do
                    for _, b in ipairs(Encounter.get(eid).composition({ depth = 10, seed = seed })) do
                        assert(b ~= "character_the_due", "the Due is never dealt: it only climbs out of a fallen keeper")
                    end
                end
            end
        end,
    },

    -- ------------------------------------------------------------------------------ Exit Fee
    {
        name = "Exit Fee: a body that walks out of a Tollkeeper's reach is struck on the way out",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), walker(4, 4), { keeper("character_toll_collector", 5, 4) })
            local w = party(c)[1]
            local before = hp(w)
            openTurn(c, w)
            assert(Combat.moveUnit(c, w, 2, 4), "the body walks off")
            assert(hp(w) < before, "the collector struck it on the way out")
        end,
    },
    {
        name = "Exit Fee: coming in is free, and a shove carries a body out for nothing",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), walker(2, 4), { keeper("character_toll_collector", 5, 4) })
            local w = party(c)[1]
            local before = hp(w)
            openTurn(c, w)
            assert(Combat.moveUnit(c, w, 4, 4), "the body walks in")
            assert(hp(w) == before, "stepping into reach costs nothing")
            -- Shoved two tiles straight back from the collector, out of its reach, over open ground.
            local col = one(c, "character_toll_collector")
            c.turn = nil
            Combat.knockback(c, col, w, 2)
            assert(w.x == 2 and w.y == 4, "the body was shoved out of reach")
            assert(hp(w) == before, "a shove carries a body out and pays no fee")
        end,
    },
    {
        name = "Mora carries Exit Fee and never collects it: she never strikes",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10), walker(4, 5), { keeper("character_mora", 5, 5) })
            local mora = one(c, "character_mora")
            assert(Toll.isTollkeeper(mora), "Mora is a Tollkeeper")
            assert(Combat.defaultWeapon(mora.char) == nil, "she holds no weapon")
            local w = party(c)[1]
            local before = hp(w)
            openTurn(c, w)
            assert(Combat.moveUnit(c, w, 2, 5), "the body walks off from beside her")
            assert(hp(w) == before, "she collects nothing: only her collectors do")
            local plan = AI.plan(c, mora)
            assert(plan and not plan.item, "her turn swings at nothing")
        end,
    },

    -- ------------------------------------------------------------------------------ the Toll-Collector
    {
        name = "the Toll-Collector's pike skewers two tiles in a line, so a pair in file pays twice",
        fn = function()
            local front = walker(5, 4)
            local back = walker(6, 4)
            local c = Fixture.combat(Fixture.new(9, 9), { front, back }, { keeper("character_toll_collector", 4, 4) })
            local col = one(c, "character_toll_collector")
            local f, b = party(c)[1], party(c)[2]
            local hf, hb = hp(f), hp(b)
            openTurn(c, col)
            assert(Combat.useItem(c, col, Fixture.itemNamed(col.char, "weapon_toll_pike"), 5, 4), "the pike thrusts")
            assert(hp(f) < hf and hp(b) < hb, "both bodies in the line pay")
        end,
    },
    {
        name = "the Collector's Pike deals 50% more to a foe with an ally beside it",
        fn = function()
            local function thrust(flanked)
                local foes = { unit("character_archer", 3, 4, { isolate = "bare", stats = { health = 300, defense = 0 } }) }
                if flanked then
                    foes[2] = unit("character_archer", 3, 5, { isolate = "bare", stats = { health = 300, defense = 0 } })
                end
                local me = unit("character_archer", 2, 4, { isolate = "bare", items = { "weapon_collectors_pike" } })
                local c = Fixture.combat(Fixture.new(9, 9), me, foes)
                local hero = party(c)[1]
                local target
                for _, u in ipairs(c.units) do if u.side == "enemy" and u.x == 3 and u.y == 4 then target = u end end
                local before = hp(target)
                openTurn(c, hero)
                assert(Combat.useItem(c, hero, Fixture.itemNamed(hero.char, "weapon_collectors_pike"), 3, 4))
                return before - hp(target)
            end
            local alone, flanked = thrust(false), thrust(true)
            assert(alone > 0, "the pike lands")
            assert(flanked > alone, string.format("a foe with an ally beside it takes more (%d vs %d)", flanked, alone))
        end,
    },

    -- ------------------------------------------------------------------------------ the Bailiff
    {
        name = "the Barrier: the Bailiff braces every Tollkeeper beside it until its own next turn",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), walker(1, 1), {
                keeper("character_bailiff", 4, 4), keeper("character_toll_collector", 4, 3),
                keeper("character_toll_collector", 5, 4), keeper("character_toll_collector", 7, 7),
            })
            local bailiff = one(c, "character_bailiff")
            local near, far = {}, nil
            for _, u in ipairs(all(c, "character_toll_collector")) do
                if u.x == 7 then far = u else near[#near + 1] = u end
            end
            beginTurn(c, bailiff)
            Combat.wait(c, bailiff)
            assert(Status.has(bailiff, "status_defending"), "the Bailiff braces at the end of its turn")
            for _, u in ipairs(near) do
                local st = Status.get(u, "status_defending")
                assert(st and st.heldBy == bailiff, "a Tollkeeper beside it is Braced by it")
            end
            assert(not Status.has(far, "status_defending"), "one standing off the line is not")
            -- A covered collector's own turn does not take the brace down: it holds until the BAILIFF's turn.
            beginTurn(c, near[1])
            assert(Status.has(near[1], "status_defending"), "the lent brace outlasts the bearer's own turn start")
            c.turn = nil
            beginTurn(c, bailiff)
            for _, u in ipairs(near) do
                assert(not Status.has(u, "status_defending"), "the Bailiff's next turn takes its lent braces down")
            end
        end,
    },
    {
        name = "the Barrier covers Tollkeepers only, and an impact blow on the Bailiff opens the whole gate",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), walker(1, 1), {
                keeper("character_bailiff", 4, 4), keeper("character_toll_collector", 4, 3),
                unit("character_archer", 3, 4, { isolate = "bare" }),
            })
            local bailiff, col = one(c, "character_bailiff"), one(c, "character_toll_collector")
            local stranger = one(c, "character_archer")
            beginTurn(c, bailiff)
            Combat.wait(c, bailiff)
            assert(Status.has(col, "status_defending"), "the collector is covered")
            assert(not Status.has(stranger, "status_defending"), "a body that keeps no gate is not")
            local w = party(c)[1]
            Combat.dealFlatDamage(c, bailiff, 5, { "slash", "physical" }, "test", w, { raw = true })
            assert(Status.has(bailiff, "status_defending"), "an edge does not break the brace")
            Combat.dealFlatDamage(c, bailiff, 5, { "impact", "physical" }, "test", w, { raw = true })
            assert(not Status.has(bailiff, "status_defending"), "impact breaks the Bailiff's brace")
            assert(not Status.has(col, "status_defending"), "and every brace it lent comes down with it")
        end,
    },
    {
        name = "an impact blow breaks a covered Tollkeeper's brace",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), walker(1, 1), {
                keeper("character_bailiff", 4, 4), keeper("character_toll_collector", 4, 3),
            })
            local bailiff, col = one(c, "character_bailiff"), one(c, "character_toll_collector")
            beginTurn(c, bailiff)
            Combat.wait(c, bailiff)
            Combat.dealFlatDamage(c, col, 5, { "impact", "physical" }, "test", party(c)[1], { raw = true })
            assert(not Status.has(col, "status_defending"), "the struck collector's brace breaks")
            assert(Status.has(bailiff, "status_defending"), "the Bailiff still holds its own")
        end,
    },
    {
        name = "the Bailiff's Bar: Defend also Braces every adjacent ally until your next turn",
        fn = function()
            local holder = unit("character_archer", 4, 4, { isolate = "bare", items = { "armor_bailiffs_bar" } })
            local ally = unit("character_archer", 4, 5, { isolate = "bare" })
            local c = Fixture.combat(Fixture.new(9, 9), { holder, ally }, { unit("character_archer", 8, 8, { isolate = "bare" }) })
            local h, a = party(c)[1], party(c)[2]
            beginTurn(c, h)
            assert(Combat.defend(c, h), "the holder Defends")
            local st = Status.get(a, "status_defending")
            assert(st and st.heldBy == h, "the ally beside it is Braced by it")
            beginTurn(c, a)
            assert(Status.has(a, "status_defending"), "the ally's own turn start leaves the brace standing")
            c.turn = nil
            beginTurn(c, h)
            assert(not Status.has(a, "status_defending"), "the holder's next turn takes it down")
            -- A turn that did not Defend lends nothing.
            Combat.wait(c, h)
            assert(not Status.has(a, "status_defending"), "a plain Wait braces nobody")
        end,
    },

    -- ------------------------------------------------------------------------------ the Outrider
    {
        name = "Ride Past: up to 4 tiles through every body in the lane, striking each, and out beyond them",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 9), { walker(3, 4), walker(4, 4) },
                { keeper("character_outrider", 2, 4) })
            local rider = one(c, "character_outrider")
            local a, b = party(c)[1], party(c)[2]
            local ha, hb = hp(a), hp(b)
            openTurn(c, rider)
            assert(Combat.useItem(c, rider, Fixture.itemNamed(rider.char, "weapon_ride_past"), 3, 4), "it rides")
            assert(rider.x == 6 and rider.y == 4, "it comes out at the lane's far end, beyond them")
            assert(hp(a) < ha and hp(b) < hb, "every body it passed through is struck")
            assert(not Status.has(rider, "status_stun"), "a ride that comes out is not Stunned")
        end,
    },
    {
        name = "a ride with nowhere to come out stops dead, lands nothing, and the Outrider is Stunned",
        fn = function()
            -- Back to a wall.
            local c = Fixture.combat(Fixture.new(10, 9, { tiles = { wall(4, 4) } }), walker(3, 4),
                { keeper("character_outrider", 2, 4) })
            local rider = one(c, "character_outrider")
            local w = party(c)[1]
            local before = hp(w)
            openTurn(c, rider)
            Combat.useItem(c, rider, Fixture.itemNamed(rider.char, "weapon_ride_past"), 3, 4)
            assert(rider.x == 2 and rider.y == 4, "it stays where it stood")
            assert(hp(w) == before, "the body with its back to the wall takes nothing")
            assert(Status.has(rider, "status_stun"), "and the Outrider is Stunned")
            -- Back to a body: four in file fill the lane.
            local c2 = Fixture.combat(Fixture.new(10, 9), { walker(3, 4), walker(4, 4), walker(5, 4), walker(6, 4) },
                { keeper("character_outrider", 2, 4) })
            local r2 = one(c2, "character_outrider")
            openTurn(c2, r2)
            Combat.useItem(c2, r2, Fixture.itemNamed(r2.char, "weapon_ride_past"), 3, 4)
            assert(r2.x == 2 and Status.has(r2, "status_stun"), "a lane full of bodies is nowhere to come out")
        end,
    },
    {
        name = "the Outrider rides the lane through the most foes, and does not look behind the line",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), { walker(5, 2), walker(2, 5), walker(3, 5) },
                { keeper("character_outrider", 5, 5) })
            local rider = one(c, "character_outrider")
            local plan = Toll.plan(c, rider)
            assert(plan and plan.item and plan.item.id == "weapon_ride_past", "its turn is a ride")
            local from = plan.move or { x = rider.x, y = rider.y }
            local dx, dy = plan.tx - from.x, plan.ty - from.y
            local cells = Toll.lane(c, from.x, from.y, dx, dy, 4, function(x, y) return Combat.unitAt(c, x, y) end, rider)
            local _, bodies = Toll.exit(cells)
            assert(#bodies == 2, "it picks the lane with two foes in it over the one with one")
            -- With its back to the wall the party stands, and the ride is still taken: a mount does not look.
            local c2 = Fixture.combat(Fixture.new(12, 12, { tiles = { wall(1, 5) } }), { walker(2, 5) },
                { keeper("character_outrider", 6, 5) })
            local r2 = one(c2, "character_outrider")
            local p2 = Toll.plan(c2, r2)
            assert(p2 and p2.item, "it rides at a body with its back to a wall")
        end,
    },
    {
        name = "the Passing Lance rides through foes only, and a blocked lane simply stops it",
        fn = function()
            local me = unit("character_archer", 2, 4, { isolate = "bare", items = { "weapon_passing_lance" } })
            local friend = unit("character_archer", 3, 4, { isolate = "bare", stats = { health = 300 } })
            local foe = unit("character_archer", 4, 4, { isolate = "bare", stats = { health = 300 } })
            local c = Fixture.combat(Fixture.new(10, 9), { me, friend }, { foe })
            local hero, pal = party(c)[1], party(c)[2]
            local bad
            for _, u in ipairs(c.units) do if u.side == "enemy" then bad = u end end
            local hp1, hp2 = hp(pal), hp(bad)
            openTurn(c, hero)
            assert(Combat.useItem(c, hero, Fixture.itemNamed(hero.char, "weapon_passing_lance"), 3, 4), "the lance rides")
            assert(hero.x == 6, "it ends beyond them")
            assert(hp(pal) == hp1, "an ally in the lane is passed through untouched")
            assert(hp(bad) < hp2, "a foe in the lane is struck")
            local c2 = Fixture.combat(Fixture.new(10, 9, { tiles = { wall(4, 4) } }),
                unit("character_archer", 2, 4, { isolate = "bare", items = { "weapon_passing_lance" } }),
                { unit("character_archer", 3, 4, { isolate = "bare", stats = { health = 300 } }) })
            local h2 = party(c2)[1]
            openTurn(c2, h2)
            Combat.useItem(c2, h2, Fixture.itemNamed(h2.char, "weapon_passing_lance"), 3, 4)
            assert(h2.x == 2 and not Status.has(h2, "status_stun"), "blocked, it stops; nobody is Stunned")
        end,
    },

    -- ------------------------------------------------------------------------------ the Due
    {
        name = "a fallen Tollkeeper lets the Due out, and the Due goes for whoever made the kill",
        fn = function()
            local killer = walker(3, 4)
            local other = walker(8, 8)
            local c = Fixture.combat(Fixture.new(10, 10), { killer, other }, { unit("character_toll_collector", 4, 4) })
            local col = one(c, "character_toll_collector")
            local k = party(c)[1]
            Combat.dealFlatDamage(c, col, 9999, { "slash", "physical" }, "test", k, { raw = true })
            assert(not col.alive, "the collector falls")
            local due = one(c, "character_the_due")
            assert(due, "the Due climbs out of it")
            assert(due.dueTarget == k, "and it is pointed at the killer")
            assert(not due.summoned, "a real body: the fight waits for it")
            local plan = Toll.plan(c, due)
            assert(plan and plan.item, "its turn is a strike")
            local tx, ty = plan.tx, plan.ty
            assert(Combat.unitAt(c, tx, ty) == k, "at the killer, not the nearer stranger")
            local before = hp(k)
            openTurn(c, due)
            if plan.move then assert(Combat.moveUnit(c, due, plan.move.x, plan.move.y), "it closes") end
            assert(Combat.useItem(c, due, plan.item, plan.tx, plan.ty), "it strikes")
            assert(hp(k) < before, "the killer pays")
            assert(not due.alive and not due.corpse and not due.incapacitated,
                "the debt is paid, and the Due is gone -- not felled, so nothing climbs out of it")
            assert(#all(c, "character_the_due") == 0, "and nothing else is left owing")
        end,
    },
    {
        name = "the Due is no Tollkeeper: felling it lets nothing out",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10), walker(3, 4), { unit("character_toll_collector", 4, 4) })
            local k = party(c)[1]
            Combat.dealFlatDamage(c, one(c, "character_toll_collector"), 9999, { "slash", "physical" }, "test", k,
                { raw = true })
            local due = one(c, "character_the_due")
            assert(due and not Toll.isTollkeeper(due), "a Due climbed out, and keeps no gate")
            Combat.dealFlatDamage(c, due, 9999, { "slash", "physical" }, "test", k, { raw = true })
            assert(#all(c, "character_the_due") == 0, "a Due owes nothing")
        end,
    },

    -- ------------------------------------------------------------------------------ Mora
    {
        name = "Toll of Hours: an ability used within 4 of Mora Roots its user on its next turn; a swing does not",
        fn = function()
            local caster = walker(3, 5, { items = { "ability_seal_slash" }, mana = 100 })
            local far = walker(1, 1, { items = { "ability_seal_slash" }, mana = 100 })
            local c = Fixture.combat(Fixture.new(12, 12), { caster, far }, { keeper("character_mora", 5, 5) })
            local near, distant = party(c)[1], party(c)[2]
            openTurn(c, near)
            assert(Combat.useItem(c, near, Fixture.itemNamed(near.char, "ability_seal_slash"), near.x, near.y), "it casts")
            assert(near.tollOwed, "it owes an hour")
            assert(not Status.has(near, "status_root"), "the cast it made resolves free")
            beginTurn(c, near)
            assert(Status.has(near, "status_root"), "Rooted on its next turn")
            openTurn(c, distant)
            assert(Combat.useItem(c, distant, Fixture.itemNamed(distant.char, "ability_seal_slash"), distant.x, distant.y))
            assert(not distant.tollOwed, "beyond 4 of her, nothing is owed")
            local swinger = walker(4, 6)
            local c2 = Fixture.combat(Fixture.new(12, 12), swinger, { keeper("character_mora", 5, 5) })
            local s = party(c2)[1]
            local mora = one(c2, "character_mora")
            openTurn(c2, s)
            Combat.useItem(c2, s, Combat.defaultWeapon(s.char), mora.x, mora.y + 1)
            assert(not s.tollOwed, "a weapon's swing is not an ability")
        end,
    },
    {
        name = "the Toll Ledger: a foe that uses an ability within 3 of you is Rooted on its next turn",
        fn = function()
            local bearer = unit("character_archer", 4, 4, { isolate = "bare", items = { "utility_toll_ledger" } })
            local friend = walker(4, 5, { items = { "ability_seal_slash" }, mana = 100 })
            local foe = unit("character_archer", 6, 4, { isolate = "bare", items = { "ability_seal_slash" } })
            foe.char.stats.mana = { max = 100, current = 100 }
            local c = Fixture.combat(Fixture.new(12, 12), { bearer, friend }, { foe })
            local pal = party(c)[2]
            local f
            for _, u in ipairs(c.units) do if u.side == "enemy" then f = u end end
            openTurn(c, f)
            assert(Combat.useItem(c, f, Fixture.itemNamed(f.char, "ability_seal_slash"), f.x, f.y))
            beginTurn(c, f)
            assert(Status.has(f, "status_root"), "the foe that cast within 3 is Rooted on its next turn")
            openTurn(c, pal)
            assert(Combat.useItem(c, pal, Fixture.itemNamed(pal.char, "ability_seal_slash"), pal.x, pal.y))
            assert(not pal.tollOwed, "an ally casts free")
        end,
    },
    {
        name = "Passage Paid: a whole turn idle on a gate tile walks a body off the board, and the last one wins it",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), { walker(4, 5), walker(4, 6) },
                { keeper("character_mora", 5, 5), keeper("character_toll_collector", 10, 10) })
            local a, b = party(c)[1], party(c)[2]
            local mora = one(c, "character_mora")
            assert(Toll.isGateTile(mora, 4, 5) and Toll.isGateTile(mora, 4, 6), "both stand at her gate")
            beginTurn(c, a)
            Combat.wait(c, a)
            assert(a.passed and not a.alive, "the first body pays and passes")
            assert(not a.incapacitated and not a.corpse, "it left safe: no body on the ground")
            assert(Combat.evaluate(c) == nil, "one of two through is not yet a win")
            assert(not mora.char.dropsWithheld, "she withholds nothing while the company is still here")
            beginTurn(c, b)
            Combat.wait(c, b)
            assert(b.passed, "the second pays and passes")
            assert(Combat.evaluate(c) == "win", "every living body passed: the fight is won without her falling")
            assert(mora.alive and mora.char.dropsWithheld, "and she pays her drop only if she falls")
        end,
    },
    {
        name = "Passage Paid asks for a whole turn of nothing: a step, a blow or a Stun pays no passage",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), { walker(3, 5), walker(4, 6), walker(4, 5) },
                { keeper("character_mora", 5, 5) })
            local stepper, striker, stunned = party(c)[1], party(c)[2], party(c)[3]
            beginTurn(c, stepper)
            assert(Combat.moveUnit(c, stepper, 4, 4), "it steps onto the gate")
            Combat.wait(c, stepper)
            assert(not stepper.passed, "a turn spent walking there is not a turn spent waiting")
            beginTurn(c, striker)
            local mora = one(c, "character_mora")
            Combat.useItem(c, striker, Combat.defaultWeapon(striker.char), mora.x, mora.y + 1)
            assert(not striker.passed, "a turn that struck her pays nothing")
            beginTurn(c, stunned)
            Status.apply(c, stunned, "status_stun")
            Combat.wait(c, stunned)
            assert(not stunned.passed, "a turn a Stun took is not paid")
            local off = Fixture.combat(Fixture.new(12, 12), walker(2, 2), { keeper("character_mora", 5, 5) })
            local o = party(off)[1]
            beginTurn(off, o)
            Combat.wait(off, o)
            assert(not o.passed, "idling away from her gate is only idling")
        end,
    },
}
