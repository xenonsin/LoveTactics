-- Tests for THE WASTING ONES (round 4 of "Envy's Bestiary", approved 2026-10-06): the two bodies Envy's approach
-- still owed, from Ovid's Envy, who never smiles except at another's pain and wastes at the sight of their success.
--
--   Wasting One     the Thin Smile: every wound a foe takes in its sight heals it by 2
--   The Pale Crone  Grief at Your Fortune: a foe healed or blessed in her sight is leapt on and struck, once a round
--
-- Each case pins a rule the review approved, on a bare board, plus the drops (which run the same traits pointed
-- the other way) and the three fights.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_wasting_one = { tier = 2, organ = "utility_smiles_at_pain", drop = "utility_the_thin_smile", class = "plague_knight" },
    character_pale_crone = { tier = 3, organ = "utility_grief_at_fortune", drop = "utility_thorned_staff", class = "skirmisher" },
}
local FIGHTS = {
    encounter_envy_the_thin_smile = { "character_wasting_one" },
    encounter_envy_where_envy_lives = { "character_pale_crone", "character_wasting_one" },
    encounter_envy_begrudged = { "character_pale_crone", "character_evil_eye" },
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 100, health or 100
    return spawn
end

local function board(tiles) return Fixture.new(11, 11, { tiles = tiles }) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function hit(c, target, amount, attacker)
    return Combat.dealFlatDamage(c, target, amount, { "physical" }, "test", attacker, { raw = true })
end

local function wound(u, by) u.char.stats.health.current = u.char.stats.health.current - by end

local MOUNTAIN = { type = "mountain", walkable = false, moveCost = 99, sightCost = 99 }
local function ridge(...)
    local out = {}
    for _, x in ipairs({ ... }) do
        local t = { x = x, y = 4 }
        for k, v in pairs(MOUNTAIN) do t[k] = v end
        out[#out + 1] = t
    end
    return out
end

-- The fight is under way: a heal or a blessing before the first turn is an opening boon, and nobody saw it.
local function begun(c) c.turnCount = 1 end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "two demons of Envy, each with its organ and its trophy on a real shelf",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.race == "demon", id .. " is a demon")
                assert(def.tier == want.tier, id .. " stands on tier " .. want.tier)
                local c = Character.instantiate(id)
                assert(itemNamed(c, want.organ), id .. " carries " .. want.organ)
                assert(def.drops and def.drops[1] == want.drop, id .. " drops " .. want.drop)
                local drop = Item.defs[want.drop]
                assert(drop.class == want.class, want.drop .. " is " .. want.class .. " stock")
                assert(drop.unstocked and not drop.price, want.drop .. " is a trophy: on the rack, never sold")
                assert(drop.unlockLevel == 11, want.drop .. " sits at the approach's rung")
                local organ = Item.defs[want.organ]
                assert(organ.class == "creature" and organ.noSteal, want.organ .. " is a body's own")
            end
            -- The bodies' own blows: a demon's burns, on the physical channel, and neither is ever loot.
            for _, id in ipairs({ "weapon_viper_fed_bite", "weapon_withering_staff" }) do
                local w = Item.defs[id]
                assert(w and w.class == "creature" and w.noSteal, id .. " is a body's own")
                local tags = {}
                for _, t in ipairs(w.tags) do tags[t] = true end
                assert(tags.fire and tags.physical, id .. " burns, as a physical blow")
            end
        end,
    },
    {
        name = "three approach fights stand on the waste, one of them mixed with the Evil Eye",
        fn = function()
            for id, bodies in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == "combat", id .. " is ordinary traffic")
                assert(e.rung == 1 and e.weight == 5, id .. " is homed on the approach at weight 5")
                assert(e.condition({ biome = "desert" }) and not e.condition({ biome = "spire" }), id .. " is desert-locked")
                local comp = type(e.composition) == "function"
                    and e.composition({ biome = "desert", rung = 1, depth = 11, floorLevel = 33 }) or e.composition
                local has = {}
                for _, b in ipairs(comp) do has[b] = true end
                for _, b in ipairs(bodies) do assert(has[b], id .. " fields " .. b) end
            end
        end,
    },
    -- ------------------------------------------------------------------------------ the Thin Smile
    {
        name = "the Thin Smile: a wound the company takes in a Wasting One's sight heals it by 2",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8), { unit("character_wasting_one", 5, 2) })
            local body, smiler = c.units[1], one(c, "character_wasting_one")
            wound(smiler, 10)
            local before = hp(smiler)
            hit(c, body, 7)
            assert(hp(smiler) == before + 2, "it smiles, and is fed by 2")
            hit(c, smiler, 5)
            assert(hp(smiler) == before + 2 - 5, "a wound on its own side feeds nothing")
        end,
    },
    {
        name = "the Thin Smile: behind a ridge it sees nothing, and is fed nothing",
        fn = function()
            local c = Fixture.combat(board(ridge(4, 5, 6)), walker(5, 8), { unit("character_wasting_one", 5, 2) })
            local body, smiler = c.units[1], one(c, "character_wasting_one")
            wound(smiler, 10)
            local before = hp(smiler)
            hit(c, body, 7)
            assert(hp(smiler) == before, "the ridge hides the wound")
        end,
    },
    -- ------------------------------------------------------------------------------ Grief at Your Fortune
    {
        name = "Grief at Your Fortune: a heal in her sight marks the leap, and the turn's end throws it",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8), { unit("character_pale_crone", 5, 2) })
            local body, crone = c.units[1], one(c, "character_pale_crone")
            begun(c)
            wound(body, 30)
            Combat.applyHeal(c, body, 10)
            assert(crone.lungeAt == body, "the heal is seen")
            local before = hp(body)
            Trait.onAnyTurnEnd(c, body)
            assert(Combat.unitGap(crone, body) == 1, "she is beside it")
            assert(hp(body) < before, "and has struck")

            Combat.applyHeal(c, body, 5)
            assert(not crone.lungeAt, "once a round: a second heal is not answered")
            Trait.onAnyTurnEnd(c, crone)
            assert(not crone.griefSpent, "her own turn re-arms it")
        end,
    },
    {
        name = "Grief at Your Fortune: a fresh blessing is seen; an opening boon and a heal behind a ridge are not",
        fn = function()
            local c = Fixture.combat(board(), walker(5, 8), { unit("character_pale_crone", 5, 2) })
            local body, crone = c.units[1], one(c, "character_pale_crone")
            Status.apply(c, body, "status_hasted")
            assert(not crone.lungeAt, "a boon worn in at the bell was never seen")
            Status.remove(c, body, "status_hasted")
            begun(c)
            Status.apply(c, body, "status_hasted")
            assert(crone.lungeAt == body, "a blessing landed mid-fight is")

            local c2 = Fixture.combat(board(ridge(4, 5, 6)), walker(5, 8), { unit("character_pale_crone", 5, 2) })
            local b2, crone2 = c2.units[1], one(c2, "character_pale_crone")
            begun(c2)
            wound(b2, 30)
            Combat.applyHeal(c2, b2, 10)
            assert(not crone2.lungeAt, "behind a ridge the heal goes unseen")
        end,
    },
    -- ------------------------------------------------------------------------------ the trophies
    {
        name = "the trophies run the same rules for the company: the smile heals, the staff leaps within 3",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 5, 8, { isolate = "bare", items = { "utility_the_thin_smile" } }),
                { walker(5, 2) })
            local knight, foe = c.units[1], c.units[2]
            wound(knight, 10)
            local before = hp(knight)
            hit(c, foe, 7)
            assert(hp(knight) == before + 2, "the Thin Smile heals its bearer off a foe's wound")

            local c2 = Fixture.combat(board(),
                unit("character_archer", 5, 8, { isolate = "bare", items = { "utility_thorned_staff", "weapon_iron_sword" } }),
                { walker(5, 5), walker(5, 1) })
            local skirm, near, far = c2.units[1], c2.units[2], c2.units[3]
            begun(c2)
            wound(far, 30)
            Combat.applyHeal(c2, far, 10)
            assert(not skirm.lungeAt, "seven tiles off is beyond the staff's reach of 3")
            wound(near, 30)
            Combat.applyHeal(c2, near, 10)
            assert(skirm.lungeAt == near, "three tiles off is within it")
            local before2 = hp(near)
            Trait.onAnyTurnEnd(c2, near)
            assert(Combat.unitGap(skirm, near) == 1 and hp(near) < before2, "it leaps beside and strikes")
        end,
    },
}
