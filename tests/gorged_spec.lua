-- Tests for THE GORGED (Wrath's vampires, reviewed 2026-09-26/27): the elite that drank until it filled the room
-- (character_the_gorged, utility_full_to_bursting / trait_full_to_bursting, hazard_blood_pool, models/gorged.lua)
-- and its drop, the Surfeit Heart (utility_surfeit_heart / trait_surfeit_heart, status_surfeit).
--
--   spill        a blow that wounds it puts a pool on one tile beside it; pools never stack
--   the pool     a vampire in one drinks it dry (Thirst reset, a heal); a living body bleeds, to the Gorged
--   the burst    at half health: the tiles round it flood, it becomes one tile, faster, in Bloodlust for good
--   the Heart    healing past full becomes a shield (capped at 25% of max) that the next hit breaks

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Arena = require("models.arena")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Thirst = require("models.thirst")
local Gorged = require("models.gorged")
local Fixture = require("tests.support.fixture")

local unit, openTurn, hp = Fixture.unit, Fixture.openTurn, Fixture.hp

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function swordsman(x, y, health)
    return unit("character_archer", x, y,
        { isolate = "bare", items = { "weapon_iron_sword" }, stats = { health = health or 300 } })
end

-- The Gorged at (5, 5) -- its body covers (5..6, 5..6) -- on 300 health, plus whatever else the case seats.
local function room(party, others)
    local enemies = { unit("character_the_gorged", 5, 5, { stats = { health = 300 } }) }
    for _, e in ipairs(others or {}) do enemies[#enemies + 1] = e end
    local c = Fixture.combat(Fixture.new(11, 11), party or swordsman(1, 1), enemies)
    return c, one(c, "character_the_gorged")
end

local function wound(c, g, n, by)
    Combat.dealFlatDamage(c, g, n, { "physical" }, "test", by, { raw = true })
end

local function pools(c)
    local out = {}
    for _, h in ipairs(c.hazards or {}) do
        if h.alive and h.id == Gorged.POOL then out[#out + 1] = h end
    end
    return out
end

return {
    {
        name = "the Gorged is a 2x2 human fighter vampire on the boss rung, an elite spare on Wrath's seat",
        fn = function()
            local def = Character.defs["character_the_gorged"]
            assert(def.tier == 4 and def.race == "human" and def.class == "fighter", "tier 4, human, fighter")
            assert(Character.isVampire(def), "a vampire")
            assert(def.footprint.w == 2 and def.footprint.h == 2 and def.stats.movement == 2, "2x2 and slow")
            local organ = Item.defs["utility_full_to_bursting"]
            assert(organ and organ.class == "creature" and organ.bound and organ.noSteal, "its organ is its own")
            local e = Encounter.get("encounter_wrath_the_gorged")
            assert(e and e.kind == "elite" and e.rung == 2, "an elite on rung 2 (floor 8)")
            assert(e.condition({ biome = "volcanic" }) and not e.condition({ biome = "cave" }), "on the flows")
            local ids = Arena.resolveComposition(e.composition, { depth = 8 })
            assert(ids[1] == "character_the_gorged" and #ids <= Arena.ELITE_CAP, "it leads, inside the elite tier")
            local wrath
            for _, s in ipairs(Descent.SINS) do if s.id == "wrath" then wrath = s end end
            local spare = false
            for _, id in ipairs(wrath.elites.spares) do if id == "encounter_wrath_the_gorged" then spare = true end end
            assert(spare, "one of Wrath's spare elites")
            local heart = Item.defs["utility_surfeit_heart"]
            assert(heart.unstocked and heart.unlockLevel == 8 and heart.class ~= "creature",
                "the Surfeit Heart is an unstocked trophy on a real shelf")
            assert(def.drops[1] == "utility_surfeit_heart", "and it is what the Gorged drops")
            assert(not heart.description:find("spends"), "item text never says spends")
        end,
    },
    {
        name = "a blow that wounds it spills one blood pool beside it, and pools never stack on one tile",
        fn = function()
            local c, g = room()
            wound(c, g, 10)
            local p = pools(c)
            assert(#p == 1, "one blow, one pool")
            assert(Combat.cellGap(p[1].x, p[1].y, g) == 1, "on a tile beside its body")
            for _ = 1, 20 do wound(c, g, 2) end
            local seen, n = {}, 0
            for _, h in ipairs(pools(c)) do
                local k = h.x .. "," .. h.y
                assert(not seen[k], "two pools on " .. k)
                seen[k] = true
                n = n + 1
                assert(Combat.cellGap(h.x, h.y, g) == 1, "every pool is beside it")
            end
            assert(n == 8, "the eight tiles round a 2x2 each hold one, and no more, got " .. n)
        end,
    },
    {
        name = "a vampire that steps into a pool drinks it dry: Thirst reset, a heal, the pool gone",
        fn = function()
            local f = unit("character_fledgling", 1, 5, { stats = { health = 40 } })
            local c, g = room(nil, { f })
            local v = one(c, "character_fledgling")
            Status.apply(c, v, "status_thirst")
            v.char.stats.health.current = 20
            Gorged.pool(c, 2, 5, g)
            openTurn(c, v)
            assert(Combat.moveUnit(c, v, 2, 5), "it walks into the pool")
            assert(Thirst.level(v) == 0, "its Thirst resets")
            assert(hp(v) > 20, "and it heals")
            assert(#pools(c) == 0, "and the pool is drunk dry")
            assert(Hazard.defs[Gorged.POOL].welcomes(v), "a vampire's planner walks toward a pool")
        end,
    },
    {
        name = "a living body that steps into a pool bleeds, and the wound is the Gorged's, so it drinks the ticks",
        fn = function()
            local c, g = room(swordsman(1, 1))
            local s = c.units[1]
            Gorged.pool(c, 1, 2, g)
            openTurn(c, s)
            assert(Combat.moveUnit(c, s, 1, 2), "into the pool")
            local bleed = Status.get(s, "status_bleed")
            assert(bleed and bleed.opener == g, "it bleeds, and the Gorged opened the wound")
            assert(not Hazard.defs[Gorged.POOL].welcomes(s), "the living are warned off it")
            Status.apply(c, g, "status_thirst")
            local before = hp(s)
            openTurn(c, s)
            assert(Combat.moveUnit(c, s, 1, 3), "and walks on")
            assert(hp(s) < before, "the wound bites on the step")
            assert(Thirst.level(g) == 0, "and what it spills is the Gorged's drink (Running Feeds It)")
        end,
    },
    {
        name = "at half health it bursts: the tiles round it flood, it is one tile, faster, in Bloodlust that no drink lifts",
        fn = function()
            local c, g = room(swordsman(4, 5))
            local s = c.units[1]
            local move = Combat.flatStat(g, "movement")
            wound(c, g, 160)
            assert(g._burst, "it burst")
            assert(g.w == 1 and g.h == 1 and g.x == 5 and g.y == 5, "one tile, on its old anchor")
            assert(Combat.unitAt(c, 6, 6) == nil, "the rest of its old body is open ground")
            assert(Status.has(g, Thirst.BLOODLUST), "in Bloodlust")
            assert(Combat.flatStat(g, "movement") >= move + Gorged.BURST_MOVE + 1, "and faster")
            -- Every walkable tile within 1 of the 2x2 it was, less the one it stands on: 4x4 less corners, less 1.
            local floods = 0
            for _, h in ipairs(pools(c)) do
                assert(Combat.cellGap(h.x, h.y, { x = 5, y = 5, w = 2, h = 2 }) <= 1, "the flood is round its old body")
                floods = floods + 1
            end
            assert(floods == 11, "the room floods, got " .. floods)
            local bleed = Status.get(s, "status_bleed")
            assert(bleed and bleed.opener == g, "the body beside it is standing in it, and bleeds")
            Thirst.feed(c, g, 20)
            assert(Status.has(g, Thirst.BLOODLUST), "a drink does not lift this Bloodlust")
            Status.remove(c, g, Thirst.BLOODLUST)
            Gorged.holdBloodlust(c, g)
            assert(Status.has(g, Thirst.BLOODLUST), "and it comes back if something else took it")
            local n = #pools(c)
            wound(c, g, 60)
            assert(g.w == 1 and #pools(c) <= n + 1, "it bursts once; after, a wound only spills")
        end,
    },
    {
        name = "the Surfeit Heart banks overheal as a shield capped at 25% of max, and the next hit breaks it",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                unit("character_archer", 1, 1,
                    { isolate = "bare", items = { "utility_surfeit_heart" }, stats = { health = 100 } }),
                unit("character_bandit", 7, 7, { isolate = "bare" }))
            local u = c.units[1]
            u.char.stats.health.current = 95
            Combat.applyHeal(c, u, 20)
            assert(hp(u) == 100, "healed to full")
            local st = Status.get(u, "status_surfeit")
            assert(st and st.magnitude == 15, "the 15 past full is a shield")
            Combat.applyHeal(c, u, 30)
            assert(Status.get(u, "status_surfeit").magnitude == 25, "capped at 25% of max")
            Combat.dealFlatDamage(c, u, 10, { "physical" }, "test", nil, { raw = true })
            assert(hp(u) == 100, "the shield takes the blow")
            assert(not Status.has(u, "status_surfeit"), "and breaks on it, with 15 left unspent")
            Combat.dealFlatDamage(c, u, 10, { "physical" }, "test", nil, { raw = true })
            assert(hp(u) == 90, "the next blow lands")
            -- Without the Heart, overheal is simply lost.
            local c2 = Fixture.combat(Fixture.new(8, 8), swordsman(1, 1, 100), unit("character_bandit", 7, 7))
            Combat.applyHeal(c2, c2.units[1], 30)
            assert(not Status.has(c2.units[1], "status_surfeit"), "no Heart, no shield")
        end,
    },
}
