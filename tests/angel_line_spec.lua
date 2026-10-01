-- Tests for THE ANGELS OF PRIDE (2026-09-30, "Pride's Bestiary"): the race, its rule, the choir's own mechanics,
-- the fights and the drops.
--
--   Incorruptible   nothing from outside the choir lands on an angel -- no foe's debuff, no push or pull -- while
--                   its own side's statuses still land; and it flies
--   the choir       the Herald (the Hymn: angels within 2 Blessed at its turn's end), the Virtue (Aegis on the ally
--                   hurt most last round), the Seraph (a foe starting its turn beside it Burns), the Ophan (strikes
--                   every adjacent tile, cannot be avoided) and the Throne (2x2, never moves: the Decree's cycling
--                   patterns, the Sentence's chain, Hosanna's Heralds at each quarter)
-- Each case pins a rule the review approved, on a bare board.

local Character = require("models.character")
local Combat = require("models.combat")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Race = require("models.race")
local Status = require("models.status")
local Trait = require("models.trait")
local Choir = require("models.choir")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local ANGELS = {
    "character_herald", "character_virtue", "character_seraph", "character_ophan", "character_the_throne",
}
local TROPHIES = {
    "utility_heralds_trumpet", "ability_virtues_aegis", "armor_seraphs_wing", "weapon_wheel_of_eyes",
    "ability_thrones_verdict",
}
local ORGANS = {
    "utility_angel_blood", "utility_the_hymn", "utility_the_turning", "utility_the_sentence", "utility_hosanna",
    "weapon_choir_light", "weapon_seraph_flame", "weapon_the_decree",
}
local FIGHTS = {
    encounter_pride_the_choir = "combat", encounter_pride_the_burning_watch = "combat",
    encounter_pride_the_wheels = "combat", encounter_pride_gilt_and_wing = "combat",
    encounter_pride_the_throne = "elite",
}

local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function sideOf(c, side)
    local out = {}
    for _, u in ipairs(c.units) do if u.side == side then out[#out + 1] = u end end
    return out
end

-- A bare body carrying `items`, health 200, for a rule-on-a-board case.
local function body(x, y, items)
    return unit("character_archer", x, y, { isolate = "bare", items = items or {}, stats = { health = 200 } })
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "the angel is an unplayable race that turns holy, takes dark, and grants Incorruptible and wings",
        fn = function()
            local def = Race.defs["angel"]
            assert(def and def.kind == "humanoid", "an angel is a race of bodies")
            assert(def.playable == false, "no company hires an angel (approved)")
            assert(def.resist.holy > 0 and def.resist.dark < 0, "light turns aside on light; the dark goes in")
            local grant = Item.defs["utility_angel_blood"]
            assert(grant.bound and grant.noSteal, "Incorruptible is an organ, not kit")
            for _, id in ipairs(ANGELS) do
                local c = Character.instantiate(id)
                assert(c.race == "angel", id .. " is an angel")
                assert(itemNamed(c, "utility_angel_blood"), id .. ": the race put Incorruptible in the grid")
            end
            local cb = Fixture.combat(Fixture.new(6, 6), walker(1, 1), { unit("character_herald", 4, 4) })
            assert(Combat.isFlying(one(cb, "character_herald")), "winged: an angel flies over the ground")
        end,
    },
    {
        name = "every angel trophy is an unstocked find on an angel's drop list, on a real shelf",
        fn = function()
            local dropped = {}
            for _, id in ipairs(ANGELS) do
                for _, d in ipairs(Character.defs[id].drops or {}) do dropped[d] = true end
            end
            local shelves = {
                utility_heralds_trumpet = "theurge", ability_virtues_aegis = "priest", armor_seraphs_wing = "crusader",
                weapon_wheel_of_eyes = "skirmisher", ability_thrones_verdict = "inquisitor",
            }
            for _, id in ipairs(TROPHIES) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.unstocked, id .. " is a trophy: seen on the rack, never sold")
                assert(dropped[id], id .. " is on an angel's drop list")
                assert(def.class == shelves[id], id .. " sits on the " .. shelves[id] .. " shelf")
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature" and def.noSteal, id .. " is a body's own and cannot be taken")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
        end,
    },
    {
        name = "five fights stand on the spire's seat: four ordinary, and the Throne as its elite",
        fn = function()
            for id, kind in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e, id .. " exists")
                assert(e.kind == kind, id .. " is " .. kind)
                assert(e.rung == 2, id .. " stands on the seat (rung 2)")
                assert(e.condition({ biome = "spire" }) and not e.condition({ biome = "cave" }),
                    id .. " is locked to the spire")
            end
            local throne = Encounter.get("encounter_pride_the_throne").composition({})
            local seen = {}
            for _, id in ipairs(throne) do seen[id] = true end
            assert(seen.character_the_throne and seen.character_ophan and seen.character_herald,
                "the Throne is fielded with an Ophan and its Heralds")
            local gilt = Encounter.get("encounter_pride_gilt_and_wing").composition({})
            local mixed = {}
            for _, id in ipairs(gilt) do mixed[Character.defs[id].race] = true end
            assert(mixed.angel and mixed.construct, "Gilt and Wing stands the choir beside the gilded rank")
        end,
    },
    -- ------------------------------------------------------------------------------ Incorruptible
    {
        name = "Incorruptible: a foe's Root, Stun and Charm never land, and nothing moves an angel",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), body(4, 6), { body(4, 4, { "utility_angel_blood" }) })
            local foe, angel = sideOf(c, "party")[1], sideOf(c, "enemy")[1]
            for _, id in ipairs({ "status_root", "status_stun", "status_charm", "status_burn" }) do
                assert(Status.apply(c, angel, id, { applier = foe }) == nil, id .. " from a foe does not land")
                assert(not Status.has(angel, id), "and is not worn")
            end
            assert(Status.apply(c, angel, "status_burn") == nil, "ground nobody of its side laid does not land either")
            assert(Status.isImmune(angel, "status_root"), "and the tooltip reads the same wall")
            assert(Status.blocksForcedMove(angel), "no push and no pull")
            Combat.knockback(c, foe, angel, 2)
            assert(angel.x == 4 and angel.y == 4, "a shove finds nothing to move")
        end,
    },
    {
        name = "Incorruptible keeps out only what comes from outside: the choir's own statuses land",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), body(1, 1),
                { body(4, 4, { "utility_angel_blood" }), body(4, 5) })
            local enemies = sideOf(c, "enemy")
            local angel, ally = enemies[1], enemies[2]
            assert(Status.apply(c, angel, "status_root", { applier = ally }), "its own side's debuff lands")
            assert(Status.apply(c, angel, "status_blessing", { applier = ally }), "and its own side's blessing")
            local plain = Fixture.combat(Fixture.new(9, 9), body(4, 6), { body(4, 4) })
            assert(Status.apply(plain, sideOf(plain, "enemy")[1], "status_root", { applier = sideOf(plain, "party")[1] }),
                "a body without the rule is rooted as ever")
        end,
    },
    -- ------------------------------------------------------------------------------ the Herald
    {
        name = "the Hymn: at the Herald's turn's end, every angel within 2 is Blessed, and nobody else",
        fn = function()
            local c = Fixture.combat(Fixture.new(11, 11), walker(10, 10), {
                unit("character_herald", 5, 5),
                unit("character_virtue", 5, 7),          -- an angel within 2
                unit("character_seraph", 5, 8),          -- an angel at 3
                body(6, 5),                              -- a gilded neighbour: not an angel
            })
            local herald = one(c, "character_herald")
            local enemies = sideOf(c, "enemy")
            Trait.onAnyTurnEnd(c, herald)
            assert(Status.has(enemies[2], "status_blessing"), "the angel within 2 is Blessed")
            assert(not Status.has(enemies[3], "status_blessing"), "the angel at 3 is not")
            assert(not Status.has(enemies[4], "status_blessing"), "the Hymn is for angels only")
            assert(not Status.has(herald, "status_blessing"), "a herald announces; it is not announced")
        end,
    },
    {
        name = "the Herald's Trumpet blesses every ally within 2, angel or not",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), { body(4, 4, { "utility_heralds_trumpet" }), body(4, 6) },
                { body(8, 8) })
            local bearer, ally = sideOf(c, "party")[1], sideOf(c, "party")[2]
            Trait.onAnyTurnEnd(c, bearer)
            assert(Status.has(ally, "status_blessing"), "the company's copy has no kin")
        end,
    },
    -- ------------------------------------------------------------------------------ the Virtue
    {
        name = "Virtue's Aegis wards the ally hurt most since its last turn, and refuses when nobody was",
        fn = function()
            local c = Fixture.combat(Fixture.new(11, 11), walker(10, 10), {
                unit("character_virtue", 5, 5), body(5, 6, { "utility_angel_blood" }), body(6, 5, { "utility_angel_blood" }),
            })
            local virtue, foe = one(c, "character_virtue"), sideOf(c, "party")[1]
            local enemies = sideOf(c, "enemy")
            local a, b = enemies[2], enemies[3]
            local aegis = itemNamed(virtue.char, "ability_virtues_aegis")
            Trait.onAnyTurnEnd(c, virtue) -- the round starts here
            assert(Combat.itemBlockReason(virtue, aegis), "nobody hurt: nothing to answer")
            Combat.dealFlatDamage(c, a, 10, { "physical" }, "test", foe, { raw = true })
            Combat.dealFlatDamage(c, b, 25, { "physical" }, "test", foe, { raw = true })
            openTurn(c, virtue)
            assert(Combat.useItem(c, virtue, aegis, virtue.x, virtue.y), "the ward is laid")
            assert(Status.has(b, "status_aegis"), "on the one that bled most")
            assert(not Status.has(a, "status_aegis"), "and only on that one")
            Trait.onAnyTurnEnd(c, virtue) -- a new round: the old wounds are banked
            local ab = aegis.activeAbility
            assert(not ab.usable(virtue, aegis), "what bled last round is not this round's wound")
            Combat.dealFlatDamage(c, a, 5, { "physical" }, "test", foe, { raw = true })
            assert(ab.usable(virtue, aegis), "a fresh wound is")
        end,
    },
    -- ------------------------------------------------------------------------------ the Seraph
    {
        name = "the Burning One: a foe that starts its turn beside a Seraph Burns, and one a tile off does not",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), { walker(4, 5), walker(4, 7) }, { unit("character_seraph", 4, 4) })
            local near, far = sideOf(c, "party")[1], sideOf(c, "party")[2]
            Trait.onAnyTurnStart(c, near)
            Trait.onAnyTurnStart(c, far)
            assert(Status.has(near, "status_burn"), "beside it when the turn opens: alight")
            assert(not Status.has(far, "status_burn"), "two tiles off: untouched")
            -- ...and it is wired: the turn that opens is heard.
            local c2 = Fixture.combat(Fixture.new(9, 9), walker(4, 5), { unit("character_seraph", 4, 4) })
            local foe = sideOf(c2, "party")[1]
            for _, u in ipairs(c2.units) do u.initiative = (u == foe) and 0 or 50 end
            assert(Combat.startTurn(c2) == foe, "the foe's turn opens")
            assert(Status.has(foe, "status_burn"), "and opens in flames")
        end,
    },
    -- ------------------------------------------------------------------------------ the Ophan
    {
        name = "the Wheel of Eyes strikes every adjacent foe, and its blows cannot be avoided",
        fn = function()
            local c = Fixture.combat(Fixture.new(9, 9), { walker(5, 4), walker(4, 5), walker(5, 7) },
                { unit("character_ophan", 5, 5) })
            local ophan = one(c, "character_ophan")
            local party = sideOf(c, "party")
            local wheel = itemNamed(ophan.char, "weapon_wheel_of_eyes")
            assert(not Combat.rollsToHit(c, ophan, party[1], wheel), "it does not roll: nothing steps aside from it")
            local plan = Choir.plan(c, ophan)
            assert(plan and plan.item == wheel, "with a foe beside it, the wheel turns")
            local before = { hp(party[1]), hp(party[2]), hp(party[3]) }
            openTurn(c, ophan)
            assert(Combat.useItem(c, ophan, wheel, ophan.x, ophan.y), "it turns")
            assert(hp(party[1]) < before[1] and hp(party[2]) < before[2], "both adjacent foes are struck")
            assert(hp(party[3]) == before[3], "the one two tiles off is not")
        end,
    },
    -- ------------------------------------------------------------------------------ the Throne
    {
        name = "the Throne is a 2x2 boss that never moves",
        fn = function()
            local def = Character.defs["character_the_throne"]
            assert(def.footprint.w == 2 and def.footprint.h == 2, "four tiles of burning wheel")
            assert(def.boss, "the fight is it")
            assert(def.stats.movement == 0, "it does not come to you")
            assert(def.tier == 3, "an elite")
        end,
    },
    {
        name = "the Decree lights the cross, then the rings, then the lines, and lands on the foes in the light",
        fn = function()
            local c = Fixture.combat(Fixture.new(14, 14), { walker(5, 10), walker(10, 10) },
                { unit("character_the_throne", 5, 5) })
            local throne = one(c, "character_the_throne")
            local inCross, offCross = sideOf(c, "party")[1], sideOf(c, "party")[2]
            assert(Choir.pattern(throne) == "cross", "the first decree is the cross")
            local function lit(cells, x, y)
                for _, p in ipairs(cells) do if p.x == x and p.y == y then return true end end
                return false
            end
            local cross = Choir.decreeCells(c, throne)
            assert(lit(cross, 5, 10) and lit(cross, 6, 1) and not lit(cross, 10, 10), "the rows and columns it stands in")
            assert(not lit(cross, 5, 5), "never its own tiles")
            local rings = Choir.decreeCells(c, throne, "rings")
            assert(lit(rings, 8, 5) and not lit(rings, 7, 5) and not lit(rings, 9, 5), "every second ring: 2, 4, 6 out")
            local lines = Choir.decreeCells(c, throne, "lines")
            assert(lit(lines, 1, 4) and lit(lines, 1, 10) and not lit(lines, 1, 8), "every third row: 1, 4, 7 out")

            local plan = Choir.plan(c, throne)
            local decree = itemNamed(throne.char, "weapon_the_decree")
            assert(plan and plan.item == decree, "a Throne holding no decree decrees")
            openTurn(c, throne)
            assert(Combat.useItem(c, throne, decree, throne.x, throne.y), "the decree is lit")
            assert(throne.channel, "and it hangs for a turn: the board's wind-up telegraph")
            assert(Choir.plan(c, throne) == nil, "a Throne holding a decree does not light another")
            local a, b = hp(inCross), hp(offCross)
            Combat.resolveChannel(c, throne)
            assert(hp(inCross) < a, "the foe standing in the light is struck")
            assert(hp(offCross) == b, "the foe that read the floor is not")
            assert(Choir.pattern(throne) == "rings", "and the next decree is the rings")
            throne.decrees = 2
            assert(Choir.pattern(throne) == "lines", "then the lines")
            throne.decrees = 3
            assert(Choir.pattern(throne) == "cross", "and round again")
        end,
    },
    {
        name = "the Sentence: every third turn the two furthest apart are chained, and ending a turn apart hurts both",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), { walker(1, 1), walker(11, 11), walker(2, 2) },
                { unit("character_the_throne", 6, 6) })
            local throne = one(c, "character_the_throne")
            local party = sideOf(c, "party")
            local a, b, near = party[1], party[2], party[3]
            Trait.onAnyTurnEnd(c, throne)
            Trait.onAnyTurnEnd(c, throne)
            assert(not Status.has(a, "status_sentenced"), "not yet")
            Trait.onAnyTurnEnd(c, throne)
            local sa, sb = Status.get(a, "status_sentenced"), Status.get(b, "status_sentenced")
            assert(sa and sb, "on the third turn, the two furthest apart are sentenced")
            assert(sa.partner == b and sb.partner == a, "each naming the other")
            assert(not Status.has(near, "status_sentenced"), "and nobody else")
            local ha, hb = hp(a), hp(b)
            Status.onTurnEnd(c, a)
            assert(hp(a) < ha and hp(b) < hb, "a turn ended more than 2 apart hurts both")
            a.x, a.y = 10, 11
            ha, hb = hp(a), hp(b)
            Status.onTurnEnd(c, a)
            assert(hp(a) == ha and hp(b) == hb, "close up, and the chain holds its peace")
        end,
    },
    {
        name = "Hosanna: two Heralds are called at each quarter, on the reinforcement telegraph, and sent home if it falls",
        fn = function()
            local c = Fixture.combat(Fixture.new(12, 12), walker(1, 1), { unit("character_the_throne", 6, 6) })
            local throne, foe = one(c, "character_the_throne"), sideOf(c, "party")[1]
            local max = maxHp(throne)
            local function waves() return (c.objective.waves and #c.objective.waves) or 0 end
            Combat.dealFlatDamage(c, throne, math.floor(max * 0.2), { "physical" }, "test", foe, { raw = true })
            assert(waves() == 0, "above three quarters: no call")
            Combat.dealFlatDamage(c, throne, math.floor(max * 0.1), { "physical" }, "test", foe, { raw = true })
            assert(waves() == 1, "past 75%: the choir answers")
            local w = c.objective.waves[1]
            assert(#w.composition == 2 and w.composition[1] == "character_herald", "two Heralds")
            assert(w.at > (c.clock or 0), "due ahead, so the muster is telegraphed before it lands")
            Combat.dealFlatDamage(c, throne, math.floor(max * 0.5), { "physical" }, "test", foe, { raw = true })
            assert(waves() == 3, "one blow across 50% and 25% calls both pairs")
            assert(not Combat.allWavesArrived(c, c.objective), "and they are owed")
            Combat.dealFlatDamage(c, throne, max, { "physical" }, "test", foe, { raw = true })
            assert(not throne.alive, "the Throne falls")
            assert(Combat.allWavesArrived(c, c.objective), "and whoever it called and had not landed is sent home")
        end,
    },
    {
        name = "Throne's Verdict lights a 3x3 and lands at the caster's next turn, on foes only",
        fn = function()
            local c = Fixture.combat(Fixture.new(11, 11),
                { body(4, 4, { "ability_thrones_verdict" }), body(6, 7) }, { body(6, 6), body(9, 9) })
            local caster, friend = sideOf(c, "party")[1], sideOf(c, "party")[2]
            local hit, clear = sideOf(c, "enemy")[1], sideOf(c, "enemy")[2]
            caster.char.stats.mana.max, caster.char.stats.mana.current = 50, 50
            local verdict = itemNamed(caster.char, "ability_thrones_verdict")
            openTurn(c, caster)
            assert(Combat.useItem(c, caster, verdict, 6, 6), "the verdict is lit")
            assert(caster.channel, "and it waits for the caster's next turn")
            local h, f, k = hp(hit), hp(friend), hp(clear)
            Combat.resolveChannel(c, caster)
            assert(hp(hit) < h, "the foe in the square is struck")
            assert(hp(friend) == f, "the caster's own side is spared")
            assert(hp(clear) == k, "and nothing outside the square is touched")
        end,
    },
}
