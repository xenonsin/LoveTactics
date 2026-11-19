-- THE CREATURE IDENTITY PASS, Gluttony and Lust (floors 1-4), 2026-11-19.
--
-- An audit put every fielded body through one test: does meeting it change what you BRING, where you
-- STAND, or who you kill FIRST? The bodies and patterns below failed it, the author approved a lever for
-- each, and each case here plays the lever on a bare board rather than checking that a field exists:
--
--   * the Blooded Knight takes the blow aimed at the succubus beside him      (Order / Position)
--   * a Shoalkin is hard to hit in the water and ordinary on the bank         (Position / Bring)
--   * the Brackish Lance knocks a body it finds already Wet back a tile       (Position)
--   * the Nymph's Springwater heals per plant of hers standing                 (Order: cut the plants)
--   * the harpy and the lamia want different things brought                   (Bring)
--   * the Sabertooth and the Longfang are two bodies, not one loop             (Order)
--   * the cats and the wyverns no longer ask for the wolves' mace              (Bring)
--   * the families of the two circles choose their targets by different rules (who gets hit)
--
-- Combat.FORCE_HIT is pinned on for every case by the runner; the one case about Avoid reads the number
-- the dice would be rolled against rather than rolling them.

local AI = require("models.ai")
local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Terrain = require("models.terrain")
local Fixture = require("tests.support.fixture")

local unit, hp, itemNamed, openTurn = Fixture.unit, Fixture.hp, Fixture.itemNamed, Fixture.openTurn

-- A sturdy company body that strikes with a sword and carries nothing that reacts.
local function swordsman(x, y)
    return unit("character_knight", x, y, { isolate = "bare", items = { "weapon_iron_sword" },
        stats = { health = 300 } })
end

-- A punching bag: no kit, no armour, a deep pool, so a number read off it is the blow and nothing else.
local function dummy(id, x, y, health)
    return unit(id or "character_bandit", x, y, { isolate = "bare", stats = { health = health or 300, defense = 0 } })
end

local function find(c, id)
    for _, u in ipairs(c.units) do if u.char.id == id then return u end end
end

-- A single unit as it fights: blueprint resist plus race plus every passive in its grid, folded.
local function fighting(id)
    local c = Fixture.combat(Fixture.new(8, 8), { dummy(nil, 1, 1) }, { unit(id, 6, 6) })
    return c, c.units[2]
end

local function prefsOf(id)
    local out = {}
    for _, rule in ipairs(Character.defs[id].ai or {}) do
        if rule.targetPref then out[#out + 1] = rule.targetPref end
    end
    return out
end

return {
    -- ------------------------------------------------------------------------------ the Knight
    {
        name = "the Blooded Knight takes the blow aimed at the succubus beside him; the generic knight does not",
        fn = function()
            for _, case in ipairs({ { id = "character_blooded_knight", guards = true },
                                    { id = "character_knight", guards = false } }) do
                local map = Fixture.new(10, 10)
                local c = Fixture.combat(map, { swordsman(5, 4) },
                    { unit("character_lesser_succubus", 5, 5, { stats = { health = 300 } }),
                      unit(case.id, 6, 5, { stats = { health = 300 } }) })
                local hero, her, him = c.units[1], c.units[2], c.units[3]
                local herBefore, himBefore = hp(her), hp(him)
                assert(Fixture.strike(c, hero, her, "weapon_iron_sword"), "the swing is legal")
                if case.guards then
                    assert(hp(her) == herBefore, "the blow meant for her never reaches her")
                    assert(hp(him) < himBefore, "the Blooded Knight takes it instead")
                else
                    assert(hp(her) < herBefore, "a plain knight stands beside her and lets it land")
                end
            end
        end,
    },
    {
        name = "the Blooded Knight's guard cools down: the second blow in the same breath lands on her",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10), { swordsman(5, 4), swordsman(4, 5) },
                { unit("character_lesser_succubus", 5, 5, { stats = { health = 300 } }),
                  unit("character_blooded_knight", 6, 5, { stats = { health = 300 } }) })
            local a, b, her = c.units[1], c.units[2], c.units[3]
            local before = hp(her)
            Fixture.strike(c, a, her, "weapon_iron_sword")
            assert(hp(her) == before, "the first blow is his")
            Fixture.strike(c, b, her, "weapon_iron_sword")
            assert(hp(her) < before, "a cheap first blow draws the guard, and the real one lands")
        end,
    },
    {
        name = "the three Lust fights that field a knight field the Blooded Knight",
        fn = function()
            local Encounter = require("models.encounter")
            for _, id in ipairs({ "encounter_lust_the_long_gallery", "encounter_lust_the_chapter_house",
                                  "encounter_lust_the_lady_chapel" }) do
                local list = Encounter.get(id).composition({ depth = 4, rung = 2, biome = "swamp", seed = 3 })
                local blooded, plain = 0, 0
                for _, b in ipairs(list) do
                    if b == "character_blooded_knight" then blooded = blooded + 1 end
                    if b == "character_knight" then plain = plain + 1 end
                end
                assert(blooded >= 1 and plain == 0, id .. " fields the Blooded Knight")
            end
        end,
    },

    -- ------------------------------------------------------------------------------ the Shoalkin
    {
        name = "a Shoalkin in the water is 25 harder to hit than the same Shoalkin on the bank",
        fn = function()
            local water = Terrain.get("water")
            local map = Fixture.new(8, 8, { tiles = { { x = 5, y = 5, type = "water", moveCost = water.moveCost,
                walkable = true, sightCost = 0, tags = water.tags, swim = true } } })
            local c = Fixture.combat(map, { dummy(nil, 1, 1) }, { unit("character_shoalkin", 5, 5) })
            local fish = c.units[2]
            assert(itemNamed(fish.char, "utility_lying_low"), "the cover is creature kit on its grid")
            local wet = Combat.avoid(c, fish)
            fish.x = 6
            local dry = Combat.avoid(c, fish)
            assert(wet - dry == 25, string.format("Lying Low is worth 25 in the water (%d vs %d)", wet, dry))
        end,
    },
    {
        name = "the Shoalkin swings for the blow that ends somebody",
        fn = function()
            local prefs = prefsOf("character_shoalkin")
            assert(prefs[1] == "lethal", "a Shoalkin's rule is `lethal`, not the circle's old `lowest_hp`")
        end,
    },

    -- ------------------------------------------------------------------------------ the Fen Lancer
    {
        name = "the Brackish Lance knocks a body it finds already Wet back a tile, and leaves a dry one standing",
        fn = function()
            for _, soaked in ipairs({ true, false }) do
                local c = Fixture.combat(Fixture.new(8, 8),
                    { dummy(nil, 3, 4) },
                    { unit("character_fen_lancer", 2, 4, { isolate = "bare", items = { "weapon_brackish_lance" } }) })
                local man, lancer = c.units[1], c.units[2]
                if soaked then assert(Status.apply(c, man, "status_wet"), "a man soaks") end
                openTurn(c, lancer)
                assert(Combat.useItem(c, lancer, lancer.char.inventory[1], 3, 4), "the thrust is legal")
                if soaked then
                    assert(man.x == 4 and man.y == 4, "a soaked body is driven one tile along the thrust")
                else
                    assert(man.x == 3 and man.y == 4, "a dry body is skewered where it stands")
                end
            end
        end,
    },
    {
        name = "a soaked body on the channel's bank goes under; the first thrust soaks, the second drowns",
        fn = function()
            local deep = Terrain.get("deep")
            local map = Fixture.new(8, 8, { tiles = { { x = 5, y = 4, type = "deep", moveCost = deep.moveCost,
                walkable = deep.walkable, sightCost = deep.sightCost, tags = deep.tags, swim = deep.swim,
                drowns = deep.drowns } } })
            map.hazards = { { id = "hazard_deep_water", x = 5, y = 4, duration = 9999 } }
            local c = Fixture.combat(map, { dummy(nil, 3, 4), dummy(nil, 4, 4) },
                { unit("character_fen_lancer", 2, 4, { isolate = "bare", items = { "weapon_brackish_lance" } }) })
            local near, far, lancer = c.units[1], c.units[2], c.units[3]
            openTurn(c, lancer)
            Combat.useItem(c, lancer, lancer.char.inventory[1], 3, 4)
            assert(far.alive and far.x == 4 and Status.has(far, "status_wet"), "the first thrust soaks the far rank")
            openTurn(c, lancer)
            Combat.useItem(c, lancer, lancer.char.inventory[1], 3, 4)
            assert(not far.alive and far.sank, "the second drives the soaked body into the deep, and it goes under")
            assert(near.alive and near.x == 3, "the dry body on the point is skewered and stays put")
        end,
    },

    -- ------------------------------------------------------------------------------ the Nymph
    {
        name = "Springwater heals for each plant of hers standing: cut the saplings and the spring runs dry",
        fn = function()
            local function healed(saplings)
                local enemies = { unit("character_nymph", 5, 5), unit("character_nymph", 5, 6) }
                for i = 1, saplings do enemies[#enemies + 1] = unit("character_sapling", 7 + i, 8) end
                local c = Fixture.combat(Fixture.new(12, 12), { dummy(nil, 1, 1) }, enemies)
                local nymph = c.units[2]
                local patient = c.units[3]
                patient.char.stats.health.current = 2
                openTurn(c, nymph)
                assert(Combat.useItem(c, nymph, itemNamed(nymph.char, "weapon_springwater"), patient.x, patient.y),
                    "she can mend her sister")
                return hp(patient) - 2
            end
            local bare, one, three = healed(0), healed(1), healed(3)
            assert(one > bare and three > one, string.format(
                "the heal climbs with the grove (none %d, one %d, three %d)", bare, one, three))
            assert(three - one == 6, "three for each plant standing")
        end,
    },

    -- ------------------------------------------------------------------------------ Lust's two Bring questions
    {
        name = "the harpy wants holy brought and the lamia wants ice: one circle, two answers",
        fn = function()
            for _, pair in ipairs({ { "character_harpy", "character_lamia" },
                                    { "character_harpy_matriarch", "character_elder_lamia" } }) do
                local _, bird = fighting(pair[1])
                local _, snake = fighting(pair[2])
                local holyBird = Combat.mitigatedDamage(bird, 30, { "holy", "magical" })
                local holySnake = Combat.mitigatedDamage(snake, 30, { "holy", "magical" })
                local iceBird = Combat.mitigatedDamage(bird, 30, { "ice", "magical" })
                local iceSnake = Combat.mitigatedDamage(snake, 30, { "ice", "magical" })
                -- Each body measured against ITSELF, so the two bodies' different magic defence cancels out
                -- and what is left is which element each one is open to.
                assert(holyBird > iceBird, pair[1] .. " takes a Smite harder than frost")
                assert(iceSnake > holySnake, pair[2] .. " takes frost harder than a Smite")
                assert((snake.resist.holy or 0) < 0, pair[2] .. " is still a demon: holy still finds it")
            end
        end,
    },

    -- ------------------------------------------------------------------------------ the pride
    {
        name = "the pride is two bodies: the Sabertooth hides and does not strike back; the Longfang strikes back in the open",
        fn = function()
            local function counters(id)
                local c = Fixture.combat(Fixture.new(9, 9), { swordsman(4, 5) },
                    { unit(id, 5, 5, { stats = { health = 300 } }) })
                local hero, cat = c.units[1], c.units[2]
                local before = hp(hero)
                Fixture.strike(c, hero, cat, "weapon_iron_sword")
                return hp(hero) < before, cat
            end
            local struckBack = counters("character_the_longfang")
            assert(struckBack, "struck in melee, the Longfang strikes straight back")
            local quiet = counters("character_sabertooth")
            assert(not quiet, "the Sabertooth does not: the round after its pounce is free to hit it in")
        end,
    },

    -- ------------------------------------------------------------------------------ the hides
    {
        name = "Gluttony's hides ask three questions: the wolves a mace, the cats a blade, the wyverns a point",
        fn = function()
            local function takes(id, tag)
                local _, u = fighting(id)
                return Combat.mitigatedDamage(u, 30, { "physical", tag })
            end
            for _, id in ipairs({ "character_wolf_grunt", "character_white_wolf" }) do
                assert(takes(id, "impact") > takes(id, "slash"), id .. ": a mace, as before")
            end
            for _, id in ipairs({ "character_sabertooth", "character_the_longfang" }) do
                assert(takes(id, "slash") > takes(id, "impact"), id .. ": an edge opens a cat; a club is soaked")
            end
            for _, id in ipairs({ "character_wyvern", "character_wyvern_alpha", "character_the_highwing" }) do
                assert(takes(id, "pierce") > takes(id, "impact"), id .. ": a point goes through the wing")
                assert(takes(id, "pierce") > takes(id, "slash"), id .. ": and an edge still slides off the scale")
            end
        end,
    },

    -- ------------------------------------------------------------------------------ who gets hit
    {
        name = "the families choose their targets by different rules, and every rule is one the planner knows",
        fn = function()
            local known = {}
            for _, p in ipairs(AI.TARGET_PREF_ORDER) do known[p] = true end
            local want = {
                character_wolf_grunt = "lowest_hp",      -- the pack pulls down the wounded
                character_sabertooth = "lethal",         -- the ambusher takes the body its bite ends
                character_the_longfang = "nearest",      -- the leader fights the front she draws
                character_manticore = "lethal",          -- what falls beside it is eaten
                character_giant_toad = "hazardous",      -- hauled across bad ground
                character_giant_spider = "hemmed",       -- the body with nowhere to go
                character_griffin = "nearest",           -- it bites back, so it trades with what is in front
                character_harpy = "hazardous",           -- snatched or shoved onto bad ground
                character_lamia = "nearest",             -- the coils want the front rank, alive and moving
                character_shoalkin = "lethal",
                character_blooded_knight = "nearest",    -- whoever walked up to her
            }
            for id, pref in pairs(want) do
                local prefs = prefsOf(id)
                local has = false
                for _, p in ipairs(prefs) do
                    assert(known[p], id .. " names a preference the planner does not know: " .. p)
                    if p == pref then has = true end
                end
                assert(has, id .. " targets by `" .. pref .. "`")
            end
            -- The circle's old default is now the minority among the families above.
            local lowest = 0
            for id in pairs(want) do
                for _, p in ipairs(prefsOf(id)) do if p == "lowest_hp" then lowest = lowest + 1 end end
            end
            assert(lowest <= 1, "only the wolves still dive the wounded first")
        end,
    },
    {
        name = "the Shoalkin takes the kill over the most wounded body",
        fn = function()
            -- Two foes in reach of the knife. The big one is the most wounded by share and no knife ends it;
            -- the small one is less wounded and one cut from falling.
            local c = Fixture.combat(Fixture.new(9, 9),
                { dummy(nil, 4, 5, 400), dummy(nil, 6, 5, 40) },
                { unit("character_shoalkin", 5, 5) })
            local big, small, fish = c.units[1], c.units[2], c.units[3]
            big.char.stats.health.current = 60    -- 15%
            small.char.stats.health.current = 8   -- 20%, and one cut ends it
            openTurn(c, fish)
            local plan = AI.plan(c, fish)
            assert(plan and plan.tx == small.x and plan.ty == small.y, "the Shoalkin goes for the body it can finish")
        end,
    },
}
