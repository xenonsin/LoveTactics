-- THE COIN-EATERS (Greed's approach, reviewed 2026-09-25 -- "The Coin-Eaters" artifact): the Gilded Scarab
-- that rolls the floor's gold, the Rust Mite whose hide rusts the weapon that strikes it, and the Brood
-- Queen whose Hoard is floor five's puzzle -- plus the three trophies, each a mechanic rebuilt to work on
-- every floor. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Hazard = require("models.hazard")
local Encounter = require("models.encounter")
local Descent = require("models.descent")

local HEAP = "hazard_coin_heap"

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function itemOf(u, id)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == id then return it end
    end
    error(id .. " is not in " .. tostring(u.char.id) .. "'s grid")
end

local function heapAt(c, x, y) return Hazard.at(c, x, y, HEAP) end
local function hp(u) return u.char.stats.health.current end
local function openTurn(c, u) c.turn = { unit = u, moved = false, moveCost = 0 } end

return {
    -- -----------------------------------------------------------------------
    -- The Gilded Scarab's Roll (ability_roll_heap)
    -- -----------------------------------------------------------------------
    { name = "a scarab rolls a heap down its lane, merging every heap it crosses", fn = function()
        local c = Combat.new(arena(10, 5), { unit("character_bandit", 10, 5) },
            { unit("character_gilded_scarab", 2, 3) })
        local scarab = c.units[2]
        Hazard.place(c, 3, 3, HEAP, { amount = 10 })
        Hazard.place(c, 5, 3, HEAP, { amount = 10 })
        openTurn(c, scarab)
        assert(Combat.useItem(c, scarab, itemOf(scarab, "ability_roll_heap"), 3, 3), "the roll lands")
        assert(not heapAt(c, 3, 3) and not heapAt(c, 5, 3), "both heaps have left where they lay")
        local rolled = heapAt(c, 7, 3)
        assert(rolled, "the heap comes to rest four tiles down the lane")
        assert(rolled.amount == 20, "carrying the gold of both, got " .. tostring(rolled.amount))
    end },

    { name = "a rolled heap stops against the first foe and hits it by its gold", fn = function()
        local c = Combat.new(arena(10, 5), { unit("character_bandit", 5, 3) },
            { unit("character_gilded_scarab", 2, 3) })
        local bandit, scarab = c.units[1], c.units[2]
        Hazard.place(c, 3, 3, HEAP, { amount = 20 })
        local before = hp(bandit)
        openTurn(c, scarab)
        assert(Combat.useItem(c, scarab, itemOf(scarab, "ability_roll_heap"), 3, 3), "the roll lands")
        assert(hp(bandit) < before, "the bandit is hit")
        assert(heapAt(c, 4, 3), "and the heap stops just short of it")
    end },

    { name = "a heap rolled into the Brood Queen goes into her Hoard (trait_the_nest, status_hoard)", fn = function()
        local c = Combat.new(arena(10, 5), { unit("character_bandit", 10, 5) },
            { unit("character_gilded_scarab", 2, 3), unit("character_brood_queen", 6, 3) })
        local scarab, queen = c.units[2], c.units[3]
        Hazard.place(c, 3, 3, HEAP, { amount = 10 })
        openTurn(c, scarab)
        assert(Combat.useItem(c, scarab, itemOf(scarab, "ability_roll_heap"), 3, 3), "the roll lands")
        assert(Status.stacksOf(queen, "status_hoard") == 20, "her opening ten, and ten more in her hoard")
        for x = 3, 5 do assert(not heapAt(c, x, 3), "and no heap left on the floor") end
        assert(itemOf(queen, "utility_the_nest"), "the Nest is in her grid")
    end },

    { name = "Carry Home (ability_carry_home) rolls a heap toward the Queen, not away from the scarab", fn = function()
        local c = Combat.new(arena(10, 7), { unit("character_bandit", 10, 7) },
            { unit("character_gilded_scarab", 4, 3), unit("character_brood_queen", 4, 7) })
        local scarab, queen = c.units[2], c.units[3]
        Hazard.place(c, 4, 4, HEAP, { amount = 10 })
        openTurn(c, scarab)
        assert(Combat.useItem(c, scarab, itemOf(scarab, "ability_carry_home"), 4, 4), "the carry lands")
        assert(Status.stacksOf(queen, "status_hoard") == 20, "the heap reached her hoard")
        assert(Item.defs.ability_carry_home.activeAbility.support, "a support cast, for the planner")
    end },

    -- -----------------------------------------------------------------------
    -- The Rust Mite's hide (utility_rust_hide, trait_rust_hide, status_tarnished)
    -- -----------------------------------------------------------------------
    { name = "a weapon that strikes a Rust Mite in melee rusts, and only that weapon", fn = function()
        local c = Combat.new(arena(6, 6), { unit("character_bandit", 3, 3) },
            { unit("character_rust_mite", 4, 3) })
        local bandit, mite = c.units[1], c.units[2]
        mite.char.stats.health.current = 500
        mite.char.stats.health.max = 500
        local weapon
        for _, it in ipairs(Character.eachItem(bandit.char)) do
            if it.type == "weapon" then weapon = it break end
        end
        assert(weapon, "the bandit carries a weapon")
        assert(itemOf(mite, "utility_rust_hide"), "the hide is in the mite's grid")
        for _ = 1, 5 do
            openTurn(c, bandit)
            bandit.char.stats.stamina.current = 99
            Combat.useItem(c, bandit, weapon, 4, 3)
        end
        assert(Status.has(bandit, "status_tarnished"), "the bandit's blade is Tarnished")
        assert(Status.tarnishOn(bandit, weapon) == 6, "capped at -6, got " .. Status.tarnishOn(bandit, weapon))
        assert(Status.tarnishOn(bandit, { id = "some_other_weapon" }) == 0, "another weapon is untouched")
    end },

    { name = "the Rustcoat (armor_rustcoat) rusts a blade the same way, on a tank's coat", fn = function()
        local def = Item.defs.armor_rustcoat
        assert(def.class == "knight" and def.type == "armor", "knight armour")
        assert(def.bonus.movement == -1, "every armour costs a square of pace")
        local knight = Character.instantiate("character_rowan")
        knight.inventory = {}
        Character.addItem(knight, Item.instantiate("armor_rustcoat"))
        local c = Combat.new(arena(6, 6), { unit(knight, 4, 3) }, { unit("character_bandit", 3, 3) })
        local ku, bandit = c.units[1], c.units[2]
        ku.char.stats.health.current, ku.char.stats.health.max = 500, 500
        local weapon
        for _, it in ipairs(Character.eachItem(bandit.char)) do
            if it.type == "weapon" then weapon = it break end
        end
        openTurn(c, bandit)
        Combat.useItem(c, bandit, weapon, 4, 3)
        assert(Status.tarnishOn(bandit, weapon) == 2, "one blow, one stack of rust")
    end },

    -- -----------------------------------------------------------------------
    -- The Brood Queen: Lay in the Hoard and Roll the Hoard
    -- -----------------------------------------------------------------------
    { name = "she lays an egg in a heap (ability_lay_in_the_hoard), and in two turns it hatches two scarabs", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_bandit", 8, 8) },
            { unit("character_brood_queen", 2, 2) })
        local queen = c.units[2]
        Hazard.place(c, 4, 2, HEAP, { amount = 10 })
        openTurn(c, queen)
        assert(Combat.useItem(c, queen, itemOf(queen, "ability_lay_in_the_hoard"), 4, 2), "the egg is laid")
        local egg = Combat.unitAt(c, 4, 2)
        assert(egg and egg.char.id == "character_scarab_egg", "an egg sits on the heap")
        assert(Status.has(egg, "status_scarab_hatch"), "on a clock")
        Status.tick(c, 11)
        assert(not egg.alive, "the egg is gone")
        local scarabs = 0
        for _, u in ipairs(c.units) do
            if u.alive and u.char.id == "character_gilded_scarab" then scarabs = scarabs + 1 end
        end
        assert(scarabs == 2, "and two scarabs came out of it, got " .. scarabs)
    end },

    { name = "a broken egg hatches nothing", fn = function()
        local c = Combat.new(arena(8, 8), { unit("character_bandit", 8, 8) },
            { unit("character_brood_queen", 2, 2) })
        local queen = c.units[2]
        Hazard.place(c, 4, 2, HEAP, { amount = 10 })
        openTurn(c, queen)
        Combat.useItem(c, queen, itemOf(queen, "ability_lay_in_the_hoard"), 4, 2)
        local egg = Combat.unitAt(c, 4, 2)
        Combat.dealFlatDamage(c, egg, 999, { "impact" }, "test", nil, { raw = true })
        Status.tick(c, 11)
        for _, u in ipairs(c.units) do
            assert(not (u.alive and u.char.id == "character_gilded_scarab"), "no scarab from a broken egg")
        end
    end },

    { name = "Roll the Hoard: under 20 she cannot; at 20 everything in the lane is downed, hers included", fn = function()
        local c = Combat.new(arena(12, 5), { unit("character_bandit", 5, 3), unit("character_bandit", 5, 1) },
            { unit("character_brood_queen", 2, 3), unit("character_gilded_scarab", 7, 3) })
        local inLane, clear, queen, scarab = c.units[1], c.units[2], c.units[3], c.units[4]
        local roll = itemOf(queen, "ability_roll_the_hoard")
        assert(Status.stacksOf(queen, "status_hoard") == 10, "the Nest opens on one heap's worth")
        assert(not roll.activeAbility.usable(queen), "ten gold is not a hoard")
        Status.apply(c, queen, "status_hoard", { magnitude = 10 })
        assert(roll.activeAbility.usable(queen), "twenty is")
        openTurn(c, queen)
        assert(Combat.useItem(c, queen, roll, 3, 3), "the roll is cast, and winds up")
        assert(Combat.resolveChannel(c, queen), "and lands when the wind-up is done")
        assert(inLane.char.stats.health.current <= 0 or not inLane.alive, "the bandit in the lane is downed")
        assert(clear.alive and hp(clear) > 0, "the one out of the lane is not")
        assert(scarab.char.stats.health.current <= 0 or not scarab.alive, "and her own scarab in the lane is too")
        assert(Status.stacksOf(queen, "status_hoard") == 0, "the hoard is spent")
    end },

    -- -----------------------------------------------------------------------
    -- The trophies that work on every floor
    -- -----------------------------------------------------------------------
    { name = "Gathering Roll (ability_gathering_roll) shoves a foe and gathers every body it hits", fn = function()
        local fighter = Character.instantiate("character_rowan")
        fighter.inventory = {}
        local roll = Item.instantiate("ability_gathering_roll")
        Character.addItem(fighter, roll)
        local c = Combat.new(arena(10, 5), { unit(fighter, 2, 3) },
            { unit("character_bandit", 3, 3), unit("character_bandit", 5, 3) })
        local fu, a, b = c.units[1], c.units[2], c.units[3]
        a.char.stats.health.current, a.char.stats.health.max = 500, 500
        b.char.stats.health.current, b.char.stats.health.max = 500, 500
        openTurn(c, fu)
        assert(Combat.useItem(c, fu, roll, 3, 3), "the roll lands")
        assert(b.x > 5, "the far bandit was carried on down the lane")
        assert(a.x > 3, "and so was the one struck")
        assert(hp(a) < 500 and hp(b) < 500, "and both took the blow")
        assert(Item.defs.ability_gathering_roll.class == "fighter", "Fighter stock")
    end },

    { name = "Brood Sting (ability_brood_sting) hatches two scarabs for the stinger; Cure takes the egg out", fn = function()
        local keeper = Character.instantiate("character_rowan")
        keeper.inventory = {}
        local sting = Item.instantiate("ability_brood_sting")
        Character.addItem(keeper, sting)
        local c = Combat.new(arena(8, 8), { unit(keeper, 2, 2) }, { unit("character_bandit", 3, 2) })
        local ku, bandit = c.units[1], c.units[2]
        bandit.char.stats.health.current, bandit.char.stats.health.max = 500, 500
        openTurn(c, ku)
        assert(Combat.useItem(c, ku, sting, 3, 2), "the sting lands")
        assert(Status.has(bandit, "status_brood_sting"), "the egg is in")
        Status.tick(c, 11)
        local mine = 0
        for _, u in ipairs(c.units) do
            if u.alive and u.char.id == "character_gilded_scarab" and u.side == "party" then mine = mine + 1 end
        end
        assert(mine == 2, "two scarabs on the stinger's side, got " .. mine)
        assert(hp(bandit) < 500, "and the host took the hatching")

        local c2 = Combat.new(arena(8, 8), { unit("character_rowan", 2, 2) }, { unit("character_bandit", 3, 2) })
        local host = c2.units[2]
        Status.apply(c2, host, "status_brood_sting", { magnitude = 10, applier = c2.units[1] })
        Status.cleanse(c2, host)
        for _, u in ipairs(c2.units) do
            assert(not (u.char.id == "character_gilded_scarab"), "a cured egg hatches nothing")
        end
    end },

    { name = "the three trophies are rift-only and on the beetles' drop lists", fn = function()
        local want = {
            character_gilded_scarab = "ability_gathering_roll",
            character_rust_mite = "armor_rustcoat",
            character_brood_queen = "ability_brood_sting",
        }
        for body, drop in pairs(want) do
            local drops = Character.defs[body].drops
            assert(drops and drops[1] == drop, body .. " drops " .. drop)
            assert(Item.defs[drop].unstocked and not Item.defs[drop].price, drop .. " is a trophy")
        end
        assert(Item.defs["weapon_mandibles"].class == "creature", "the bite is creature kit")
    end },

    -- -----------------------------------------------------------------------
    -- Where they stand
    -- -----------------------------------------------------------------------
    { name = "three ordinary fights and the Queen's elite, all on Greed's approach", fn = function()
        local fights = { "encounter_greed_the_swarm", "encounter_greed_the_scarab_dig", "encounter_greed_the_tarnish" }
        for _, id in ipairs(fights) do
            local def = Encounter.get(id)
            assert(def and def.kind == "combat" and def.rung == 1, id .. " is an ordinary fight on the approach")
        end
        local queen = Encounter.get("encounter_greed_the_brood_queen")
        assert(queen.kind == "elite" and queen.rung == 1, "the Queen is an elite on the approach")
        local greed
        for _, s in ipairs(Descent.SINS) do if s.id == "greed" then greed = s end end
        local billed = false
        for _, id in ipairs(greed.elites.spares) do
            if id == "encounter_greed_the_brood_queen" then billed = true end
        end
        assert(billed, "and billed as one of Greed's spares")
        local pool = {}
        for _, e in ipairs(Encounter.pool({ biome = "cave", rung = 1, depth = 5 })) do pool[e.id] = true end
        for _, id in ipairs(fights) do assert(pool[id], id .. " is dealt on floor five") end
        assert(pool.encounter_greed_the_brood_queen, "and so is the Queen")
    end },
}
