-- THE PAYMASTER (Greed's approach, reviewed over five rounds 2026-09-25/26): Vesh's hand, paying a dwarf crew
-- into the ground in a dead dwarf's shape, and the Lure under it once the last of the crew falls. Each case
-- pins a rule the review approved, on a bare board (models/paymaster.lua holds the rules).
--
--   Pay Out      a heap within 2 of a living dwarf at the start of his turn; he never pockets one
--   the shape    the plate and the race are a dwarf's, and none of a dwarf's organs come with them
--   the reveal   on the last OTHER dwarf's fall, not before -- a Gilt Wyrm counts, a skeleton does not;
--                killed first, he dies as the Paymaster and nothing rises
--   the raise    his crew's dead stand up on his side as Dwarf Skeletons (a Bone Wyrm where a wyrm fell),
--                up to the elite cap, and the dead pocket nothing
--   the Lure     Bone-Knit once, Grave-Chill, weak to light and fire
--   the book     one face until the reveal, both after
--   the trophy   Thrown Wages: the company's gold as a heap on open ground, or as a blow at a foe

local Character = require("models.character")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Transform = require("models.transform")
local Arena = require("models.arena")
local Bestiary = require("models.bestiary")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Paymaster = require("models.paymaster")
local Fixture = require("tests.support.fixture")

local unit, itemNamed, hp = Fixture.unit, Fixture.itemNamed, Fixture.hp

local HEAP = "hazard_coin_heap"
local PAY = "character_the_paymaster"

local function board() return Fixture.new(14, 14) end
local function fell(c, u) Combat.dealFlatDamage(c, u, 9999, {}, "test") end

local function heaps(c)
    local out = {}
    for _, h in ipairs(c.hazards or {}) do
        if h.alive and h.id == HEAP then out[#out + 1] = h end
    end
    return out
end

local function living(c, id, side)
    local out = {}
    for _, u in ipairs(c.units) do
        if u.alive and u.char and u.char.id == id and (not side or u.side == side) then out[#out + 1] = u end
    end
    return out
end

-- The Paymaster and a crew on the enemy side, with one company walker far off in the corner. `crew` is a list
-- of { id, x, y }. Returns the combat, the Paymaster, and the crew units in the order given.
local function payroll(crew, spawns)
    local enemies = { unit(PAY, 7, 7) }
    for _, s in ipairs(crew) do enemies[#enemies + 1] = unit(s[1], s[2], s[3]) end
    local c = Fixture.combat(board(), Fixture.walker(1, 1), enemies)
    local out = {}
    for i = 3, #c.units do out[#out + 1] = c.units[i] end
    if spawns then spawns.enemies = enemies end
    return c, c.units[2], out
end

-- Step `u` onto (x, y) the way a walk ends there: the tile's ground fires.
local function stepOnto(c, u, x, y)
    u.x, u.y = x, y
    Combat.enterTile(c, u, x, y)
end

-- Inject a purse over a local gold cell (tests/purse_spec.lua's shape). Returns a reader.
local function givePurse(c, gold)
    local g = gold
    c.purse = { get = function() return g end, spend = function(n) g = g - n end }
    return function() return g end
end

return {
    -- ------------------------------------------------------------------------------ the shape
    {
        name = "the Paymaster wears the dwarf and none of what a dwarf is inside",
        fn = function()
            local c, pay = payroll({ { "character_dwarf_delver", 10, 10 } })
            assert(pay.char.name == "The Paymaster", "the plate reads the Paymaster")
            assert(pay.char.race == "dwarf" and pay.char.kind == "humanoid", "the race reads dwarf")
            assert(not Character.isUndead(pay.char), "and nothing on him says he is dead")
            assert(not itemNamed(pay.char, "utility_stout"), "the race granted no Stout (raceGrants = false)")
            assert(not Trait.flag(pay, "seeksHeaps"), "so loose gold does not draw him")
            assert(not Trait.has(pay, "trait_inheritance"), "and he takes up no Share")
            assert(not Hazard.defs[HEAP].welcomes(pay), "a heap is not welcome ground to him")
            assert(itemNamed(pay.char, "weapon_paymasters_pick") and itemNamed(pay.char, "utility_pay_out")
                and itemNamed(pay.char, "utility_the_payroll"), "the pick, the purse and the payroll")
            assert(Status.has(pay, "status_pay_out"), "Pay Out is laid for the whole fight")
            local delver = living(c, "character_dwarf_delver")[1]
            assert(itemNamed(delver.char, "utility_stout"), "a real dwarf beside him still carries Stout")
        end,
    },
    -- ------------------------------------------------------------------------------ Pay Out
    {
        name = "Pay Out: at the start of his turn a heap lands on an open tile within 2 of a living dwarf",
        fn = function()
            for seed = 1, 6 do
                local c, pay, crew = payroll({ { "character_dwarf_delver", 11, 11 }, { "character_dwarf_skeleton", 3, 11 } })
                c.rng = function(n) return ((seed - 1) % n) + 1 end
                local delver = crew[1]
                Status.onTurnStart(c, pay)
                local hs = heaps(c)
                assert(#hs == 1, "one heap a turn, got " .. #hs)
                local gap = Combat.cellGap(hs[1].x, hs[1].y, delver)
                assert(gap >= 1 and gap <= Paymaster.PAY_REACH,
                    "it lands within 2 of the living dwarf, got " .. gap)
                assert(not Combat.unitAt(c, hs[1].x, hs[1].y), "on open ground")
            end
        end,
    },
    {
        name = "he never pockets a heap and never sickens; the crew does",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_delver", 11, 11 } })
            Hazard.place(c, 7, 8, HEAP, {})
            stepOnto(c, pay, 7, 8)
            assert(Hazard.at(c, 7, 8, HEAP), "the heap is still on the floor after he walks over it")
            assert(Status.stacksOf(pay, "status_dragon_sickness") == 0, "and he took no Dragon-Sickness")
            Hazard.place(c, 11, 12, HEAP, {})
            stepOnto(c, crew[1], 11, 12)
            assert(not Hazard.at(c, 11, 12, HEAP), "a Delver pockets the one he walks onto")
            assert(Status.stacksOf(crew[1], "status_dragon_sickness") == 1, "and sickens on it")
        end,
    },
    -- ------------------------------------------------------------------------------ the reveal
    {
        name = "the reveal fires on the last OTHER dwarf's fall and not before -- a skeleton is not crew",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_delver", 10, 10 }, { "character_dwarf_delver", 3, 3 },
                                           { "character_dwarf_skeleton", 12, 3 } })
            local health = hp(pay)
            fell(c, crew[1])
            assert(not Transform.isTransformed(pay) and pay.char.name == "The Paymaster",
                "one dwarf down and another standing: still the Paymaster")
            fell(c, crew[2])
            assert(pay.alive and Transform.isTransformed(pay), "the last living dwarf down, and he turns -- "
                .. "though a skeleton still stands beside him")
            assert(pay.char.id == "character_the_lure" and pay.char.name == "The Lure", "the plate names the Lure")
            assert(Character.isUndead(pay.char), "and it is dead")
            assert(hp(pay) == health and c.units[2] == pay and pay.x == 7 and pay.y == 7,
                "the same unit, on the same tile, on the same health bar")
            assert(not Status.has(pay, "status_pay_out"), "he stops paying out")
            Status.onTurnStart(c, pay)
            assert(#heaps(c) == 0, "no heap lands on the Lure's turn")
            assert(itemNamed(pay.char, "ability_grave_chill"), "he fights with Vesh's Grave-Chill")
            assert(pay.resist.holy < 0 and pay.resist.fire < 0, "weak to light and to fire")
            assert(Combat.flatStat(pay, "defense") >= 10, "and hard for a blade or a hammer to find")
        end,
    },
    {
        name = "killed while his crew stands, he dies as the Paymaster and nothing rises",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_delver", 10, 10 }, { "character_dwarf_delver", 3, 3 } })
            fell(c, pay)
            assert(not pay.alive and not Transform.isTransformed(pay), "he fell in the dwarf's shape")
            fell(c, crew[1])
            fell(c, crew[2])
            assert(#living(c, "character_dwarf_skeleton") == 0, "no crewman got back up")
            assert(#living(c, "character_the_lure") == 0, "and no shade ever stood there")
        end,
    },
    -- ------------------------------------------------------------------------------ the raise
    {
        name = "the raise: the crew's dead stand up where they fell, on his side, as Dwarf Skeletons",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_hornblower", 10, 10 },
                                           { "character_dwarf_delver", 3, 3 }, { "character_dwarf_delver", 12, 4 } })
            for _, u in ipairs(crew) do fell(c, u) end
            local dead = living(c, "character_dwarf_skeleton", pay.side)
            assert(#dead == 3, "three fell and three rose, got " .. #dead)
            local tiles = {}
            for _, u in ipairs(dead) do tiles[u.x .. "," .. u.y] = true end
            for _, u in ipairs(crew) do
                assert(tiles[u.x .. "," .. u.y], "a skeleton stands where each one fell")
                assert(not u.incapacitated and not u.corpse, "and the body under it is spent")
            end
        end,
    },
    {
        name = "the raise stops at the elite cap, and the rest stay in the ground",
        fn = function()
            local spec = {}
            for i = 1, 7 do spec[#spec + 1] = { "character_dwarf_delver", 1 + i, 12 } end
            local c, pay, crew = payroll(spec)
            for _, u in ipairs(crew) do fell(c, u) end
            local standing = 0
            for _, u in ipairs(c.units) do if u.alive and u.side == pay.side then standing = standing + 1 end end
            assert(standing == Arena.ELITE_CAP, "his side stands at the elite cap, got " .. standing)
            assert(#living(c, "character_dwarf_skeleton") == Arena.ELITE_CAP - 1, "the Lure and five of his dead")
        end,
    },
    {
        name = "a Gilt Wyrm is still crew, and one that fell as a wyrm rises as a Bone Wyrm",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_delver", 10, 10 }, { "character_dwarf_delver", 3, 3 } })
            local wyrm, other = crew[1], crew[2]
            Status.apply(c, wyrm, "status_dragon_sickness", { magnitude = 3 })
            assert(Transform.isTransformed(wyrm) and wyrm.char.id == "character_gilt_wyrm", "the gold made a wyrm")
            fell(c, other)
            assert(not Transform.isTransformed(pay), "the wyrm is still a dwarf under the scales: no reveal yet")
            fell(c, wyrm)
            assert(Transform.isTransformed(pay), "the wyrm was the last of the crew")
            local bone = living(c, "character_bone_wyrm", pay.side)[1]
            assert(bone and bone.x == 10 and bone.y == 10, "a Bone Wyrm stands where the wyrm fell")
            assert(#living(c, "character_dwarf_skeleton", pay.side) == 1, "and the Delver rose as a skeleton")
            assert(Character.isUndead(bone.char) and bone.char.race == "dragon", "a wyrm still, and dead")
            assert(itemNamed(bone.char, "weapon_gilt_maw") and itemNamed(bone.char, "ability_venom_breath"),
                "it keeps the Gilt Maw and the Venom Breath")
            assert(not itemNamed(bone.char, "utility_wyrm_dread") and not itemNamed(bone.char, "utility_stout"),
                "and loses Dread and Stout")
            local want = Character.defs["character_gilt_wyrm"].drops
            local got = Character.defs["character_bone_wyrm"].drops
            assert(#got == #want, "its drops are the Gilt Wyrm's list")
            for i, id in ipairs(want) do assert(got[i] == id, "drop " .. i .. " is " .. id) end
        end,
    },
    {
        name = "the raised dead pocket nothing: the heaps are the company's now",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_delver", 10, 10 }, { "character_dwarf_delver", 3, 3 } })
            Status.apply(c, crew[1], "status_dragon_sickness", { magnitude = 3 })
            fell(c, crew[2])
            fell(c, crew[1])
            local skel = living(c, "character_dwarf_skeleton", pay.side)[1]
            local bone = living(c, "character_bone_wyrm", pay.side)[1]
            assert(skel and bone, "both rose")
            assert(not Trait.flag(skel, "seeksHeaps") and not Trait.flag(bone, "seeksHeaps"),
                "neither is drawn to loose gold")
            Hazard.place(c, 3, 5, HEAP, {})
            stepOnto(c, skel, 3, 5)
            Hazard.place(c, 10, 12, HEAP, {})
            stepOnto(c, bone, 10, 12)
            assert(Hazard.at(c, 3, 5, HEAP) and Hazard.at(c, 10, 12, HEAP), "both heaps lie where they were")
            assert(Status.stacksOf(skel, "status_dragon_sickness") == 0
                and Status.stacksOf(bone, "status_dragon_sickness") == 0, "and neither took a stack")
        end,
    },
    -- ------------------------------------------------------------------------------ the Lure
    {
        name = "the Lure Bone-Knits once: it stands up whole from the first lethal blow and not the second",
        fn = function()
            local c, pay, crew = payroll({ { "character_dwarf_delver", 10, 10 } })
            fell(c, crew[1])
            assert(Transform.isTransformed(pay), "turned")
            assert(itemNamed(pay.char, "utility_held_in_trust"), "carrying Vesh's Bone-Knit, held in trust")
            local mana = pay.char.stats.mana.current
            fell(c, pay)
            assert(pay.alive and hp(pay) == pay.char.stats.health.max, "the first death is refused, and it is whole")
            assert(pay.char.stats.mana.current == mana, "and the trust costs no mana")
            fell(c, pay)
            assert(not pay.alive, "the second is not")
        end,
    },
    -- ------------------------------------------------------------------------------ the book
    {
        name = "the bestiary shows the dwarf until the reveal, and names both faces after it",
        fn = function()
            local spawns = {}
            local c, pay, crew = payroll({ { "character_dwarf_delver", 10, 10 } }, spawns)
            local player = { met = {} }
            Bestiary.recordMet(player, spawns.enemies)
            local function entry()
                for _, e in ipairs(Bestiary.entries(player)) do
                    if e.id == PAY or e.id == "character_the_lure" then return e end
                end
            end
            assert(entry().name == "The Paymaster", "before the reveal the book knows only the dwarf")
            assert(not Bestiary.hasMet(player, "character_the_lure"), "and has not met what is under it")
            fell(c, crew[1])
            Bestiary.recordMet(player, spawns.enemies)
            assert(Bestiary.hasMet(player, "character_the_lure"), "the reveal is a meeting")
            local shown = 0
            for _, e in ipairs(Bestiary.entries(player)) do
                if e.id == PAY or e.id == "character_the_lure" then shown = shown + 1 end
            end
            assert(shown == 1, "one body, one entry")
            assert(entry().id == PAY and entry().name == "The Paymaster / The Lure", "naming both faces")
        end,
    },
    -- ------------------------------------------------------------------------------ the trophy
    {
        name = "Thrown Wages on open ground: the company's gold lands as a coin heap",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                unit("character_saber", 2, 2, { isolate = "bare", items = { "ability_thrown_wages" }, stats = { stamina = 99 } }),
                unit("character_bandit", 7, 7, { isolate = "bare" }))
            local hero = c.units[1]
            local purse = givePurse(c, 100)
            Fixture.openTurn(c, hero)
            assert(Combat.useItem(c, hero, itemNamed(hero.char, "ability_thrown_wages"), 4, 2), "the throw lands")
            local heap = Hazard.at(c, 4, 2, HEAP)
            assert(heap and heap.amount == 20, "a heap worth the 20 gold thrown")
            assert(purse() == 80, "and the 20 is gone from the bank")
        end,
    },
    {
        name = "Thrown Wages at a foe: the gold is the blow, a point past the floor for every 5 thrown",
        fn = function()
            local function throw(gold)
                local c = Fixture.combat(Fixture.new(8, 8),
                    unit("character_saber", 2, 2, { isolate = "bare", items = { "ability_thrown_wages" }, stats = { stamina = 99 } }),
                    unit("character_bandit", 4, 2, { isolate = "bare", stats = { defense = 0, health = 900 } }))
                local hero, foe = c.units[1], c.units[2]
                local purse = givePurse(c, gold)
                local before = hp(foe)
                assert(Fixture.strike(c, hero, foe, "ability_thrown_wages"), "the throw lands")
                assert(not Hazard.at(c, 4, 2, HEAP), "no heap where a foe stood")
                return before - hp(foe), purse()
            end
            local floor, broke = throw(0)
            local rich, left = throw(100)
            assert(floor > 0 and broke == 0, "an empty purse still throws the floor")
            assert(rich - floor == 4 and left == 80, "20 gold at 5 a point is +4, and the 20 is spent")
            assert(Item.defs["ability_thrown_wages"].unstocked, "a trophy, sold nowhere")
            assert(Character.defs[PAY].drops[1] == "ability_thrown_wages", "and it is the Paymaster's")
        end,
    },
    -- ------------------------------------------------------------------------------ the stop
    {
        name = "the Paymaster is an elite on Greed's approach, billed as a spare, his crew under the cap",
        fn = function()
            local def = Encounter.get("encounter_greed_the_paymaster")
            assert(def.kind == "elite" and def.rung == 1, "an elite on the approach")
            assert(def.condition({ biome = "cave" }) and not def.condition({ biome = "forest" }), "in the cave only")
            local shallow = Arena.resolveComposition(def.composition, { depth = 5 })
            local deep = Arena.resolveComposition(def.composition, { depth = 6 })
            local function count(list, id)
                local n = 0
                for _, x in ipairs(list) do if x == id then n = n + 1 end end
                return n
            end
            assert(count(shallow, PAY) == 1 and count(shallow, "character_dwarf_hornblower") == 1
                and count(shallow, "character_dwarf_delver") == 2 and #shallow == 4,
                "the Paymaster, a Hornblower and two Delvers")
            assert(count(deep, "character_dwarf_hearthguard") == 1 and #deep == 5, "and a Hearthguard at depth")
            assert(#deep < Arena.ELITE_CAP, "under the cap, so the raise always has room")
            local billed = false
            for _, s in ipairs(Descent.SINS) do
                if s.id == "greed" then
                    for _, id in ipairs(s.elites.spares) do
                        if id == "encounter_greed_the_paymaster" then billed = true end
                    end
                end
            end
            assert(billed, "Greed bills him as a spare")
        end,
    },
}
