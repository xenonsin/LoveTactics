-- Tests for THE DJINN OF PRIDE (2026-09-30, reviewed on "Pride's Bestiary"): the race, its family rule, the three
-- djinn and their spells, the Wishmaker and her Lamp, the fights and the drops.
--
--   Will Not Stoop   a djinn casts and never swings; a foe beside it when its turn opens sends it blinking, free,
--                    to the open tile within 4 farthest from its foes, and with nowhere to go it is Shamed and
--                    loses the turn
--   the Djinni       its gale pushes every body in a line 2 tiles (Djinni's Breath, its drop)
--   the Ifrit        its bolt sets the tile alight and lays a Fire Trail; it drops Ifrit's Coal
--   the Marid        its tide floods a 3x3 Wet and heals it per Wet foe (Marid's Tide, its drop)
--   the Wishmaker    an elf archmage whose Lamp grants a wish at each third of her health -- whole again, the
--                    company's best boon, a Great Djinn held at 1 while the Lamp stands; she drops The Last Lamp
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Race = require("models.race")
local Status = require("models.status")
local Trait = require("models.trait")
local Djinn = require("models.djinn")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local DJINN = { "character_djinni", "character_ifrit", "character_marid", "character_great_djinn" }
local TROPHIES = {
    ability_djinnis_breath = { class = "mage", by = "character_djinni",
        text = "Push every body in a line 2 tiles." },
    utility_ifrits_coal = { class = "elementalist", by = "character_ifrit",
        text = "Your fire spells set the target's tile alight." },
    ability_marids_tide = { class = "druid", by = "character_marid",
        text = "Flood a 3x3 area: every body inside is Wet, and you heal for each Wet foe." },
    utility_the_last_lamp = { class = "summoner", by = "character_the_wishmaker",
        text = "Once a fight, below a third of your health: become a djinn for 3 turns. +4 magic damage; blink from foes beside you." },
}
local ORGANS = { "utility_will_not_stoop", "ability_ifrits_flame", "utility_three_wishes", "utility_the_lamp",
    "ability_marids_flood" }
local FIGHTS = {
    encounter_pride_smoke_and_gale = { rung = 1, kind = "combat" },
    encounter_pride_the_tide = { rung = 1, kind = "combat" },
    encounter_pride_gilt_and_smoke = { rung = 1, kind = "combat" },
    encounter_pride_the_wishmaker = { rung = 2, kind = "elite" },
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

-- A board with enemies (spec rows { id, x, y }) and a company.
local function board(spec, party, cols, rows)
    local enemies = {}
    for _, s in ipairs(spec) do enemies[#enemies + 1] = unit(s[1], s[2], s[3], s[4]) end
    return Fixture.combat(Fixture.new(cols or 11, rows or 11), party or walker(1, 1), enemies)
end

-- Make `u` the next to act and open its turn the way the game does.
local function startTurnOf(c, u)
    for _, other in ipairs(c.units) do other.initiative = (other == u) and 0 or 100 end
    local opened = Combat.startTurn(c)
    assert(opened == u, "the turn opened on the body under test")
    return opened
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

-- Set `u` to exactly `n` health.
local function setHp(u, n) u.char.stats.health.current = n end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the djinn are a masterless race of casters, kind elemental, and Will Not Stoop is the race's grant",
        fn = function()
            local race = Race.get("djinn")
            assert(race and race.kind == "elemental" and race.playable == false, "a djinn serves no one")
            for _, id in ipairs(DJINN) do
                local def = Character.defs[id]
                assert(def and def.race == "djinn", id .. " is a djinn")
                assert(def.unarmed == false, id .. " has no fists: it never swings")
                local c = Character.instantiate(id)
                assert(itemNamed(c, "utility_will_not_stoop"), id .. ": the race put Will Not Stoop in the grid")
                for _, item in ipairs(Character.eachItem(c)) do
                    assert(item.type ~= "weapon", id .. " carries no weapon: " .. item.id)
                end
            end
            assert(Character.defs["character_djinni"].tier == 2 and Character.defs["character_ifrit"].tier == 2,
                "the Djinni and the Ifrit are tier 2")
            assert(Character.defs["character_marid"].tier == 3, "the Marid is tier 3")
            local wm = Character.defs["character_the_wishmaker"]
            assert(wm.race == "elf" and wm.boss and wm.tier == 3, "the Wishmaker is an elf archmage, and a boss")
            local lamp = Character.defs["character_the_lamp"]
            assert(lamp.race == "object" and lamp.timeless and lamp.scaling == false, "the Lamp is an object body")
        end,
    },
    {
        name = "every djinn trophy is an unstocked find on the right body's drop list, on its approved shelf",
        fn = function()
            for id, want in pairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(def.class == want.class, id .. " sits on the " .. want.class .. " shelf")
                assert(def.description == want.text, id .. " reads as approved")
                local found = false
                for _, d in ipairs(Character.defs[want.by].drops or {}) do found = found or d == id end
                assert(found, id .. " drops from " .. want.by)
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own")
                if def.type == "utility" then assert(def.bound, id .. " is bound") end
            end
        end,
    },
    {
        name = "three djinn fights stand on the spire's approach, and the Wishmaker is the seat's elite",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.rung == want.rung and e.kind == want.kind, id .. " is a rung-" .. want.rung .. " " .. want.kind)
                assert(e.condition({ biome = "spire" }) and not e.condition({ biome = "cave" }),
                    id .. " is locked to the spire")
            end
            local list = Encounter.get("encounter_pride_the_wishmaker").composition({ depth = 14, rung = 2 })
            local seen = {}
            for _, id in ipairs(list) do seen[id] = true end
            assert(seen.character_the_wishmaker and seen.character_the_lamp, "she is dealt with her Lamp")
            local mixed = Encounter.get("encounter_pride_gilt_and_smoke").composition({ depth = 13, rung = 1 })
            local pages = 0
            for _, id in ipairs(mixed) do if id == "character_gilded_page" then pages = pages + 1 end end
            assert(pages >= 1, "the mixed fight stands an Ifrit behind Pride's own pages")
        end,
    },
    -- ------------------------------------------------------------------------------ Will Not Stoop
    {
        name = "Will Not Stoop: a djinn whose turn opens beside a foe blinks clear, free, and keeps its turn",
        fn = function()
            local c = board({ { "character_djinni", 5, 5 } }, walker(5, 6))
            local foe, d = c.units[1], one(c, "character_djinni")
            local mana = Combat.resource(d.char, "mana")
            startTurnOf(c, d)
            assert(d.x ~= 5 or d.y ~= 5, "it left the tile beside the foe")
            assert(math.abs(d.x - 5) + math.abs(d.y - 5) <= 4, "within 4")
            assert(Combat.unitGap(d, foe) >= 3, "to the tile farthest from its foe: " .. Combat.unitGap(d, foe))
            assert(Combat.resource(d.char, "mana") == mana, "free")
            assert(not Status.has(d, "status_shamed"), "and not Shamed")
            assert(not c.turn.moved and not Combat.itemBlockReason(d, itemNamed(d.char, "ability_djinnis_breath")),
                "the whole turn is still its own")
        end,
    },
    {
        name = "Will Not Stoop: a djinn with no foe beside it does not move",
        fn = function()
            local c = board({ { "character_ifrit", 5, 5 } }, walker(5, 8))
            local d = one(c, "character_ifrit")
            startTurnOf(c, d)
            assert(d.x == 5 and d.y == 5, "nothing to flee")
        end,
    },
    {
        name = "Will Not Stoop: boxed in, a djinn is Shamed and loses the turn; it ends with the turn",
        fn = function()
            -- A corridor two tiles long: the djinni at one end, the foe at the other. Nowhere to blink.
            local c = board({ { "character_djinni", 1, 1 } }, walker(2, 1), 2, 1)
            local d = one(c, "character_djinni")
            startTurnOf(c, d)
            assert(d.x == 1 and d.y == 1, "nowhere to go")
            assert(Status.has(d, "status_shamed"), "so it is Shamed")
            assert(Combat.itemBlockReason(d, itemNamed(d.char, "ability_djinnis_breath")), "it cannot act")
            assert(Status.blocksMove(d), "or move")
            assert(not Status.get(d, "status_shamed").def.debuff, "a price of its own pride: no Cure lifts it")
            Combat.wait(c, d)
            assert(not Status.has(d, "status_shamed"), "and it ends when the turn does")
        end,
    },
    {
        name = "Will Not Stoop: a rooted djinn cannot blink, and is Shamed",
        fn = function()
            local c = board({ { "character_marid", 5, 5 } }, walker(5, 6))
            local d = one(c, "character_marid")
            Status.apply(c, d, "status_root", { duration = 20 })
            assert(Djinn.willNotStoop(c, d) == "shamed", "Root holds a blink as it holds a walk")
            assert(d.x == 5 and d.y == 5, "and it stays")
        end,
    },
    {
        name = "Will Not Stoop: it will not land beside another foe",
        fn = function()
            -- Foes ring the djinn's reach: everything within 4 that is not beside one of them is the far corner.
            local c = board({ { "character_djinni", 5, 5 } }, { walker(5, 6), walker(3, 5), walker(7, 5) })
            local d = one(c, "character_djinni")
            Djinn.willNotStoop(c, d)
            for _, u in ipairs(c.units) do
                if u.side == "party" then assert(Combat.unitGap(d, u) > 1, "it landed beside a foe") end
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the three spells
    {
        name = "Djinni's Breath pushes every body in the line 2 tiles, the far one first",
        fn = function()
            local c = board({ { "character_djinni", 5, 2 } }, { walker(5, 3), walker(5, 5) })
            local near, far = c.units[1], c.units[2]
            local d = one(c, "character_djinni")
            openTurn(c, d)
            assert(Combat.useItem(c, d, itemNamed(d.char, "ability_djinnis_breath"), 5, 3), "the gale is cast")
            assert(far.y == 7, "the far body is pushed 2: " .. far.y)
            assert(near.y == 5, "and the near one 2, into the ground the far one left: " .. near.y)
        end,
    },
    {
        name = "Ifrit's Flame sets the target's tile alight and its Fire Trail burns each tile it is pushed through",
        fn = function()
            local c = board({ { "character_ifrit", 5, 2 } }, walker(5, 5))
            local foe, d = c.units[1], one(c, "character_ifrit")
            openTurn(c, d)
            assert(Combat.useItem(c, d, itemNamed(d.char, "ability_ifrits_flame"), foe.x, foe.y), "the bolt is cast")
            assert(Hazard.at(c, 5, 5, "hazard_fire"), "the struck tile is alight")
            assert(Status.has(foe, "status_fire_trail"), "and the foe trails fire")
            Combat.knockback(c, d, foe, 2)
            assert(foe.y == 7, "pushed two")
            assert(Hazard.at(c, 5, 6, "hazard_fire") and Hazard.at(c, 5, 7, "hazard_fire"),
                "every tile it was pushed through caught")
            assert(Status.has(foe, "status_burn"), "and it burns")
        end,
    },
    {
        name = "Ifrit's Coal: the bearer's fire spells set the target's tile alight, and nothing else does",
        fn = function()
            local hero = Fixture.unit("character_rowan", 5, 2, { isolate = "bare",
                items = { "utility_ifrits_coal", "ability_fire_bolt", "ability_ice_bolt" },
                stats = { mana = 100 } })
            local c = Fixture.combat(Fixture.new(11, 11), hero, { unit("character_gilded_page", 5, 4),
                unit("character_gilded_page", 6, 4) })
            local a, b = c.units[2], c.units[3]
            openTurn(c, c.units[1])
            assert(Combat.useItem(c, c.units[1], itemNamed(c.units[1].char, "ability_ice_bolt"), b.x, b.y), "ice")
            assert(not Hazard.at(c, b.x, b.y, "hazard_fire"), "ice lights nothing")
            openTurn(c, c.units[1])
            assert(Combat.useItem(c, c.units[1], itemNamed(c.units[1].char, "ability_fire_bolt"), a.x, a.y), "fire")
            assert(Hazard.at(c, 5, 4, "hazard_fire"), "the fire bolt's target tile is alight")
        end,
    },
    {
        name = "Marid's Tide soaks a 3x3 and heals the Marid for every Wet foe on the board",
        fn = function()
            local c = board({ { "character_marid", 5, 1 } }, { walker(5, 4), walker(6, 5), walker(10, 10) })
            local a, b, far = c.units[1], c.units[2], c.units[3]
            local m = one(c, "character_marid")
            Status.apply(c, far, "status_wet")
            setHp(m, 10)
            openTurn(c, m)
            assert(Combat.useItem(c, m, itemNamed(m.char, "ability_marids_flood"), 5, 4), "the tide is cast")
            assert(Status.has(a, "status_wet") and Status.has(b, "status_wet"), "every body in the square is Wet")
            assert(hp(m) == 10 + 3 * 8, "8 health for each of the three Wet foes: " .. hp(m))
        end,
    },
    -- ------------------------------------------------------------------------------ the Wishmaker
    {
        name = "the Wishmaker: the Lamp is set beside her, and at two-thirds the first wish makes her whole",
        fn = function()
            local c = board({ { "character_the_wishmaker", 5, 5 }, { "character_the_lamp", 9, 9 } }, walker(1, 1))
            local foe, wm, lamp = c.units[1], one(c, "character_the_wishmaker"), one(c, "character_the_lamp")
            assert(Combat.unitGap(wm, lamp) == 1, "her Lamp stands beside her")
            assert(Status.has(wm, "status_unblemished"), "an elf, so Unblemished")
            Combat.dealFlatDamage(c, wm, maxHp(wm) - math.floor(maxHp(wm) * 2 / 3), { "physical" }, "test", foe,
                { raw = true })
            assert(hp(wm) == maxHp(wm), "the first wish: whole again")
            assert(wm.wishes == 1, "one wish spent")
        end,
    },
    {
        name = "the Wishmaker: at one-third the second wish takes the company's strongest boon",
        fn = function()
            local c = board({ { "character_the_wishmaker", 5, 5 }, { "character_the_lamp", 5, 6 } },
                { walker(1, 1), walker(1, 3) })
            local blessed, plain, wm = c.units[1], c.units[2], one(c, "character_the_wishmaker")
            Status.apply(c, blessed, "status_bestowed", {})
            Status.apply(c, plain, "status_djinn_form", {})
            wm.wishes = 1
            setHp(wm, math.floor(maxHp(wm) / 3) + 2)
            Combat.dealFlatDamage(c, wm, 3, { "physical" }, "test", blessed, { raw = true })
            assert(wm.wishes == 2, "the second wish")
            assert(Status.has(wm, "status_bestowed") and not Status.has(blessed, "status_bestowed"),
                "the larger boon moved onto her")
            assert(Status.has(plain, "status_djinn_form"), "and only the one")
        end,
    },
    {
        name = "the Wishmaker: the third wish makes a Great Djinn held at 1 while the Lamp stands; break it and she falls",
        fn = function()
            local c = board({ { "character_the_wishmaker", 5, 5 }, { "character_the_lamp", 5, 6 } }, walker(1, 1))
            local foe, wm, lamp = c.units[1], one(c, "character_the_wishmaker"), one(c, "character_the_lamp")
            wm.wishes = 2
            Combat.dealFlatDamage(c, wm, 9999, { "physical" }, "test", foe, { raw = true })
            assert(wm.alive and hp(wm) == 1, "the blow that would fell her grants the last wish")
            assert(wm.char.id == "character_great_djinn", "and she is a djinn")
            assert(wm.char.boss, "still the objective")
            assert(Trait.flag(wm, "willNotStoop"), "who will not stoop")
            assert(Status.has(wm, "status_lamp_bound"), "Lamp-Bound")
            Combat.dealFlatDamage(c, wm, 9999, { "physical" }, "test", foe, { raw = true })
            assert(wm.alive and hp(wm) == 1, "while the Lamp stands she cannot fall")
            Combat.dealFlatDamage(c, lamp, 9999, { "physical" }, "test", foe, { raw = true })
            assert(not lamp.alive, "the Lamp breaks")
            assert(not Status.has(wm, "status_lamp_bound"), "and its hold goes with it")
            Combat.dealFlatDamage(c, wm, 9999, { "physical" }, "test", foe, { raw = true })
            assert(not wm.alive, "now she falls")
        end,
    },
    {
        name = "the Wishmaker: break the Lamp first and there are no wishes, and she never turns",
        fn = function()
            local c = board({ { "character_the_wishmaker", 5, 5 }, { "character_the_lamp", 5, 6 } }, walker(1, 1))
            local foe, wm, lamp = c.units[1], one(c, "character_the_wishmaker"), one(c, "character_the_lamp")
            Combat.dealFlatDamage(c, lamp, 9999, { "physical" }, "test", foe, { raw = true })
            Combat.dealFlatDamage(c, wm, maxHp(wm) - 5, { "physical" }, "test", foe, { raw = true })
            assert(hp(wm) == 5 and not wm.wishes, "no wish at two-thirds or one-third")
            Combat.dealFlatDamage(c, wm, 9999, { "physical" }, "test", foe, { raw = true })
            assert(not wm.alive and wm.char.id == "character_the_wishmaker", "and she falls an elf")
        end,
    },
    {
        name = "the Wishmaker: one blow from full to nothing is the first wish, never a skip to the djinn",
        fn = function()
            local c = board({ { "character_the_wishmaker", 5, 5 }, { "character_the_lamp", 5, 6 } }, walker(1, 1))
            local foe, wm = c.units[1], one(c, "character_the_wishmaker")
            Combat.dealFlatDamage(c, wm, 9999, { "physical" }, "test", foe, { raw = true })
            assert(wm.alive and hp(wm) == maxHp(wm) and wm.wishes == 1, "whole again")
            assert(wm.char.id == "character_the_wishmaker", "and still herself")
        end,
    },
    {
        name = "The Last Lamp: below a third, Djinn Form once a fight -- +4 magic damage, and a blink from a foe beside",
        fn = function()
            local hero = Fixture.unit("character_rowan", 5, 5, { isolate = "bare", items = { "utility_the_last_lamp" },
                stats = { health = 90 } })
            local c = Fixture.combat(Fixture.new(11, 11), hero, { unit("character_gilded_page", 5, 9) })
            local h, foe = c.units[1], c.units[2]
            Combat.dealFlatDamage(c, h, 50, { "physical" }, "test", foe, { raw = true })
            assert(not Status.has(h, "status_djinn_form"), "not yet below a third")
            Combat.dealFlatDamage(c, h, 15, { "physical" }, "test", foe, { raw = true })
            assert(Status.has(h, "status_djinn_form"), "below a third: a djinn")
            assert(Status.statBonus(h, "magicDamage") >= 4, "+4 magic damage")
            assert(Status.get(h, "status_djinn_form").remaining == 15, "for three turns")
            foe.x, foe.y = 5, 6
            Trait.onAnyTurnEnd(c, foe)
            assert(Combat.unitGap(h, foe) > 1, "a foe came next to it, and it blinked clear")
            Status.remove(c, h, "status_djinn_form")
            Combat.dealFlatDamage(c, h, 2, { "physical" }, "test", foe, { raw = true })
            assert(not Status.has(h, "status_djinn_form"), "once a fight")
        end,
    },
}
