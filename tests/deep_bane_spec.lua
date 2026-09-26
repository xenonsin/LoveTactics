-- THE THING UNDER THE SEAM (Greed's seat, approved on review 2026-09-26: "They dug too greedily and too
-- deep"). Each rule the review settled, held by the behaviour it promises on a bare board, against the real
-- blueprints:
--   * the body: a 2x2 demon alone, fire on every blow, resisting fire and weak to ice, creature kit only
--   * Lash of Flame: reach 3, the whole haul to its side, Burning -- and over a gap nobody can walk
--   * the trail: every tile it vacates -- both of them, for a 2x2 -- burns for three turns, and not it
--   * Shadow and Flame: a cone wound up a turn ahead, marked, and landing hard enough to put a body down
--   * the break: at half health the ring two out falls to lava once, the ring's bodies drop inside, and
--     nobody walks across it
--   * the Whip of Flame (a mace that pulls a tile and Burns) and the Shadow Mantle (nothing past 3 aims at
--     its bearer, the planner included), both unstocked trophies
--   * Too Deep is a rung-2 cave elite, billed as one of Greed's spares, and a floor six can deal it
-- Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BANE = "character_deep_bane"
local KIT = { "weapon_lash_of_flame", "ability_shadow_and_flame", "utility_what_was_sleeping" }
local DROPS = { "weapon_whip_of_flame", "utility_shadow_mantle" }

-- A sturdy company body with nothing in its grid but what a case hands it.
local function body(x, y, items, health)
    return unit("character_knight", x, y, { isolate = "bare", items = items or {},
        stats = { health = health or 300, mana = 60, stamina = 60, movement = 6 } })
end

-- The thing anchored at (6,6) -- it stands on (6..7, 6..7) -- on a 14x14 floor, the company as given.
local function lair(company)
    local c = Combat.new(Fixture.new(14, 14), company or {}, { unit(BANE, 6, 6) })
    local bane
    for _, u in ipairs(c.units) do if u.char.id == BANE then bane = u end end
    local party = {}
    for _, u in ipairs(c.units) do if u ~= bane then party[#party + 1] = u end end
    return c, bane, party
end

-- Put it just past half with a blow it survives.
local function breakFloor(c, bane)
    local hpt = bane.char.stats.health
    hpt.current = math.floor(hpt.max * 0.5) + 1
    Combat.dealFlatDamage(c, bane, 2, {}, "test")
    assert(hpt.current <= hpt.max * 0.5 and bane.alive, "it is past half and still standing")
end

local function tileAt(c, x, y) return c.arena.tiles[y] and c.arena.tiles[y][x] end

local function lavaCount(c)
    local n = 0
    for y = 1, c.arena.rows do
        for x = 1, c.arena.cols do
            if tileAt(c, x, y).type == "lava" then n = n + 1 end
        end
    end
    return n
end

return {
    -- ------------------------------------------------------------------------------ the body
    {
        name = "it is a lone 2x2 demon elite: fire on its blows, fire resisted, ice feared, creature kit",
        fn = function()
            local def = Character.defs[BANE]
            assert(def.name == "The Thing Under the Seam", "named: " .. tostring(def.name))
            assert(def.race == "demon" and def.tier == 3 and def.boss, "a tier-3 demon, off the execute table")
            assert(def.footprint.w == 2 and def.footprint.h == 2, "two by two")
            assert(def.resist.fire > 0 and def.resist.ice < 0, "it resists fire and fears ice")
            for _, id in ipairs(KIT) do
                local item = Item.defs[id]
                assert(item and item.class == "creature" and item.noSteal and item.price == nil,
                    id .. " is unpriced, unstealable creature kit")
            end
            -- A demon's blows burn, and the channel is never moved (docs/bestiary.md).
            for _, id in ipairs({ "weapon_lash_of_flame", "ability_shadow_and_flame" }) do
                local tags = {}
                for _, t in ipairs(Item.defs[id].tags) do tags[t] = true end
                assert(tags.fire and tags.physical and not tags.magical, id .. " is a physical blow with fire on it")
            end
            local c, bane = lair({ body(1, 1) })
            assert(bane.w == 2 and bane.h == 2, "it stands on four tiles")
            assert(Trait.flag(bane, "emberwalk"), "its own fire does not touch it")
            assert(Trait.has(bane, "trait_boss_phases"), "its break rides the phase script")
            assert((bane.resist.holy or 0) < 0, "a demon takes holy the harder")
        end,
    },

    -- ------------------------------------------------------------------------------ the lash
    {
        name = "Lash of Flame: from three tiles out it hauls a body the whole way to its side, Burning",
        fn = function()
            local c, bane, party = lair({ body(6, 11) })
            local k = party[1]
            assert(Combat.unitGap(bane, k) == 4, "four out: past the lash")
            k.y = 10
            assert(Combat.unitGap(bane, k) == 3, "three out: at the edge of its reach")
            openTurn(c, bane)
            local ok, why = Combat.useItem(c, bane, itemNamed(bane.char, "weapon_lash_of_flame"), k.x, k.y)
            assert(ok, "the lash lands: " .. tostring(why))
            assert(Combat.unitGap(bane, k) == 1, "and the body is beside it: gap " .. Combat.unitGap(bane, k))
            assert(Status.has(k, "status_burn"), "Burning")
        end,
    },

    -- ------------------------------------------------------------------------------ the trail
    {
        name = "where it walks the floor burns: both tiles a 2x2 vacates hold fire for three turns, and not it",
        fn = function()
            local c, bane = lair({ body(1, 13) })
            openTurn(c, bane)
            assert(Combat.moveUnit(c, bane, 7, 6), "it steps one tile east")
            for _, cell in ipairs({ { 6, 6 }, { 6, 7 } }) do
                local fire = Hazard.at(c, cell[1], cell[2], "hazard_fire")
                assert(fire, string.format("(%d,%d), which it left, is burning", cell[1], cell[2]))
                assert(fire.remaining == 3 * Status.TICKS_PER_TURN,
                    "for three turns: " .. tostring(fire.remaining) .. " ticks")
            end
            for _, cell in ipairs({ { 7, 6 }, { 8, 6 }, { 7, 7 }, { 8, 7 } }) do
                assert(not Hazard.at(c, cell[1], cell[2], "hazard_fire"), "nothing is laid under its feet")
            end
            -- Walking back through its own trail does not Burn it.
            openTurn(c, bane)
            assert(Combat.moveUnit(c, bane, 6, 6), "it walks back into its trail")
            assert(not Status.has(bane, "status_burn"), "and its own fire does not touch it")
            -- ...while a 1x1 trail still lays exactly the one tile it came from (the vacated set of a 1x1).
            local left = Combat.vacatedCells({ x = 3, y = 3 }, 2, 3)
            assert(#left == 1 and left[1].x == 2 and left[1].y == 3, "a 1x1 vacates the one tile it left")
        end,
    },

    -- ------------------------------------------------------------------------------ the cone
    {
        name = "Shadow and Flame: the cone is wound up a turn ahead and marked, then lands and puts a body down",
        fn = function()
            -- 50 health on a knight's 11 defense: its level-1 blueprint lands 18 + 52 = 70 before armour.
            local c, bane, party = lair({ body(6, 9, nil, 50), body(1, 1, nil, 50) })
            local caught, clear = party[1], party[2]
            local sf = itemNamed(bane.char, "ability_shadow_and_flame")
            openTurn(c, bane)
            local ok, why = Combat.useItem(c, bane, sf, 6, 9)
            assert(ok, "the swing begins: " .. tostring(why))
            assert(bane.channel, "it is WOUND UP, not landed")
            assert(hp(caught) == 50, "nothing has landed yet")
            -- The telegraph is the cone off its face, committed where it was aimed.
            local cells = Combat.aoeCells(c, sf.activeAbility, bane.channel.tx, bane.channel.ty, bane)
            local marked = {}
            for _, cell in ipairs(cells) do marked[cell.x .. "," .. cell.y] = true end
            assert(marked["6,9"] and marked["5,9"] and marked["8,9"] and marked["6,10"],
                "the marked cone covers the rows south of its face")
            assert(not marked["1,1"], "and not the far corner")
            -- Its next turn comes round and the cone lands.
            assert(Combat.resolveChannel(c, bane), "the swing lands")
            assert(not caught.alive or hp(caught) <= 0, "the body left in the cone goes down: " .. hp(caught))
            assert(clear.alive and hp(clear) == 50, "the body out of it is untouched")
        end,
    },
    {
        name = "a body that steps out of the marked cone before it lands takes nothing",
        fn = function()
            local c, bane, party = lair({ body(6, 9, nil, 60) })
            local k = party[1]
            openTurn(c, bane)
            assert(Combat.useItem(c, bane, itemNamed(bane.char, "ability_shadow_and_flame"), 6, 9))
            k.x, k.y = 12, 12
            Combat.resolveChannel(c, bane)
            assert(hp(k) == 60, "the telegraph was the counterplay")
        end,
    },

    -- ------------------------------------------------------------------------------ the break
    {
        name = "at half health the floor two out falls to lava, once, and the ring's bodies drop inside",
        fn = function()
            -- (6,9) is two below its footprint: ON the ring. (6,11) is four out and stays put.
            local c, bane, party = lair({ body(6, 9), body(6, 11) })
            local onRing, outside = party[1], party[2]
            assert(Combat.cellGap(6, 9, bane) == 2, "the first body stands exactly two out")
            assert(lavaCount(c) == 0, "no lava before the break")
            breakFloor(c, bane)

            -- Every walkable tile exactly two out is lava; nothing nearer or farther is.
            local ring = 0
            for y = 1, 14 do
                for x = 1, 14 do
                    local gap = Combat.cellGap(x, y, bane)
                    local lava = tileAt(c, x, y).type == "lava"
                    if gap == 2 then
                        assert(lava, string.format("(%d,%d) on the ring fell", x, y))
                        ring = ring + 1
                    else
                        assert(not lava, string.format("(%d,%d) at gap %d did not", x, y, gap))
                    end
                end
            end
            assert(ring == lavaCount(c) and ring > 0, "the ring is the whole of the lava: " .. ring)

            assert(onRing.alive, "the body on the ring did not die of it")
            assert(Combat.cellGap(onRing.x, onRing.y, bane) == 1,
                "it dropped one tile to the inside edge: gap " .. Combat.cellGap(onRing.x, onRing.y, bane))
            assert(onRing.x == 6 and onRing.y == 8, "straight in, to (6,8): got " .. onRing.x .. "," .. onRing.y)
            assert(outside.x == 6 and outside.y == 11, "a body off the ring stays where it was")

            -- ONCE: more blows below half open nothing further.
            local fell = lavaCount(c)
            Combat.dealFlatDamage(c, bane, 5, {}, "test")
            Combat.dealFlatDamage(c, bane, 5, {}, "test")
            assert(lavaCount(c) == fell, "the floor falls away once")
        end,
    },
    {
        name = "nobody walks across the ring: inside stays inside, outside stays outside",
        fn = function()
            local c, bane, party = lair({ body(6, 9), body(6, 12) })
            local inner, outer = party[1], party[2]
            breakFloor(c, bane)
            for key in pairs(Combat.reachable(c, inner)) do
                local x, y = key:match("(%-?%d+),(%-?%d+)")
                assert(Combat.cellGap(tonumber(x), tonumber(y), bane) <= 1,
                    "a body inside cannot reach " .. key)
            end
            for key in pairs(Combat.reachable(c, outer)) do
                local x, y = key:match("(%-?%d+),(%-?%d+)")
                assert(Combat.cellGap(tonumber(x), tonumber(y), bane) >= 3,
                    "a body outside cannot reach " .. key)
            end
            openTurn(c, outer)
            assert(not Combat.moveUnit(c, outer, 6, 8), "and a walk onto the island is refused")
            -- Its own trail cannot bridge it: fire refuses lava as ground (Hazard.place).
            assert(not Hazard.place(c, 6, 9, "hazard_fire", {}), "no zone stands on the pit")
        end,
    },
    {
        name = "after the break the lash carries a body over the gap to its side",
        fn = function()
            local c, bane, party = lair({ body(6, 10) })
            local k = party[1]
            breakFloor(c, bane)
            assert(tileAt(c, 6, 9).type == "lava", "the pit lies between them")
            openTurn(c, bane)
            local ok, why = Combat.useItem(c, bane, itemNamed(bane.char, "weapon_lash_of_flame"), k.x, k.y)
            assert(ok, "the lash reaches across the pit: " .. tostring(why))
            assert(k.alive and Combat.unitGap(bane, k) == 1, "the body is carried over to its side")
            assert(tileAt(c, k.x, k.y).walkable, "and lands on floor")
        end,
    },

    -- ------------------------------------------------------------------------------ the drops
    {
        name = "it drops the Whip of Flame and the Shadow Mantle, both unstocked trophies",
        fn = function()
            local def = Character.defs[BANE]
            assert(#def.drops == 2 and def.drops[1] == DROPS[1] and def.drops[2] == DROPS[2], "its two pieces")
            for _, id in ipairs(DROPS) do
                local item = Item.defs[id]
                assert(item.unstocked and item.price == nil, id .. " is on a rack and never sold")
            end
            local whip = Item.defs.weapon_whip_of_flame
            assert(Item.archetype(whip) == "mace", "a mace: it displaces")
            assert(whip.activeAbility.range == 2, "reach 2")
            assert(Item.defs.utility_shadow_mantle.type == "utility", "the mantle is worn over armour")
        end,
    },
    {
        name = "the Whip of Flame pulls what it hits one tile toward you, and Burns it",
        fn = function()
            local c = Combat.new(Fixture.new(8, 8), { body(2, 2, { "weapon_whip_of_flame" }) },
                { unit("character_bandit", 2, 4, { isolate = "bare", stats = { health = 200, defense = 0 } }) })
            local k, foe = c.units[1], c.units[2]
            openTurn(c, k)
            local ok, why = Combat.useItem(c, k, itemNamed(k.char, "weapon_whip_of_flame"), 2, 4)
            assert(ok, "the whip lands: " .. tostring(why))
            assert(foe.x == 2 and foe.y == 3, "one tile toward the bearer: " .. foe.x .. "," .. foe.y)
            assert(Status.has(foe, "status_burn"), "and Burning")
        end,
    },
    {
        name = "the Shadow Mantle: nothing four tiles off can aim at its bearer, and at three it can",
        fn = function()
            local c = Combat.new(Fixture.new(10, 10), { body(2, 2, { "utility_shadow_mantle" }) },
                { unit("character_bandit", 2, 6, { isolate = "bare", items = { "ability_mark_of_heresy" },
                    stats = { mana = 60 } }) })
            local bearer, foe = c.units[1], c.units[2]
            assert(Trait.flag(bearer, "concealedBeyond"), "the mantle's shadow is on its bearer")
            local mark = itemNamed(foe.char, "ability_mark_of_heresy")
            assert(Combat.unitGap(foe, bearer) == 4, "four tiles off")

            -- The model's gates: off the list, and refused outright.
            local listed = false
            for _, t in ipairs(Combat.abilityTargets(c, foe, mark)) do if t == bearer then listed = true end end
            assert(not listed, "at four the bearer is on nobody's list")
            openTurn(c, foe)
            local ok, why = Combat.useItem(c, foe, mark, bearer.x, bearer.y)
            assert(not ok, "and a cast aimed at it from four is refused (" .. tostring(why) .. ")")

            -- The planner's: from four there is no plan on the bearer; from three there is.
            local function planned(x, y)
                for _, cand in ipairs(AI.candidates(c, foe, { mark }, { { x = x, y = y, steps = 0 } }, false)) do
                    if cand.target == bearer then return true end
                end
                return false
            end
            assert(not planned(2, 6), "the planner will not aim at it from four")
            assert(planned(2, 5), "it walks in to three to do it")

            foe.y = 5
            assert(Combat.unitGap(foe, bearer) == 3, "three tiles off")
            listed = false
            for _, t in ipairs(Combat.abilityTargets(c, foe, mark)) do if t == bearer then listed = true end end
            assert(listed, "at three the bearer can be picked")
            openTurn(c, foe)
            assert(Combat.useItem(c, foe, mark, bearer.x, bearer.y), "and the cast lands")
            assert(Status.has(bearer, "status_mark"), "Marked")
        end,
    },

    -- ------------------------------------------------------------------------------ the floor
    {
        name = "Too Deep is a lone rung-2 cave elite, one of Greed's spares, and floor six deals it",
        fn = function()
            local enc = Encounter.get("encounter_greed_the_deep_bane")
            assert(enc.kind == "elite" and enc.rung == 2 and enc.alone, "a rung-2 elite that stands alone")
            assert(enc.condition({ biome = "cave" }) and not enc.condition({ biome = "forest" }), "cave-locked")
            local comp = enc.composition({ depth = 6, rung = 2, seed = 3 })
            assert(#comp == 1 and comp[1] == BANE, "no escort")
            assert(enc.objective, "played out, never auto-resolved")
            local greed
            for _, s in ipairs(Descent.SINS) do if s.id == "greed" then greed = s end end
            local billed = false
            for _, id in ipairs(greed.elites.spares) do if id == "encounter_greed_the_deep_bane" then billed = true end end
            assert(billed, "billed as one of Greed's spares")
            -- Dealt by the floor, lone body and all, at a floor six's own levels.
            local danger = Descent.dangerLevel({ floor = 6 })
            local pool = Descent.floorPool({ depth = 6, rung = 2, biome = "cave",
                quest = { sin = "greed", floorLevel = danger, dangerLevel = danger } })
            local dealt = false
            for _, e in ipairs(pool) do if e.id == "encounter_greed_the_deep_bane" then dealt = true end end
            assert(dealt, "a floor six seats it despite MIN_BODIES and the share")
            -- ...and `alone` is an elite's word only: an ordinary lone body is still dropped.
            assert(Descent.MIN_BODIES >= 2, "the body floor still stands for everything else")
        end,
    },
}
