-- Tests for THE GILDED KING (approved over review rounds on 2026-09-26): Greed's rung-2 spare elite, the
-- dead king crusted in the gold that starved him, his gilded guard, and the two trophies he drops --
--   * a heal aimed at him is a coin heap beside him, and restores nothing (nor burns him, undead as he is)
--   * any blow knocks a gold plate off as a heap, and nothing puts one back
--   * his guard of Dwarf Skeletons opens the fight Gilded
--   * the Gilded Crown opens its bearer Gilded
--   * Gilded Bread's bearer cannot be healed, and its cast buys health with the company's gold at five a
--     point -- never past the purse, never past the wound, never for a heal that could not land
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local KING = "character_the_gilded_king"
local TROPHIES = { "utility_the_gilded_crown", "ability_gilded_bread" }

local function board(n) return Fixture.new(n or 11, n or 11) end

local function heaps(c)
    local n = 0
    for _, h in ipairs(c.hazards or {}) do if h.alive and h.id == "hazard_coin_heap" then n = n + 1 end end
    return n
end

local function plates(u) return Status.stacksOf(u, "status_gold_plate") end

-- The King on a bare board with one company body in front of him. Returns the combat, the body, the King.
local function withKing(extraEnemies)
    local enemies = { unit(KING, 6, 6) }
    for _, e in ipairs(extraEnemies or {}) do enemies[#enemies + 1] = e end
    local c = Fixture.combat(board(),
        { unit("character_knight", 6, 5, { isolate = "bare", stats = { health = 200 } }) }, enemies)
    return c, c.units[1], c.units[2]
end

-- Inject a purse over a local gold cell, the way states/battle.lua injects one over Player.active.
local function givePurse(combat, gold)
    local g = gold
    combat.purse = { get = function() return g end, spend = function(n) g = g - n end }
    return function() return g end
end

-- A company pair: a baker carrying Gilded Bread, and a hurt friend beside it.
local function bakery(gold, friendHurt)
    local baker = unit("character_knight", 2, 2,
        { isolate = "bare", items = { "ability_gilded_bread" }, stats = { health = 100, stamina = 99 } })
    local friend = unit("character_knight", 2, 3, { isolate = "bare", stats = { health = 100 } })
    local c = Fixture.combat(board(8), { baker, friend }, unit("character_bandit", 7, 7, { isolate = "bare" }))
    local b, f = c.units[1], c.units[2]
    f.char.stats.health.current = 100 - (friendHurt or 0)
    local purse = gold and givePurse(c, gold) or nil
    return c, b, f, purse
end

local function bake(c, b, target, spend)
    local item = itemNamed(b.char, "ability_gilded_bread")
    openTurn(c, b)
    return Combat.useItem(c, b, item, target.x, target.y, nil, nil, spend)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the Gilded King is a dead man in a crown: human, tagged undead, a tier-3 boss body, slow and weak in the arm",
        fn = function()
            local def = Character.defs[KING]
            assert(def.race == "human" and def.undead == true, "human, and dead (the undead tag, as Vesh)")
            assert(def.tier == 3 and def.boss, "an elite's rung, off the execute and Charm tables")
            local king = Character.instantiate(KING)
            assert(Character.isUndead(king) and king.kind == "humanoid", "undead on top of what he was")
            for _, id in ipairs({ "weapon_gold_sceptre", "utility_gilded_flesh", "utility_the_gilded_crown" }) do
                assert(itemNamed(king, id), "he carries " .. id)
            end
            local thane = Character.defs["character_the_hoard_thane"]
            assert(def.stats.damage < thane.stats.damage and def.stats.speed < thane.stats.speed
                and def.stats.movement < thane.stats.movement, "slower and weaker in the arm than the seat's Thane")
            local flesh = Item.defs["utility_gilded_flesh"]
            assert(flesh.class == "creature" and flesh.noSteal and flesh.bound and flesh.price == nil, "an organ")
            local rod = Item.defs["weapon_gold_sceptre"]
            assert(rod.class == "creature" and rod.noSteal and rod.price == nil, "creature kit")
        end,
    },
    {
        name = "the fight: a cave elite on Greed's seat, billed as a spare, the King and two or three Dwarf Skeletons",
        fn = function()
            local def = Encounter.defs["encounter_greed_the_gilded_king"]
            assert(def.kind == "elite" and def.rung == 2, "an elite on rung 2")
            assert(def.condition({ biome = "cave" }) and not def.condition({ biome = "forest" }), "the cave only")
            assert((def.objective or { type = "killAll" }).type == "killAll", "never an assassination")
            local seen = {}
            for seed = 1, 40 do
                local list = def.composition({ depth = 6, seed = seed })
                assert(list[1] == KING, "the King leads")
                for i = 2, #list do assert(list[i] == "character_dwarf_skeleton", "his guard is his dead diggers") end
                assert(#list - 1 >= 2 and #list - 1 <= 3, "two or three guards, got " .. (#list - 1))
                seen[#list - 1] = true
            end
            assert(seen[2] and seen[3], "the guard rolls per seed")
            local greed
            for _, s in ipairs(Descent.SINS) do if s.id == "greed" then greed = s end end
            local billed = false
            for _, id in ipairs(greed.elites.spares) do
                if id == "encounter_greed_the_gilded_king" then billed = true end
            end
            assert(billed, "Greed bills him as a spare")
        end,
    },
    {
        name = "the drops: the Gilded Crown and Gilded Bread, both seen on the rack and never sold",
        fn = function()
            local drops = {}
            for _, id in ipairs(Character.defs[KING].drops) do drops[id] = true end
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(drops[id], "he drops " .. id)
                assert(def and def.unstocked and def.price == nil, id .. " is a trophy")
                assert(def.class ~= "creature", id .. " is a person's piece")
            end
            assert(Item.defs["ability_gilded_bread"].class == "mammonite", "the bread spends the purse: mammonite")
        end,
    },

    -- ------------------------------------------------------------------------------ Turned to Gold
    {
        name = "Turned to Gold: a heal aimed at him is a coin heap beside him, and restores nothing -- nor burns him",
        fn = function()
            local c, _, king = withKing()
            king.char.stats.health.current = 60
            local before = heaps(c)
            assert(Combat.applyHeal(c, king, 25) == 0, "nothing is healed")
            assert(hp(king) == 60, "his health does not move -- no heal, and no Grave-Cold wound either")
            assert(heaps(c) == before + 1, "the heal lies beside him as a coin heap")
            local heap
            for _, h in ipairs(c.hazards) do if h.alive and h.id == "hazard_coin_heap" then heap = h end end
            assert(math.max(math.abs(heap.x - king.x), math.abs(heap.y - king.y)) == 1, "at his feet")
            assert(Combat.healRefusal(king), "and a cast that has to pay first can see it")
        end,
    },
    {
        name = "Turned to Gold: the heap is the company's to loot",
        fn = function()
            local c, knight, king = withKing()
            Combat.applyHeal(c, king, 10)
            local heap
            for _, h in ipairs(c.hazards) do if h.alive and h.id == "hazard_coin_heap" then heap = h end end
            local bounty = c.bounty or 0
            Combat.teleportUnit(c, knight, heap.x, heap.y)
            assert((c.bounty or 0) > bounty, "the looter banks the gold")
        end,
    },

    -- ------------------------------------------------------------------------------ Gold Plate
    {
        name = "Gold Plate: six plates, and ANY blow knocks one off as a coin heap -- an edge as well as a hammer",
        fn = function()
            local c, knight, king = withKing()
            assert(plates(king) == 6, "six plates to begin, got " .. plates(king))
            local before = heaps(c)
            Combat.dealFlatDamage(c, king, 3, { "slash", "physical" }, nil, knight)
            assert(plates(king) == 5, "a knife takes one")
            Combat.dealFlatDamage(c, king, 3, { "impact", "physical" }, nil, knight)
            assert(plates(king) == 4, "a hammer takes one")
            assert(heaps(c) == before + 2, "each plate lands as a heap")
            Combat.dealFlatDamage(c, king, 3, { "fire" })
            assert(plates(king) == 4, "a tick with nobody behind it is not a blow")
        end,
    },
    {
        name = "Gold Plate: nothing puts a plate back -- not a heap he walks over, not a heal",
        fn = function()
            local c, knight, king = withKing()
            Combat.dealFlatDamage(c, king, 3, { "slash", "physical" }, nil, knight)
            Combat.dealFlatDamage(c, king, 3, { "slash", "physical" }, nil, knight)
            assert(plates(king) == 4)
            for _, h in ipairs(c.hazards) do
                if h.alive and h.id == "hazard_coin_heap" then
                    Combat.teleportUnit(c, king, h.x, h.y)
                end
            end
            assert(plates(king) == 4, "he does not eat the gold back (that is the golem's Regild)")
            Combat.applyHeal(c, king, 30)
            assert(plates(king) == 4, "and a heal is a heap, never a plate")
            local Trait = require("models.trait")
            assert(not Trait.flag(king, "eatsHeaps"), "no Regild on him")
        end,
    },

    -- ------------------------------------------------------------------------------ the guard
    {
        name = "The Gilded Guard: every Dwarf Skeleton beside him opens the fight Gilded, and the company does not",
        fn = function()
            local c, knight = withKing({ unit("character_dwarf_skeleton", 5, 7), unit("character_dwarf_skeleton", 7, 7) })
            local guards = 0
            for _, u in ipairs(c.units) do
                if u.char.id == "character_dwarf_skeleton" then
                    guards = guards + 1
                    assert(Status.has(u, "status_gilded"), "a guard opens Gilded")
                end
            end
            assert(guards == 2)
            assert(not Status.has(knight, "status_gilded"), "the company is not his to gild")
        end,
    },

    -- ------------------------------------------------------------------------------ the Gilded Crown
    {
        name = "the Gilded Crown: its bearer opens every fight Gilded, which every living dwarf covets",
        fn = function()
            local crown = Item.instantiate("utility_the_gilded_crown")
            local boons = require("models.curse").openingBoons(crown)
            assert(#boons == 1 and boons[1].id == "status_gilded", "the crown's boon is Gilded")
            -- Applied as states/battle.lua applies every item's boon at the bell.
            local c = Fixture.combat(board(),
                { unit("character_knight", 2, 2, { isolate = "bare", items = { "utility_the_gilded_crown" } }) },
                { unit("character_dwarf_delver", 8, 8) })
            local bearer = c.units[1]
            for _, item in ipairs(Character.eachItem(bearer.char)) do
                for _, b in ipairs(require("models.curse").openingBoons(item)) do
                    Status.apply(c, bearer, b.id, b.opts)
                end
            end
            assert(Status.has(bearer, "status_gilded"), "the bearer is Gilded at the bell")
            local covets = false
            for _, rule in ipairs(Character.defs["character_dwarf_delver"].ai or {}) do
                if rule.targetPref == "gilded" then covets = true end
            end
            assert(covets, "and a living dwarf goes for the gilded first")
        end,
    },

    -- ------------------------------------------------------------------------------ Gilded Bread
    {
        name = "Gilded Bread: its bearer cannot be healed",
        fn = function()
            local c, b = bakery(500, 0)
            b.char.stats.health.current = 50
            assert(Combat.applyHeal(c, b, 20) == 0 and hp(b) == 50, "no heal reaches the bearer")
            assert(bake(c, b, b, 100), "the cast on itself resolves")
            assert(hp(b) == 50, "the bread does not feed the one who holds it")
        end,
    },
    {
        name = "Gilded Bread: five gold a point, paid only for what it heals",
        fn = function()
            local c, b, f, purse = bakery(500, 10)
            assert(bake(c, b, f, 100), "the bread is broken")
            assert(hp(f) == 100, "ten points healed")
            assert(purse() == 450, "fifty gold paid for them -- not the hundred dialed")
        end,
    },
    {
        name = "Gilded Bread: it cannot heal past the purse",
        fn = function()
            local c, b, f, purse = bakery(12, 40)
            assert(bake(c, b, f, 150))
            assert(hp(f) == 62, "twelve gold buys two points")
            assert(purse() == 2, "and two coppers are left, not spent on nothing")
        end,
    },
    {
        name = "Gilded Bread: without a purse it is inert, and a heal that cannot land is never bought",
        fn = function()
            local c, b, f = bakery(nil, 30)
            assert(bake(c, b, f, 100))
            assert(hp(f) == 70, "no campaign purse, no bread")
            -- The King, stood on the baker's own side so the bread may aim at him: a heal on him would be a
            -- heap, so the gold stays in the purse.
            local c2 = Fixture.combat(board(8),
                { unit("character_knight", 2, 2, { isolate = "bare", items = { "ability_gilded_bread" },
                    stats = { stamina = 99 } }), unit(KING, 2, 3) },
                { unit("character_bandit", 7, 7, { isolate = "bare" }) })
            local baker, king = c2.units[1], c2.units[2]
            king.char.stats.health.current = 50
            local purse = givePurse(c2, 300)
            local item = itemNamed(baker.char, "ability_gilded_bread")
            openTurn(c2, baker)
            Combat.useItem(c2, baker, item, king.x, king.y, nil, nil, 100)
            assert(purse() == 300, "not a coin is spent on a body that turns it to gold")
        end,
    },
    {
        name = "Gilded Bread: the dial rides the Gilded Wound's slider, read as health",
        fn = function()
            local ab = Item.instantiate("ability_gilded_bread").activeAbility
            assert(Item.isPurchasable(ab), "a purchasable cast")
            local rate, cap = Item.purchaseRate(ab)
            assert(rate == 5 and cap == 30, "five gold a point, thirty points a cast")
            assert(ab.purchase.unit == "hp", "the chooser reads it in health")
        end,
    },
}
