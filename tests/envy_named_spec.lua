-- Tests for ENVY'S NAMED BODIES ("Envy's Bestiary", reviewed 2026-10-01..03, slice E): the circle's mini boss and
-- its two named elites.
--
--   Leviathan      floor 11's stair: Underground between surfacings; marks the 3x3 under the Fairest at the end of
--                  its turn and rises there at the start of the next (a heavy blow, everyone shoved out, the 3x3
--                  quicksand for the rest of the fight), up for a round; below half its tail marks the next-Fairest
--   Medusa         the approach's elite: Stone Gaze (3 Stone petrify for 2 turns), adders from a slashing blow,
--                  three statues that crack open at her half health, and Perseus -- a mirror turns the gaze back
--   The Kinslayer  the seat's elite: hunts the body healed or blessed most this fight, shown by a counter, and
--                  whoever lands his killing blow takes 7 times his last hit
--
-- Each case pins a rule the review approved, on a bare board, plus the drops and the fights' rungs. Leviathan's
-- telegraph is pinned by firing its turn hooks directly, since a headless autobattle never shows a mark.

local AI = require("models.ai")
local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Hazard = require("models.hazard")
local Item = require("models.item")
local Spoils = require("models.spoils")
local Status = require("models.status")
local Trait = require("models.trait")
local Gorgon = require("models.gorgon")
local Kinslayer = require("models.kinslayer")
local Leviathan = require("models.leviathan")
local Fixture = require("tests.support.fixture")

local unit, openTurn, hp = Fixture.unit, Fixture.openTurn, Fixture.hp

local BODIES = {
    character_leviathan = { race = "demon", drops = { "ability_undertow", "armor_leviathans_wake" } },
    character_medusa = { race = "naga",
        drops = { "ability_gorgons_gaze", "armor_serpent_locks", "utility_hand_mirror" } },
    character_the_kinslayer = { race = "human", drops = { "utility_the_mark" } },
}
local DROPS = {
    ability_undertow = { class = "elementalist", rung = 11 },
    armor_leviathans_wake = { class = "vanguard", rung = 11 },
    ability_gorgons_gaze = { class = "shaman", rung = 11 },
    armor_serpent_locks = { class = "poisoner", rung = 11 },
    utility_hand_mirror = { class = "artificer", rung = 11 },
    utility_the_mark = { class = "duelist", rung = 12 },
}
local ORGANS = {
    "weapon_leviathan_jaws", "utility_under_the_sand", "weapon_serpent_hair", "utility_stone_gaze",
    "weapon_adder_fang", "utility_turned_to_stone", "utility_kinslayers_grudge",
}
local FIGHTS = {
    encounter_envy_medusa = { rung = 1 },
    encounter_envy_the_kinslayer = { rung = 2 },
}

-- A company body that takes a blow and lands one: a walker on a deep pool.
local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id and u.alive then return u end end
end

local function bless(c, u) return Status.apply(c, u, "status_blessing", { duration = 40 }) end

local function inMark(u, cx, cy) return math.abs(u.x - cx) <= 1 and math.abs(u.y - cy) <= 1 end

local function setHp(u, n) u.char.stats.health.current = n end

local WALL = { type = "mountain", moveCost = math.huge, walkable = false, sightCost = math.huge }
local function wall(x, y)
    local t = { x = x, y = y }
    for k, v in pairs(WALL) do t[k] = v end
    return t
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "three named bodies, each a tier-4 boss with its own organ, dropping real classes' trophies",
        fn = function()
            for id, want in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.tier == 4 and def.boss, id .. " is a tier-4 boss: the fight is about it")
                assert(def.race == want.race, id .. " is " .. want.race)
                assert(#def.drops == #want.drops, id .. " drops " .. #want.drops)
                for i, d in ipairs(want.drops) do assert(def.drops[i] == d, id .. " drops " .. d) end
            end
            local lev = Character.defs.character_leviathan
            assert(lev.footprint.w == 2 and lev.footprint.h == 2, "Leviathan's head is two by two")
            assert(lev.stats.health == 220 and lev.referenceLevel == 13, "about 220 health, a stair centrepiece")
            for id, want in pairs(DROPS) do
                local def = Item.defs[id]
                assert(def and def.unstocked and not def.price, id .. " is an unstocked trophy")
                assert(def.class == want.class, id .. " sits on the " .. want.class .. " shelf")
                assert(def.unlockLevel == want.rung and Spoils.depthOf(def) >= want.rung,
                    id .. " falls on floor " .. want.rung)
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
            assert(Item.defs.utility_hand_mirror.perseus, "the Hand-Mirror is Perseus's")
            assert(Gorgon.PERSEUS_IDS.armor_polished_shield, "and so is the Polished Shield, by id")
            -- No biblical name anywhere in the Kinslayer's kit.
            for _, text in ipairs({ Character.defs.character_the_kinslayer.name, Item.defs.utility_the_mark.name,
                Item.defs.utility_kinslayers_grudge.name, Item.defs.utility_the_mark.flavor,
                Item.defs.utility_kinslayers_grudge.flavor, Status.defs.status_favoured.description }) do
                assert(not text:find("Cain") and not text:find("Abel"), "no biblical name: " .. text)
            end
        end,
    },
    {
        name = "two elites on the waste: Medusa's garden on the approach, the Kinslayer on the seat",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == "elite", id .. " is an elite")
                assert(e.rung == want.rung, id .. " stands on rung " .. want.rung)
                assert(e.condition({ biome = "desert" }) and not e.condition({ biome = "spire" }), id .. " is the waste's")
                assert(e.objective and e.objective.type == "killAll", id .. " is played out, never walked off")
            end
            local garden = Encounter.get("encounter_envy_medusa").composition({ depth = 11, seed = 1 })
            local statues = 0
            for _, id in ipairs(garden) do if id == "character_stone_challenger" then statues = statues + 1 end end
            assert(garden[1] == "character_medusa" and statues == 3, "Medusa and three statues of past challengers")
            local seat = Encounter.get("encounter_envy_the_kinslayer").composition({ depth = 12, seed = 2 })
            assert(seat[1] == "character_the_kinslayer", "the Kinslayer leads his fight")
        end,
    },

    -- ------------------------------------------------------------------------------ Leviathan
    {
        name = "Leviathan opens under the sand: untargetable, unharmed, and it takes no action",
        fn = function()
            local c = Fixture.combat(Fixture.new(14, 14), walker(9, 9), { unit("character_leviathan", 2, 2) })
            local lev = one(c, "character_leviathan")
            assert(Status.has(lev, "status_underground"), "Underground at the bell")
            assert(Status.untargetable(lev, c), "it cannot be targeted")
            local before = hp(lev)
            Combat.dealFlatDamage(c, lev, 30, { "physical", "slash" }, "test", c.units[1])
            assert(hp(lev) == before, "nor harmed")
            local plan = AI.plan(c, lev)
            assert(plan and plan.wait, "under the sand it holds its turn")
        end,
    },
    {
        name = "it marks the 3x3 under the Fairest, rises there: a heavy blow, everyone shoved out, quicksand for good",
        fn = function()
            local c = Fixture.combat(Fixture.new(16, 16),
                { walker(9, 9), walker(9, 10), walker(13, 3) }, { unit("character_leviathan", 2, 2) })
            local fair, beside, far = c.units[1], c.units[2], c.units[3]
            local lev = one(c, "character_leviathan")
            bless(c, fair)
            -- The end of its turn: the mark goes down under the Fairest, as a Ripple on all nine tiles.
            Trait.onAnyTurnEnd(c, lev)
            local m = lev.leviathan.head
            assert(m and m.x == 9 and m.y == 9, "the mark is under the Fairest")
            for dy = -1, 1 do
                for dx = -1, 1 do
                    assert(Hazard.at(c, 9 + dx, 9 + dy, "hazard_ripple"), "a ripple shows where it will rise")
                end
            end
            assert(not lev.leviathan.tails[1], "no tail above half")
            -- The start of its next turn: it rises.
            local h1, h2, h3 = hp(fair), hp(beside), hp(far)
            Trait.onAnyTurnStart(c, lev)
            assert(not Status.has(lev, "status_underground"), "it is up")
            assert(hp(fair) < h1 and hp(beside) < h2, "everyone in the mark is struck")
            assert(hp(far) == h3, "nobody outside it is")
            assert(not inMark(fair, 9, 9) and not inMark(beside, 9, 9), "and everyone is shoved out of the 3x3")
            assert(inMark({ x = lev.x, y = lev.y }, 9, 9) and inMark({ x = lev.x + 1, y = lev.y + 1 }, 9, 9),
                "it comes up in the hole")
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local sand = Hazard.at(c, 9 + dx, 9 + dy, "hazard_quicksand")
                    assert(sand and sand.remaining >= 9000, "the 3x3 is quicksand for the rest of the fight")
                    assert(not Hazard.at(c, 9 + dx, 9 + dy, "hazard_ripple"), "the ripple is gone")
                end
            end
            assert(not Status.has(lev, "status_mired"), "its own sand does not hold it")
            -- Up for a round: it can be hit, and it acts.
            local before = hp(lev)
            Combat.dealFlatDamage(c, lev, 30, { "physical", "impact" }, "test", fair)
            assert(hp(lev) < before, "in the round it is up, it can be hit")
            assert(not (AI.plan(c, lev) or {}).wait, "and it acts")
            Trait.onAnyTurnEnd(c, lev)
            assert(not lev.leviathan.head, "up, it lays no mark")
            -- ...and dives again as its next turn opens.
            Trait.onAnyTurnStart(c, lev)
            assert(Status.has(lev, "status_underground"), "after its round up, it dives")
        end,
    },
    {
        name = "the blessings move the mark: strip the Fairest and the sand rises under someone else",
        fn = function()
            local c = Fixture.combat(Fixture.new(16, 16), { walker(9, 9), walker(4, 12) },
                { unit("character_leviathan", 2, 2) })
            local a, b = c.units[1], c.units[2]
            local lev = one(c, "character_leviathan")
            bless(c, a)
            Trait.onAnyTurnEnd(c, lev)
            assert(lev.leviathan.head.x == a.x, "it marks the blessed body")
            Trait.onAnyTurnStart(c, lev) -- rises under a
            Trait.onAnyTurnStart(c, lev) -- dives
            Status.remove(c, a, "status_blessing")
            bless(c, b)
            Trait.onAnyTurnEnd(c, lev)
            assert(lev.leviathan.head.x == b.x and lev.leviathan.head.y == b.y, "the mark follows the blessing")
        end,
    },
    {
        name = "below half, its tail marks a second 3x3 under the next-Fairest every turn, and it erupts too",
        fn = function()
            local c = Fixture.combat(Fixture.new(18, 18), { walker(6, 12), walker(14, 12), walker(14, 3) },
                { unit("character_leviathan", 2, 2) })
            local first, second = c.units[1], c.units[2]
            local lev = one(c, "character_leviathan")
            bless(c, first); Status.apply(c, first, "status_regen", { duration = 40 })
            bless(c, second)
            setHp(lev, math.floor(Combat.unreservedMax(lev.char, "health") * 0.4))
            Trait.onAnyTurnEnd(c, lev)
            local head, tail = lev.leviathan.head, lev.leviathan.tails[1]
            assert(head and head.x == first.x and head.y == first.y, "the head marks the Fairest")
            assert(tail and tail.x == second.x and tail.y == second.y, "the tail marks the next-Fairest")
            local h2 = hp(second)
            Trait.onAnyTurnStart(c, lev)
            assert(hp(second) < h2 and not inMark(second, 14, 12), "the tail's 3x3 erupts and shoves")
            assert(Hazard.at(c, 14, 12, "hazard_quicksand"), "and drowns as the head's does")
            -- Up now, and still below half: the tail marks again at the end of this turn, with no head mark.
            Trait.onAnyTurnEnd(c, lev)
            assert(not lev.leviathan.head and #lev.leviathan.tails == 1, "the tail marks every turn")
        end,
    },
    {
        name = "the Undertow erupts by Leviathan's own rule: damage, everyone shoved out, quicksand",
        fn = function()
            local ab = Item.defs.ability_undertow.activeAbility
            assert(ab.windup and ab.windup > 0, "a wind-up: it erupts as the caster's next turn comes round")
            assert(ab.aoe and ab.aoe.shape == "square" and ab.aoe.radius == 1, "over a 3x3")
            local c = Fixture.combat(Fixture.new(14, 14), walker(2, 2),
                { unit("character_glass_mote", 8, 8), unit("character_glass_mote", 8, 9) })
            local caster = c.units[1]
            local m1, m2 = c.units[2], c.units[3]
            local h1 = hp(m1)
            local fx = {
                combat = c, user = caster, tx = 8, ty = 8,
                damage = function(u) return Combat.dealFlatDamage(c, u, 6, { "earth", "magical" }, "Undertow", caster) end,
                knockback = function(u, n, o) return Combat.knockback(c, caster, u, n, o) end,
                placeHazard = function(x, y, id, o) return Hazard.place(c, x, y, id, o) end,
                aoeUnits = function() return Leviathan.caught(c, 8, 8, caster) end,
            }
            ab.effect(fx)
            assert(hp(m1) < h1 or not m1.alive, "a foe in it is struck")
            for _, m in ipairs({ m1, m2 }) do
                if m.alive then assert(not inMark(m, 8, 8), "and shoved out of it") end
            end
            assert(Hazard.at(c, 7, 7, "hazard_quicksand") and Hazard.at(c, 9, 9, "hazard_quicksand"),
                "the 3x3 is quicksand")
        end,
    },
    {
        name = "Leviathan's Wake: the tiles you leave are quicksand until your next turn",
        fn = function()
            local c = Fixture.combat(Fixture.new(10, 10),
                unit("character_archer", 3, 3, { isolate = "bare", items = { "armor_leviathans_wake" } }),
                unit("character_glass_mote", 9, 9))
            local u = c.units[1]
            openTurn(c, u)
            assert(Combat.moveUnit(c, u, 4, 3), "the wearer steps")
            local sand = Hazard.at(c, 3, 3, "hazard_quicksand")
            assert(sand and sand.remaining == Status.TICKS_PER_TURN, "the tile it left is quicksand for a turn")
            assert(not Hazard.at(c, 4, 3, "hazard_quicksand"), "and never the one it stands on")
        end,
    },

    -- ------------------------------------------------------------------------------ Medusa
    {
        name = "Stone Gaze: ending a turn in her sight within 4 gains Stone, and at 3 Stone a body is Petrified",
        fn = function()
            local c = Fixture.combat(Fixture.new(14, 14, { tiles = { wall(7, 4), wall(7, 5), wall(7, 6) } }),
                { walker(5, 8), walker(5, 11), walker(8, 5) }, { unit("character_medusa", 5, 5) })
            local near, far, hidden = c.units[1], c.units[2], c.units[3]
            local medusa = one(c, "character_medusa")
            Trait.onAnyTurnEnd(c, near)
            Trait.onAnyTurnEnd(c, far)
            Trait.onAnyTurnEnd(c, hidden)
            assert(Status.stacksOf(near, "status_stone") == 1, "in sight within 4: one Stone")
            assert(not Status.has(far, "status_stone"), "beyond 4, none")
            assert(not Status.has(hidden, "status_stone"), "behind the ridge, none")
            Trait.onAnyTurnEnd(c, near)
            Trait.onAnyTurnEnd(c, near)
            assert(Status.has(near, "status_petrified"), "at 3 Stone it is Petrified")
            assert(not Status.has(near, "status_stone"), "and the Stone is spent")
            local pet = Status.get(near, "status_petrified")
            assert(pet.remaining == 2 * Status.TICKS_PER_TURN, "for 2 turns")
            assert(Status.halted(near) and Status.blocksMove(near), "it cannot act or move")
            local before = hp(near)
            local dealt = Combat.dealFlatDamage(c, near, 40, { "physical", "slash" }, "test", medusa)
            local control = Combat.mitigatedDamage(far, 40, { "physical", "slash" })
            assert(dealt > 0 and dealt <= math.ceil(control / 2) + 1, string.format(
                "it takes half damage (%d against %d)", dealt, control))
            assert(hp(near) == before - dealt, "the halved blow is the wound")
            Trait.onAnyTurnEnd(c, near)
            assert(not Status.has(near, "status_stone"), "a Petrified body gains no more Stone")
        end,
    },
    {
        name = "Perseus: a body carrying the Hand-Mirror gains no Stone and turns it back on her",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                unit("character_archer", 5, 7, { isolate = "bare", items = { "utility_hand_mirror" } }),
                { unit("character_medusa", 5, 5) })
            local hero, medusa = c.units[1], one(c, "character_medusa")
            assert(Gorgon.mirrored(hero), "the mirror is in the grid")
            for _ = 1, 3 do Trait.onAnyTurnEnd(c, hero) end
            assert(not Status.has(hero, "status_stone") and not Status.has(hero, "status_petrified"),
                "the bearer gains no Stone")
            assert(Status.has(medusa, "status_petrified"), "the gaze turns back and she is Petrified at 3")
        end,
    },
    {
        name = "her blood: a slashing blow that cuts her springs an adder beside her, and a club does not",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), walker(5, 7), { unit("character_medusa", 5, 5) })
            local hero, medusa = c.units[1], one(c, "character_medusa")
            Combat.dealFlatDamage(c, medusa, 10, { "physical", "impact" }, "test", hero)
            assert(not one(c, "character_adder"), "an impact blow springs nothing")
            Combat.dealFlatDamage(c, medusa, 10, { "physical", "slash" }, "test", hero)
            local adder = one(c, "character_adder")
            assert(adder and adder.side == medusa.side, "a slash springs an adder on her side")
            assert(Combat.unitGap(adder, medusa) == 1, "beside her")
            local fang = Fixture.itemNamed(adder.char, "weapon_adder_fang")
            assert(fang, "a small poisoner")
            for _ = 1, 8 do Combat.dealFlatDamage(c, medusa, 1, { "physical", "slash" }, "test", hero) end
            local n = 0
            for _, u in ipairs(c.units) do if u.alive and u.char.id == "character_adder" then n = n + 1 end end
            assert(n == Gorgon.MAX_ADDERS, "held to four at once: " .. n)
        end,
    },
    {
        name = "her garden: three statues stand Petrified, and at her half health they crack open and fight",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), walker(2, 10), {
                unit("character_medusa", 5, 5), unit("character_stone_challenger", 7, 3),
                unit("character_stone_challenger", 3, 3), unit("character_stone_challenger", 8, 6) })
            local medusa = one(c, "character_medusa")
            local statues = {}
            for _, u in ipairs(c.units) do
                if u.char.id == "character_stone_challenger" then statues[#statues + 1] = u end
            end
            for _, s in ipairs(statues) do
                assert(Status.has(s, "status_petrified"), "a statue opens Petrified")
                Trait.onAnyTurnEnd(c, s)
                assert(Status.has(s, "status_petrified"), "and is held so turn after turn")
            end
            Combat.dealFlatDamage(c, medusa, 10, { "physical", "impact" }, "test", c.units[1])
            assert(Status.has(statues[1], "status_petrified"), "a scratch wakes nothing")
            setHp(medusa, math.floor(Combat.unreservedMax(medusa.char, "health") * 0.5) + 5)
            Combat.dealFlatDamage(c, medusa, 30, { "physical", "impact" }, "test", c.units[1])
            for _, s in ipairs(statues) do
                assert(not Status.has(s, "status_petrified"), "past half, the statue cracks open")
                Trait.onAnyTurnEnd(c, s)
                assert(not Status.has(s, "status_petrified"), "and stays awake")
            end
        end,
    },
    {
        name = "the Gorgon's Gaze lays Stone down a line of 4, and Serpent Locks springs an adder for its wearer",
        fn = function()
            local ab = Item.defs.ability_gorgons_gaze.activeAbility
            assert(ab.aoe.shape == "line" and ab.aoe.length == 4, "a line of 4")
            local c = Fixture.combat(Fixture.new(12, 12),
                unit("character_archer", 3, 3, { isolate = "bare", items = { "armor_serpent_locks" } }),
                { unit("character_glass_mote", 4, 3), unit("character_glass_mote", 6, 3) })
            local wearer, m1, m2 = c.units[1], c.units[2], c.units[3]
            local fx = {
                user = wearer,
                aoeUnits = function() return { m1, m2, wearer } end,
                applyStatus = function(u, id) return Status.apply(c, u, id, { applier = wearer }) end,
            }
            for _ = 1, 3 do ab.effect(fx) end
            assert(Status.has(m1, "status_petrified") and Status.has(m2, "status_petrified"),
                "three gazes petrify every foe in the line")
            assert(not Status.has(wearer, "status_stone"), "never the caster's own side")
            Combat.dealFlatDamage(c, wearer, 5, { "physical", "slash" }, "test", m1)
            local adder = one(c, "character_adder")
            assert(adder and adder.side == wearer.side, "a slash on the wearer springs an adder on the company's side")
        end,
    },
    {
        name = "the Hand-Mirror rebounds a single-target attack while its bearer holds the most blessings",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), {
                unit("character_archer", 5, 5, { isolate = "bare", items = { "utility_hand_mirror" } }),
                walker(9, 9) }, { walker(5, 8) })
            local bearer, ally, foe = c.units[1], c.units[2], c.units[3]
            local bow = Combat.defaultWeapon(foe.char)
            assert(bow and not bow.activeAbility.aoe, "the foe aims a single-target weapon")
            assert(not Gorgon.handMirror(c, bearer), "with no blessing it answers nothing")
            bless(c, bearer)
            assert(Gorgon.handMirror(c, bearer), "holding more blessings than any ally, it answers")
            local hb, hf = hp(bearer), hp(foe)
            local ok, why = Fixture.strike(c, foe, bearer, bow)
            assert(ok, "the shot is loosed: " .. tostring(why))
            assert(hp(bearer) == hb and hp(foe) < hf, "the attack rebounds onto the attacker")
            bless(c, ally)
            assert(not Gorgon.handMirror(c, bearer), "an ally holding as many blessings closes the mirror")
        end,
    },

    -- ------------------------------------------------------------------------------ the Kinslayer
    {
        name = "the Kinslayer hunts the favoured one: the body healed or blessed most this fight, shown by a counter",
        fn = function()
            local c = Fixture.combat(Fixture.new(14, 14), { walker(3, 3), walker(10, 10) },
                { unit("character_the_kinslayer", 7, 3) })
            local a, b = c.units[1], c.units[2]
            local k = one(c, "character_the_kinslayer")
            assert(not Kinslayer.favoured(c, k), "nobody is favoured before anybody is tended")
            setHp(b, 200); Combat.applyHeal(c, b, 10); Combat.applyHeal(c, b, 10)
            bless(c, a)
            Trait.onAnyTurnEnd(c, a)
            assert(Kinslayer.favoured(c, k) == b, "two heals outweigh one blessing")
            local badge = Status.get(b, "status_favoured")
            assert(badge and badge.magnitude == 2, "the favoured body wears the counter, reading 2")
            assert(not Status.has(a, "status_favoured"), "and nobody else does")
            assert(#Combat.dispellableOn(b, math.huge) == 0, "the counter is not a blessing")
            local plan = AI.plan(c, k)
            assert(plan and ((plan.tx == b.x and plan.ty == b.y) or plan.move), "he goes for the favoured one")
            if plan.move then
                assert(Combat.cellGap(plan.move.x, plan.move.y, b) < Combat.cellGap(k.x, k.y, b), "closing on it")
            end
            -- A refresh lands nothing new; two fresh blessings take a to three.
            bless(c, a)
            Status.apply(c, a, "status_regen", { duration = 40 })
            Status.apply(c, a, "status_hasted", { duration = 40 })
            assert(Kinslayer.favourOf(k, a) == 3, "a blessing counts once, when it lands fresh")
            Trait.onAnyTurnEnd(c, b)
            assert(Kinslayer.favoured(c, k) == a and Status.has(a, "status_favoured")
                and not Status.has(b, "status_favoured"), "the counter moves when someone else is tended more")
        end,
    },
    {
        name = "the Mark: whoever lands his killing blow takes 7 times his last hit; a burn finds no killer",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), { walker(5, 6, 500), walker(9, 9, 500) },
                { unit("character_the_kinslayer", 5, 5) })
            local killer, other = c.units[1], c.units[2]
            local k = one(c, "character_the_kinslayer")
            k.lastHitDealt = 9
            setHp(k, 5)
            local before = hp(killer)
            Combat.dealFlatDamage(c, k, 50, { "physical", "slash" }, "test", killer)
            assert(not k.alive or k.incapacitated, "he falls")
            assert(before - hp(killer) == 63, "the killer takes 7 x his last hit: " .. (before - hp(killer)))
            assert(hp(other) == 500, "nobody else does")

            local c2 = Fixture.combat(Fixture.new(12, 12), walker(5, 6, 500), { unit("character_the_kinslayer", 5, 5) })
            local striker, k2 = c2.units[1], one(c2, "character_the_kinslayer")
            Combat.dealFlatDamage(c2, k2, 10, { "physical", "slash" }, "test", striker)
            k2.lastHitDealt = 9
            setHp(k2, 3)
            local h = hp(striker)
            Combat.dealFlatDamage(c2, k2, 20, { "fire", "burn" }, "Burn") -- a burn tick: no attacker
            assert(not k2.alive or k2.incapacitated, "the burn fells him")
            assert(hp(striker) == h, "and the Mark finds no killer, though somebody struck him before")
        end,
    },
    {
        name = "The Mark, worn: a foe that lands a killing blow on you takes 7 times that blow back",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12),
                unit("character_archer", 5, 6, { isolate = "bare", items = { "utility_the_mark" } }),
                { unit("character_glass_mote", 5, 5) })
            local wearer, mote = c.units[1], c.units[2]
            mote.char.stats.health.max, mote.char.stats.health.current = 500, 500
            setHp(wearer, 1)
            local dealt = Combat.dealFlatDamage(c, wearer, 6, { "physical", "pierce" }, "test", mote)
            assert(not wearer.alive or wearer.incapacitated, "the wearer falls")
            assert(500 - hp(mote) == 7 * dealt, string.format("the killer takes 7 x the blow (%d): %d",
                dealt, 500 - hp(mote)))
        end,
    },
}
