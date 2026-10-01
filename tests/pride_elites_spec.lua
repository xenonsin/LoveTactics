-- Tests for PRIDE'S ONE-OFF ELITES ("Pride's Bestiary", 2026-09-30): four creatures from four myths about
-- pride, each its own encounter on the spire, each with its own drop.
--
--   The Unicorn      rejects the unworthy -- no body carrying a debuff, a curse or an injury can hurt it; its
--                    horn Blights what it strikes (a debuff), and it cleanses its side at the end of its turn
--   The Sphinx       never wrong -- a riddle each turn, off the fight's seed; unanswered it takes no damage,
--                    met it is Answered until its next turn, failed it heals 10%
--   The Phoenix      never repents, only returns -- felled, an Ember that rises in three turns, +3 Damage a death
--   The Tower-Giant  Ambition each turn; it crashes within 1 + Ambition/3 for 6 damage a stack when it falls
--
-- Each case pins a rule the review approved, on a bare board, plus the four drops and the fights' rungs.

local Character = require("models.character")
local Combat = require("models.combat")
local Curse = require("models.curse")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Spoils = require("models.spoils")
local Status = require("models.status")
local Trait = require("models.trait")
local PrideElites = require("models.pride_elites")
local Fixture = require("tests.support.fixture")

local unit, openTurn, itemNamed, hp = Fixture.unit, Fixture.openTurn, Fixture.itemNamed, Fixture.hp

local BODIES = {
    character_unicorn = "weapon_horn_of_purity",
    character_sphinx = "utility_sphinxs_riddle",
    character_phoenix = "utility_phoenix_feather",
    character_tower_giant = "weapon_babel_maul",
}
local DROPS = {
    weapon_horn_of_purity = { class = "exorcist", rung = 13 },
    utility_sphinxs_riddle = { class = "inquisitor", rung = 13 },
    utility_phoenix_feather = { class = "priest", rung = 14 },
    weapon_babel_maul = { class = "barbarian", rung = 14 },
}
local ORGANS = {
    "weapon_spiral_horn", "utility_purity", "weapon_lions_paw", "utility_the_riddle",
    "weapon_ember_talons", "utility_never_repents", "weapon_masonry_fist", "utility_the_unfinished_tower",
}
local FIGHTS = {
    encounter_pride_the_unicorn = { rung = 1 },
    encounter_pride_the_sphinx = { rung = 1, alone = true },
    encounter_pride_the_phoenix = { rung = 2, alone = true },
    encounter_pride_the_tower_giant = { rung = 2, alone = true },
}

-- A company body that takes a blow and lands one: a walker on a deep pool, its armour off.
local function walker(x, y, health)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = health or 300, health or 300
    return spawn
end

local function board(n, seed) return Fixture.new(n or 11, n or 11, { seed = seed }) end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id and u.alive then return u end end
end

local function fight(id, x, y, party, extra, seed)
    local enemies = { unit(id, x, y) }
    for _, e in ipairs(extra or {}) do enemies[#enemies + 1] = e end
    return Fixture.combat(board(nil, seed), party or walker(1, 1), enemies)
end

local function riddleOf(u)
    for _, t in ipairs(u.traits or {}) do if t.def.riddler then return t end end
end

-- Point the riddle the trait is judging at `id`, with a fresh record of the round.
local function setRiddle(t, id)
    for _, r in ipairs(PrideElites.RIDDLES) do if r.id == id then t.riddle = r end end
    t.record = { moved = false, strikers = 0, strikerSet = {}, struck = {}, fire = false, far = false,
                 together = false }
end

local function maxHp(u) return Combat.unreservedMax(u.char, "health") end

local function hit(c, target, amount, attacker)
    local before = hp(target)
    Combat.dealFlatDamage(c, target, amount or 20, { "physical" }, "test", attacker, { raw = true })
    return before - hp(target)
end

return {
    -- ------------------------------------------------------------------------------ the content
    {
        name = "four elite bodies, each a boss with its own organ, dropping a real class's trophy",
        fn = function()
            for id, drop in pairs(BODIES) do
                local def = Character.defs[id]
                assert(def, id .. " exists")
                assert(def.tier == 3 and def.boss, id .. " is a tier-3 boss: the fight is about it")
                local listed = false
                for _, d in ipairs(def.drops or {}) do if d == drop then listed = true end end
                assert(listed, id .. " drops " .. drop)
            end
            for id, want in pairs(DROPS) do
                local def = Item.defs[id]
                assert(def and def.unstocked, id .. " is an unstocked trophy")
                assert(def.class == want.class, id .. " sits on the " .. want.class .. " shelf")
                assert(Spoils.depthOf(def) == want.rung, id .. " falls on floor " .. want.rung)
            end
            for _, id in ipairs(ORGANS) do
                local def = Item.defs[id]
                assert(def and def.class == "creature" and def.noSteal, id .. " is a body's own")
                if def.type == "utility" then assert(def.bound, id .. " is an organ, bound to the body") end
            end
            local ember = Character.defs["character_phoenix_ember"]
            assert(ember.race == "object" and ember.timeless and ember.scaling == false,
                "the Ember is a thing on the board that takes no turns and does not grow")
        end,
    },
    {
        name = "four elites on the spire: the Unicorn and the Sphinx on the approach, the Phoenix and the Giant on the seat",
        fn = function()
            for id, want in pairs(FIGHTS) do
                local e = Encounter.get(id)
                assert(e and e.kind == "elite", id .. " is an elite")
                assert(e.rung == want.rung, id .. " stands on rung " .. want.rung)
                assert(e.condition({ biome = "spire" }) and not e.condition({ biome = "cave" }), id .. " is the spire's")
                assert((e.alone == true) == (want.alone == true), id .. " alone: " .. tostring(want.alone))
                assert(e.objective and e.objective.type == "killAll", id .. " is played out, never walked off")
            end
            local roster = Encounter.get("encounter_pride_the_unicorn").composition({ depth = 13, seed = 3 })
            local pages = 0
            for _, id in ipairs(roster) do if id == "character_gilded_page" then pages = pages + 1 end end
            assert(roster[1] == "character_unicorn" and pages >= 1, "the Unicorn comes with Gilded Pages to cleanse")
        end,
    },
    -- ------------------------------------------------------------------------------ the Unicorn
    {
        name = "the Unicorn: a clean body hurts it; a debuff, a curse or an injury on the striker turns the blow away",
        fn = function()
            local c = fight("character_unicorn", 5, 5, { walker(5, 6), walker(4, 5), walker(6, 5), walker(5, 4) })
            local clean, debuffed, hexed, injured = c.units[1], c.units[2], c.units[3], c.units[4]
            local uni = one(c, "character_unicorn")
            assert(hit(c, uni, 10, clean) > 0, "a worthy body draws blood")
            Status.apply(c, debuffed, "status_root", {})
            assert(hit(c, uni, 10, debuffed) == 0, "a debuffed body does not")
            assert(Combat.mitigatedDamage(uni, 10, { "physical" }, { raw = true }, debuffed) == 0,
                "and the forecast says so before the swing")
            local piece = itemNamed(hexed.char, "weapon_iron_bow") or Character.eachItem(hexed.char)[1]
            assert(Curse.afflict(piece, "curse_dead_weight"), "the bow takes a hex")
            assert(PrideElites.unworthy(hexed) == "a curse", "a hexed piece is a curse")
            assert(hit(c, uni, 10, hexed) == 0, "a hexed body does not")
            injured.char.injuryShare = { health = 0.06 }
            assert(PrideElites.unworthy(injured) == "an injury", "a reserved pool is an injury")
            assert(hit(c, uni, 10, injured) == 0, "an injured body does not")
            injured.char.injuryShare = nil
            Status.apply(c, injured, "status_torn_shoulder", { duration = 9999 })
            assert(not Status.defs["status_torn_shoulder"].debuff, "an injury badge is no debuff")
            assert(PrideElites.unworthy(injured) == "an injury", "and still reads as an injury")
            assert(hit(c, uni, 10, nil) > 0, "a blow with no striker (a trap, a burn) is judged by nobody")
        end,
    },
    {
        name = "the Unicorn's horn Blights what it strikes, and a Blighted body cannot hurt it until it is Cured",
        fn = function()
            local c = fight("character_unicorn", 5, 5, walker(5, 6))
            local foe, uni = c.units[1], one(c, "character_unicorn")
            assert(Fixture.strike(c, uni, foe, "weapon_spiral_horn"), "the horn strikes")
            assert(Status.has(foe, "status_blighted"), "and Blights")
            assert(Status.defs["status_blighted"].debuff, "Blighted is a debuff")
            assert(hit(c, uni, 10, foe) == 0, "so the struck body is unworthy")
            Status.cleanse(c, foe)
            assert(hit(c, uni, 10, foe) > 0, "Cured, it is worthy again")
        end,
    },
    {
        name = "the Unicorn cleanses its side at the end of its turn, itself included",
        fn = function()
            local page = unit("character_gilded_page", 5, 4)
            local c = fight("character_unicorn", 5, 5, walker(1, 1), { page })
            local uni, pg = one(c, "character_unicorn"), one(c, "character_gilded_page")
            Status.apply(c, pg, "status_root", {})
            Status.apply(c, uni, "status_root", {})
            Trait.onAnyTurnEnd(c, uni)
            assert(not Status.has(pg, "status_root"), "the page is washed")
            assert(not Status.has(uni, "status_root"), "and so is the Unicorn")
        end,
    },
    {
        name = "the Horn of Purity: a hit Blights, and it strikes for 3 more while its bearer carries no debuff",
        fn = function()
            local function swing(dirty)
                local c = Fixture.combat(board(),
                    unit("character_archer", 5, 6, { isolate = "bare", items = { "weapon_horn_of_purity" } }),
                    { unit("character_gilded_page", 5, 5, { isolate = "bare", stats = { health = 300 } }) })
                local me, foe = c.units[1], c.units[2]
                if dirty then Status.apply(c, me, "status_root", {}) end
                local before = hp(foe)
                assert(Fixture.strike(c, me, foe, "weapon_horn_of_purity"), "the horn strikes")
                assert(Status.has(foe, "status_blighted"), "and Blights")
                return before - hp(foe)
            end
            local clean, dirty = swing(false), swing(true)
            assert(clean - dirty == 3, "clean hands strike for 3 more (" .. clean .. " vs " .. dirty .. ")")
            local def = Item.defs["weapon_horn_of_purity"]
            assert(Item.archetype(def) == "dagger" and def.activeAbility.speed <= 2, "a quick dagger")
        end,
    },
    -- ------------------------------------------------------------------------------ the Sphinx
    {
        name = "the Sphinx opens on a riddle, shown on a badge and in the log, and takes no damage unanswered",
        fn = function()
            local c = fight("character_sphinx", 5, 5, walker(5, 6))
            local foe, sph = c.units[1], one(c, "character_sphinx")
            local t = riddleOf(sph)
            assert(t and t.riddle, "a riddle is asked at the bell")
            assert(Status.has(sph, t.riddle.status), "and named on a badge")
            local logged = false
            for _, e in ipairs(c.log or {}) do
                if type(e.text) == "string" and e.text:find(t.riddle.text, 1, true) then logged = true end
            end
            assert(logged, "and in the log")
            assert(hit(c, sph, 30, foe) == 0, "unanswered, it takes nothing")
            assert(hit(c, sph, 30, nil) == 0, "not even from a trap")
        end,
    },
    {
        name = "a met riddle leaves the Sphinx Answered and open until its next turn; a failed one heals it 10%",
        fn = function()
            local c = fight("character_sphinx", 5, 5, walker(5, 6))
            local foe, sph = c.units[1], one(c, "character_sphinx")
            local t = riddleOf(sph)
            setRiddle(t, "stillness")
            Trait.onAnyTurnEnd(c, sph) -- nobody moved: met
            assert(Status.has(sph, PrideElites.ANSWERED), "met, it is Answered")
            assert(hit(c, sph, 30, foe) > 0, "and can be hurt")
            local before = hp(sph)
            setRiddle(t, "fire")
            Trait.onAnyTurnEnd(c, sph) -- nobody struck with fire: failed
            assert(not Status.has(sph, PrideElites.ANSWERED), "failed, the window shuts")
            assert(hp(sph) - before == math.floor(maxHp(sph) * 0.10 + 0.5), "and it heals a tenth")
            assert(hit(c, sph, 30, foe) == 0, "warded again")
            assert(t.riddle and t.riddle.id ~= "fire", "the next riddle is never the one just asked")
        end,
    },
    {
        name = "the five riddles are each answerable off the board: fire, stillness, one striker, distance, two together",
        fn = function()
            local c = fight("character_sphinx", 6, 6, { walker(6, 7), walker(6, 3) })
            local near, far, sph = c.units[1], c.units[2], one(c, "character_sphinx")
            local t = riddleOf(sph)
            local met = {}
            local function riddle(id) for _, r in ipairs(PrideElites.RIDDLES) do if r.id == id then return r end end end
            setRiddle(t, "alone")
            PrideElites.noteCast(c, t, sph, near, { tags = { "fire" } }, { damage = 10 }, sph.x, sph.y)
            met.fire, met.alone = riddle("fire").met(t.record), riddle("alone").met(t.record)
            assert(met.fire, "a fire strike answers Fire")
            assert(met.alone, "one striker answers Alone")
            assert(not riddle("together").met(t.record), "one striker is not Together")
            -- A real bow, loosed from three tiles: a second striker on the same foe, and from afar.
            local bow
            for _, item in ipairs(Character.eachItem(far.char)) do
                if item.type == "weapon" and (item.activeAbility.range or 1) >= 3 then bow = item end
            end
            assert(bow, "the walker carries a bow")
            openTurn(c, far)
            assert(Combat.useItem(c, far, bow, sph.x, sph.y), "the archer looses at the Sphinx")
            assert(riddle("distance").met(t.record), "a strike from 3 tiles answers Distance")
            assert(riddle("together").met(t.record), "two strikers on one foe answer Together")
            assert(not riddle("alone").met(t.record), "and two strikers are no longer Alone")
            assert(riddle("stillness").met(t.record), "nobody has moved yet")
            near.turnStartX, near.turnStartY = near.x, near.y
            near.x = near.x + 1
            PrideElites.noteTurnEnd(t, sph, near)
            assert(not riddle("stillness").met(t.record), "a body that ended its turn elsewhere moved")
            for _, r in ipairs(PrideElites.RIDDLES) do
                assert(Status.defs[r.status], r.id .. " has a badge naming it")
            end
        end,
    },
    {
        name = "the riddles are dealt off the fight's seed, so a repeat visit is asked something else",
        fn = function()
            -- Spread seeds, as a board's real seed is (a mixed hash, never 1, 2, 3): the generator's first draw
            -- off a small seed is tiny for every one of them (Combat.newRandom), which would measure the
            -- seeds rather than the deal.
            local firsts = {}
            for s = 1, 12 do
                local seed = (s * 2654435761) % 2147483647
                local c = fight("character_sphinx", 5, 5, walker(5, 6), nil, seed)
                firsts[riddleOf(one(c, "character_sphinx")).riddle.id] = true
            end
            local n = 0
            for _ in pairs(firsts) do n = n + 1 end
            assert(n >= 2, "twelve fights opened on " .. n .. " riddle(s)")
        end,
    },
    {
        name = "the Sphinx's Riddle asks its bearer's side: met, the bearer is Empowered; it never wards or heals",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 5, 6, { isolate = "mechanics", items = { "utility_sphinxs_riddle" } }),
                { unit("character_gilded_page", 5, 1, { isolate = "bare", stats = { health = 300 } }) })
            local me, foe = c.units[1], c.units[2]
            local t = riddleOf(me)
            assert(t and t.riddle and Status.has(me, t.riddle.status), "it asks at the bell, on a badge")
            setRiddle(t, "stillness")
            Trait.onAnyTurnEnd(c, me)
            assert(Status.has(me, "status_empowered"), "met: Empowered")
            assert(not Status.has(me, PrideElites.ANSWERED), "and nothing about it is a Sphinx's ward")
            assert(hit(c, me, 10, foe) > 0, "its bearer is hurt as anybody is")
            local before = hp(me)
            setRiddle(t, "fire")
            Trait.onAnyTurnEnd(c, me)
            assert(hp(me) == before, "a failed round heals nobody")
        end,
    },
    -- ------------------------------------------------------------------------------ the Phoenix
    {
        name = "the Phoenix felled leaves an Ember on its tile, and breaking the Ember ends it",
        fn = function()
            local c = fight("character_phoenix", 5, 5, walker(5, 7))
            local foe, ph = c.units[1], one(c, "character_phoenix")
            hit(c, ph, 9999, foe)
            assert(not ph.alive and not ph.corpse, "it burns away, leaving no body")
            local ember = one(c, "character_phoenix_ember")
            assert(ember and ember.x == 5 and ember.y == 5, "an Ember on its tile")
            assert(ember.timeless and ember.side == ph.side, "a thing of its side that takes no turns")
            assert(Status.has(ember, "status_rekindling"), "on a clock")
            hit(c, ember, 9999, foe)
            assert(not ember.alive, "the Ember breaks")
            Status.tick(c, 20)
            assert(not one(c, "character_phoenix"), "and nothing rises")
            assert(Combat.aliveCount(c, ph.side) == 0, "the kill-all is won")
        end,
    },
    {
        name = "an Ember left three turns rises as the Phoenix, whole, +3 Damage for every death",
        fn = function()
            local c = fight("character_phoenix", 5, 5, walker(5, 7))
            local foe, ph = c.units[1], one(c, "character_phoenix")
            local base = Combat.flatStat(ph, "damage")
            hit(c, ph, 9999, foe)
            Status.tick(c, 15)
            local again = one(c, "character_phoenix")
            assert(again and again ~= ph, "it rises")
            assert(hp(again) == maxHp(again), "at full health")
            assert(Combat.flatStat(again, "damage") == base + 3, "3 Damage the stronger")
            assert(not one(c, "character_phoenix_ember"), "the Ember is spent")
            hit(c, again, 9999, foe)
            Status.tick(c, 15)
            local third = one(c, "character_phoenix")
            assert(Status.stacksOf(third, "status_reborn") == 2, "twice dead, twice Reborn")
            assert(Combat.flatStat(third, "damage") == base + 6, "6 Damage the stronger")
        end,
    },
    {
        name = "the Phoenix Feather: once a battle, a killing blow leaves its bearer standing at 30%",
        fn = function()
            local c = Fixture.combat(board(),
                unit("character_archer", 5, 6, { isolate = "bare", items = { "utility_phoenix_feather" },
                    stats = { health = 100 } }),
                { unit("character_gilded_page", 5, 1, { isolate = "bare" }) })
            local me = c.units[1]
            hit(c, me, 9999, c.units[2])
            assert(me.alive and hp(me) == 30, "it rises at 30% (" .. hp(me) .. ")")
            hit(c, me, 9999, c.units[2])
            assert(not me.alive, "and only once")
        end,
    },
    -- ------------------------------------------------------------------------------ the Tower-Giant
    {
        name = "the Tower-Giant gains Ambition at the end of every turn, and its fall reaches with it",
        fn = function()
            local c = fight("character_tower_giant", 5, 5, walker(1, 1))
            local g = one(c, "character_tower_giant")
            for _ = 1, 4 do Trait.onAnyTurnEnd(c, g) end
            assert(Status.stacksOf(g, "status_ambition") == 4, "a stack a turn")
            local r, d = PrideElites.crashOf(0)
            assert(r == 0 and d == 0, "no ambition, no fall")
            r, d = PrideElites.crashOf(3)
            assert(r == 2 and d == 18, "3 stacks: 2 tiles, 18")
            r, d = PrideElites.crashOf(6)
            assert(r == 3 and d == 36, "6 stacks: 3 tiles, 36")
        end,
    },
    {
        name = "the Tower-Giant crashes on everything within 1 + Ambition/3 when it falls, and on nothing past it",
        fn = function()
            local c = fight("character_tower_giant", 5, 5, { walker(5, 7), walker(5, 8), walker(1, 1) })
            local inside, outside, killer = c.units[1], c.units[2], c.units[3]
            local g = one(c, "character_tower_giant")
            Status.apply(c, g, "status_ambition", { magnitude = 4 }) -- 2 tiles, 24
            local a, b = hp(inside), hp(outside)
            hit(c, g, 9999, killer)
            assert(not g.alive, "it falls")
            assert(hp(inside) < a, "two tiles off, the tower lands on you")
            assert(hp(outside) == b, "three tiles off, it does not")

            local c2 = fight("character_tower_giant", 5, 5, { walker(5, 6) })
            local beside = c2.units[1]
            local before = hp(beside)
            hit(c2, one(c2, "character_tower_giant"), 9999, nil)
            assert(hp(beside) == before, "felled before its first turn's end, it falls on nobody")
        end,
    },
    {
        name = "the Babel Maul gains Ambition each turn, and its next hit consumes every stack for +3 damage each",
        fn = function()
            local function swing(stacks)
                local c = Fixture.combat(board(),
                    unit("character_archer", 5, 6, { isolate = "bare", items = { "weapon_babel_maul" } }),
                    { unit("character_gilded_page", 5, 5, { isolate = "bare", stats = { health = 300 } }) })
                local me, foe = c.units[1], c.units[2]
                for _ = 1, stacks do Trait.onAnyTurnEnd(c, me) end
                assert(Status.stacksOf(me, "status_ambition") == stacks, "a stack a turn")
                local before = hp(foe)
                assert(Fixture.strike(c, me, foe, "weapon_babel_maul"), "the maul swings")
                -- The hit consumed them all, and the end of the turn it was struck on laid the next one.
                assert(Status.stacksOf(me, "status_ambition") == 1, "the hit consumes them all; the turn's end adds one")
                return before - hp(foe)
            end
            local fresh, built = swing(0), swing(3)
            assert(built - fresh == 9, "three stacks, +9 (" .. built .. " vs " .. fresh .. ")")
            local def = Item.defs["weapon_babel_maul"]
            assert(Item.archetype(def) == "hammer" and def.hands == 2 and def.activeAbility.speed == 7,
                "a ponderous two-handed hammer")
        end,
    },
    -- ------------------------------------------------------------------------------ the whole fights
    {
        -- Held to a DECISION, not an outcome, as the Labyrinth's case is: a ward that answers to a riddle, an
        -- Ember that re-seats its body and a fall that lands on its killers are three new ways for a fight to
        -- loop or stall the planner, and this is the case that says none of them does.
        name = "each of the four fights plays out to a decision with a real company, and nothing in it stalls",
        fn = function()
            local EncounterBattle = require("models.encounter_battle")
            local Autobattle = require("models.autobattle")
            for id in pairs(FIGHTS) do
                local roster = {}
                for i = 1, 4 do roster[i] = Character.instantiate("character_knight") end
                local built = EncounterBattle.build({
                    encounter = { kind = "elite", id = id, tier = 3 },
                    party = roster, biome = "spire", seed = 20260930,
                })
                assert(built.combat, id .. " builds")
                EncounterBattle.autoDeploy(built.combat, built.arena, roster)
                Combat.openBattle(built.combat)
                local result, turns = Autobattle.run(built.combat)
                assert(result == "win" or result == "loss", id .. ": a decision in " .. tostring(turns)
                    .. " turns, got " .. tostring(result))
            end
        end,
    },
}
