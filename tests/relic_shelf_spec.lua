-- THE 2026-10-24 SHELF: five trades and five inversions, driven through real combat.
--
-- The sibling of tests/relic_rules_spec.lua, and built the same way: stamp the relic bag on the party
-- unit as states/battle.lua does at setup, re-fold the passives, apply the structural rules, then ask
-- the board what the player would see -- a reach, a budget, a ceiling, a body still standing at 0.
-- Every bag is built through the real Relic functions off a real run state, so a relic re-scaled in data
-- moves these cases with it.

local Combat = require("models.combat")
local Relic = require("models.relic")
local Status = require("models.status")
local Item = require("models.item")
local Injury = require("models.injury")
local Descent = require("models.descent")
local Fixture = require("tests.support.fixture")

local NEW = {
    trades = { "relic_heavy_pack", "relic_bare_feet", "relic_lit_fuse", "relic_tallow_and_wick",
               "relic_narrow_road" },
    inversions = { "relic_dead_mans_hand", "relic_mirror_tithe", "relic_iron_stomach",
                   "relic_long_shadow", "relic_reversed_hourglass" },
}

local function bagFor(ids)
    local s = Relic.newState()
    for _, id in ipairs(ids) do Relic.grant(s, id) end
    return {
        bonus = Relic.statBonus(s),
        maxBonus = Relic.maxBonus(s),
        resist = Relic.resistBonus(s),
        parts = Relic.bonusParts(s),
        rules = Relic.resolvedRules(s),
    }, s
end

-- A fight with the party carrying `ids`. `opts.party` is a list of extra party spawns; `opts.foe`
-- overrides the foe's spawn; `opts.objective` is handed to the map.
local function fightWith(ids, opts)
    opts = opts or {}
    local map = Fixture.new(12, 12, { objective = opts.objective })
    local hero = Fixture.unit(opts.hero or "character_knight", 2, 2,
        { isolate = "bare", items = opts.items or { "weapon_iron_sword" }, stats = opts.stats })
    local party = { hero }
    for _, extra in ipairs(opts.party or {}) do party[#party + 1] = extra end
    local foe = opts.foe or Fixture.unit("character_bandit", opts.fx or 2, opts.fy or 4,
        { isolate = "bare", stats = { defense = 0, magicDefense = 0, health = 200 } })
    local combat = Fixture.combat(map, party, { foe })
    local bag = bagFor(ids)
    for _, u in ipairs(combat.units) do
        if u.side == "party" then u.relicBonus = bag end
    end
    Combat.applyPassives(combat)
    Combat.applyUnitRules(combat)
    return combat, hero, foe, bag
end

local function unitOf(combat, spawn)
    for _, u in ipairs(combat.units) do if u.char == spawn.char then return u end end
end

local function partyUnit(combat)
    for _, u in ipairs(combat.units) do if u.side == "party" then return u end end
end

return {
    {
        name = "the ten new relics are on the shelf, on their rungs, with marks nobody else wears",
        fn = function()
            local marks = {}
            for id, def in pairs(Relic.defs) do
                assert(def.mark, id .. " has no mark")
                assert(not marks[def.mark], id .. " shares its mark '" .. def.mark .. "' with " .. tostring(marks[def.mark]))
                marks[def.mark] = id
            end
            for _, id in ipairs(NEW.trades) do
                assert(Relic.defs[id] and Relic.defs[id].tier == "uncommon", id .. " is an uncommon trade")
            end
            for _, id in ipairs(NEW.inversions) do
                assert(Relic.defs[id] and Relic.defs[id].tier == "rare", id .. " is a rare inversion")
            end
            -- ...and none of them leaked onto the item shelf: a relic is a relic.
            for _, id in ipairs(NEW.trades) do assert(not Item.defs[id], id .. " is not an item") end
            for _, id in ipairs(NEW.inversions) do assert(not Item.defs[id], id .. " is not an item") end
        end,
    },
    {
        name = "every rule a relic declares is a rule the engine names",
        fn = function()
            local known = {}
            for _, n in ipairs(Item.RULE_NAMES) do known[n] = true end
            for id, def in pairs(Relic.defs) do
                for name in pairs(def.rules or {}) do
                    assert(known[name], id .. " declares rule '" .. name .. "', which is not on Item.RULE_NAMES")
                end
            end
        end,
    },
    {
        -- T1: +2/+2 armour (+1 each per copy) for one step of walk, paid once.
        name = "The Heavy Pack buys both armours with one step of walk, paid once",
        fn = function()
            local plain = fightWith({})
            local one = fightWith({ "relic_heavy_pack" })
            local two = fightWith({ "relic_heavy_pack", "relic_heavy_pack" })
            local p, a, b = partyUnit(plain), partyUnit(one), partyUnit(two)
            assert(Combat.flatStat(a, "defense") == Combat.flatStat(p, "defense") + 2, "+2 defense")
            assert(Combat.flatStat(a, "magicDefense") == Combat.flatStat(p, "magicDefense") + 2, "+2 magic defense")
            assert(Combat.flatStat(b, "defense") == Combat.flatStat(p, "defense") + 3, "a second copy adds 1")
            assert(Combat.moveBudget(a) == Combat.moveBudget(p) - 1, "one step off the walk")
            assert(Combat.moveBudget(b) == Combat.moveBudget(p) - 1, "and only one, however many are held")
        end,
    },
    {
        -- T2: the negative half of a trade has to fold through the same flatStat a coat's does.
        name = "The Bare Feet adds walk (capped at +3) and takes defense, and a negative bonus folds cleanly",
        fn = function()
            local plain = fightWith({})
            local one = fightWith({ "relic_bare_feet" })
            local p, a = partyUnit(plain), partyUnit(one)
            assert(Combat.moveBudget(a) == Combat.moveBudget(p) + 1, "+1 movement")
            assert(Combat.flatStat(a, "defense") == Combat.flatStat(p, "defense") - 2,
                "-2 defense lands in flatStat like any bonus; got " .. Combat.flatStat(a, "defense")
                .. " vs " .. Combat.flatStat(p, "defense"))

            local s = Relic.newState()
            for _ = 1, 4 do Relic.grant(s, "relic_bare_feet") end
            local bag = Relic.statBonus(s)
            assert(bag.movement == 3, "the walk is capped at +3 at four copies; got " .. tostring(bag.movement))
            assert(bag.defense == -5, "the price keeps climbing: -2, -1 per copy; got " .. tostring(bag.defense))
            assert(Relic.blurbAt("relic_bare_feet", 4):find("+3", 1, true), "and the card quotes the capped figure")
            -- The breakdown names the relic with the same capped figure the bag carries.
            local rows = Relic.bonusBreakdown(s, "movement")
            assert(#rows == 1 and rows[1].value == 3, "the breakdown row is capped too")
        end,
    },
    {
        -- T3: the opening boon, on the whole deployed company, and the Mark works on its own side.
        name = "The Lit Fuse opens the whole company Hasted and Marked, for the same turns",
        fn = function()
            local _, s = bagFor({ "relic_lit_fuse" })
            local a, b = { id = "a" }, { id = "b" }
            local ctx = Relic.dispatch("battleStart", { state = s, party = { a, b } })
            local seen = {}
            for _, boon in ipairs(Relic.openingBoons(ctx)) do
                seen[boon.char.id .. ":" .. boon.id] = boon.opts.duration
            end
            for _, who in ipairs({ "a", "b" }) do
                assert(seen[who .. ":status_hasted"] == 10, who .. " opens Hasted for 2 turns (10 ticks)")
                assert(seen[who .. ":status_mark"] == 10, who .. " opens Marked for as long")
            end
            Relic.grant(s, "relic_lit_fuse")
            local deeper = Relic.dispatch("battleStart", { state = s, party = { a } })
            assert(Relic.openingBoons(deeper)[1].opts.duration == 15, "a second copy is a turn longer")

            -- The Mark is an ordinary debuff, and it lands on the company's own side like anywhere else.
            local c = fightWith({})
            local u = partyUnit(c)
            local before = Combat.flatStat(u, "defense")
            assert(Status.apply(c, u, "status_mark", { duration = 10 }), "the Mark lands on a party body")
            assert(Combat.flatStat(u, "defense") == before - 5, "and cuts its defense")
        end,
    },
    {
        -- T4: a share off the health ceiling (a rule), a flat raise on the mana one (a bag).
        name = "Tallow and Wick deepens mana and takes a tenth of the health ceiling",
        fn = function()
            local plain = fightWith({}, { stats = { health = 100, mana = 20 } })
            local one = fightWith({ "relic_tallow_and_wick" }, { stats = { health = 100, mana = 20 } })
            local two = fightWith({ "relic_tallow_and_wick", "relic_tallow_and_wick" },
                { stats = { health = 100, mana = 20 } })
            local p, a, b = partyUnit(plain), partyUnit(one), partyUnit(two)
            assert(Combat.unreservedMax(a.char, "mana") == Combat.unreservedMax(p.char, "mana") + 6, "+6 mana")
            assert(Combat.unreservedMax(b.char, "mana") == Combat.unreservedMax(p.char, "mana") + 9, "+3 per copy")
            assert(Combat.unreservedMax(a.char, "health") == 90, "a tenth off a 100 ceiling")
            assert(Combat.unreservedMax(b.char, "health") == 90, "paid once, however many are held")
            assert(a.char.stats.health.current == 90, "and a body walking in full is brought under it at the bell")
        end,
    },
    {
        -- T5: the signed reach, its floors, and the sum that lets it meet the Far Mark.
        name = "The Narrow Road shortens every ranged reach by one, never under 1 or the dead zone",
        fn = function()
            local plain = fightWith({})
            local armed = fightWith({ "relic_narrow_road" })
            local p, a = partyUnit(plain), partyUnit(armed)
            assert(Combat.abilityRange(armed, a, { range = 3 }) == Combat.abilityRange(plain, p, { range = 3 }) - 1,
                "a reach of 3 becomes 2")
            assert(Combat.abilityRange(armed, a, { range = 1 }) == 1, "a sword's reach is untouched")
            assert(Combat.abilityRange(armed, a, { range = 2, minRange = 2 }) == 2,
                "a bow whose dead zone begins at 2 keeps its band rather than losing the shot")
            assert(Combat.flatStat(a, "skill") == Combat.flatStat(p, "skill") + 3, "+3 skill")

            -- THE SUM. Both the item merge and the relic resolve add reaches rather than first-wins.
            local both = bagFor({ "relic_narrow_road", "relic_far_mark" })
            assert(both.rules.abilityRange == 0, "the Narrow Road (-1) and the Far Mark (+1) net out; got "
                .. tostring(both.rules.abilityRange))
            local merged = Item.mergeRules({ abilityRange = 3 }, { abilityRange = -1 })
            assert(merged.abilityRange == 2, "Item.mergeRules sums a reach too")
        end,
    },
    {
        -- I1: borrowed time, a blow that changes nothing, a refused heal, the fall, and the debt.
        name = "The Dead Man's Hand holds a felled body up for two of its turns, then charges two injuries",
        fn = function()
            local c, h, f = fightWith({ "relic_dead_mans_hand" }, { stats = { health = 50 } })
            local hero, foe = unitOf(c, h), unitOf(c, f)
            Combat.dealFlatDamage(c, hero, 999, { "slash" }, "test", foe, { raw = true })
            assert(hero.alive, "a lethal blow does not fell the body")
            assert(hero.char.stats.health.current == 0, "it stands at 0")
            assert(Status.has(hero, "status_dead_mans_hand"), "and wears the badge")
            assert(Status.untargetable(hero, c), "foes do not aim at a body their blows can no longer move")
            Combat.dealFlatDamage(c, hero, 999, { "slash" }, "test", foe, { raw = true })
            assert(hero.alive and hero.borrowedTime == 2, "a second blow changes nothing")
            assert(Combat.applyHeal(c, hero, 30) == 0 and hero.char.stats.health.current == 0,
                "no heal reaches it")
            assert(Combat.restoreResource(hero.char, "health", 30) == 0, "not by the side door either")

            Status.onTurnEnd(c, hero)
            assert(hero.alive and hero.borrowedTime == 1, "one of its turns is spent")
            Status.onTurnEnd(c, hero)
            assert(not hero.alive, "the second turn's end is the fall")
            assert(hero.incapacitated, "it falls like any body: down, and revivable")
            assert(hero.char.deadMansDebt == 1, "and owes the extra injury")

            local p = Descent.newProfile({ hero.char })
            Injury.inflict(p, { hero.char })
            assert(#Injury.list(p, hero.char.id) == 2, "the fall is charged two injuries, not one")
            assert(hero.char.deadMansDebt == nil, "and the debt is spent")
        end,
    },
    {
        name = "The Dead Man's Hand: a body felled on its own turn keeps that turn, and a won fight still calls it in",
        fn = function()
            local c, h, f = fightWith({ "relic_dead_mans_hand" }, { stats = { health = 50 } })
            local hero, foe = unitOf(c, h), unitOf(c, f)
            Fixture.openTurn(c, hero)
            Combat.dealFlatDamage(c, hero, 999, { "slash" }, "test", foe, { raw = true })
            Status.onTurnEnd(c, hero)
            assert(hero.borrowedTime == 2, "the turn it was felled on is not counted against it")

            -- The fight ends with the body still on its feet: it is carried out as fallen, with the debt.
            local carried = Combat.reviveFallenParty(c)
            local found = false
            for _, ch in ipairs(carried) do if ch == hero.char then found = true end end
            assert(found, "a won fight carries the borrowing body out as one of the fallen")
            assert(hero.char.deadMansDebt == 1, "owing the second injury")
        end,
    },
    {
        name = "The Dead Man's Hand never holds up a body the objective names as its charge",
        fn = function()
            local c, h, f = fightWith({ "relic_dead_mans_hand" }, { stats = { health = 50 } })
            local u, foe = unitOf(c, h), unitOf(c, f)
            c.objective = c.objective or {}
            c.objective.protect = u.char.id
            assert(not Combat.borrowsTime(c, u), "the protectee is excluded")
            Combat.dealFlatDamage(c, u, 999, { "slash" }, "test", foe, { raw = true })
            assert(not u.alive, "and falls on the blow, as the objective needs it to")
        end,
    },
    {
        -- I2: half the mend, and the strike on the nearest foe for what the full heal would have restored.
        name = "The Mirror Tithe halves the company's heals and strikes the nearest foe for the full heal",
        fn = function()
            local function cast(ids)
                local ally = Fixture.unit("character_archer", 3, 2, { isolate = "bare", stats = { health = 300 } })
                local c, h, f = fightWith(ids, { items = { "ability_heal" }, party = { ally },
                    stats = { mana = 100 }, fx = 6, fy = 6 })
                local healer, a, foe = unitOf(c, h), unitOf(c, ally), unitOf(c, f)
                a.char.stats.health.current = 50
                local before = foe.char.stats.health.current
                assert(Fixture.strike(c, healer, a, "ability_heal"), "the heal is cast")
                return a.char.stats.health.current - 50, before - foe.char.stats.health.current
            end
            local full, untouched = cast({})
            assert(full > 0 and untouched == 0, "a plain heal mends and strikes nobody")
            local half, struck = cast({ "relic_mirror_tithe" })
            assert(half == math.ceil(full / 2), "the mend lands at half; " .. full .. " -> " .. half)
            assert(struck == full, "and the nearest foe takes the full heal; expected " .. full .. " got " .. struck)
            local _, harder = cast({ "relic_mirror_tithe", "relic_mirror_tithe" })
            assert(harder == math.floor(full * 1.5), "a second copy strikes for 150%")
        end,
    },
    {
        name = "The Mirror Tithe strikes nothing for a heal thrown at a full bar",
        fn = function()
            local c, h, f = fightWith({ "relic_mirror_tithe" }, { fx = 6, fy = 6 })
            local healer, foe = unitOf(c, h), unitOf(c, f)
            local before = foe.char.stats.health.current
            Combat.mirrorTithe(c, healer, healer, 40, 1)
            assert(foe.char.stats.health.current == before, "no room to heal, no tithe to pay")
        end,
    },
    {
        -- I3: the flask goes back in the bag, the drinker pays, once per turn.
        name = "The Iron Stomach keeps a draught, charges the drinker 15% of its ceiling, once per turn",
        fn = function()
            local c, h = fightWith({ "relic_iron_stomach" },
                { items = { "consumable_healing_potion" }, stats = { health = 100 } })
            local hero = unitOf(c, h)
            local flask = Fixture.itemNamed(hero.char, "consumable_healing_potion")
            flask.quantity = 3
            hero.char.stats.health.current = 20
            assert(Fixture.strike(c, hero, hero, flask), "the draught is drunk")
            assert(flask.quantity == 3, "and not used up")
            local healed = hero.char.stats.health.current
            -- Same turn: the second one is spent as ever (turn flags clear only when a turn starts).
            hero.char.stats.health.current = 20
            assert(Fixture.strike(c, hero, hero, flask), "a second draught the same turn")
            assert(flask.quantity == 2, "is spent")
            assert(hero.char.stats.health.current == healed + 15, "and costs no health; it is the toll that differs")

            local s = Relic.newState()
            for _ = 1, 5 do Relic.grant(s, "relic_iron_stomach") end
            assert(Relic.resolvedRules(s).ironStomach == 5, "the toll falls 3 a copy and stops at 5%")
            assert(Relic.costAt("relic_iron_stomach", 2):find("12%", 1, true), "the card quotes the stack's toll")
        end,
    },
    {
        -- I4: the horizon, both ways, at the door the planner and the model both ask.
        name = "The Long Shadow: nothing aims at the company from beyond 3 tiles, and it reaches no further",
        fn = function()
            local function foeBow()
                return Fixture.unit("character_bandit", 2, 6, { isolate = "bare",
                    items = { "weapon_heartstring_longbow" }, stats = { health = 200 } })
            end
            local plain, ph, pf = fightWith({}, { foe = foeBow() })
            local armed, ah, af = fightWith({ "relic_long_shadow" }, { foe = foeBow() })
            local function listed(c, foe, hero)
                local bow = Fixture.itemNamed(foe.char, "weapon_heartstring_longbow")
                for _, t in ipairs(Combat.abilityTargets(c, unitOf(c, foe), bow)) do
                    if t == unitOf(c, hero) or t.unit == unitOf(c, hero) then return true end
                end
                return false
            end
            assert(listed(plain, pf, ph), "an archer four tiles off can aim at an ordinary company")
            assert(not listed(armed, af, ah), "but not at one under the Long Shadow")
            local ok = Fixture.strike(armed, unitOf(armed, af), unitOf(armed, ah), "weapon_heartstring_longbow")
            assert(not ok, "and the model refuses the shot outright")
            local hero = unitOf(armed, ah)
            assert(not Status.concealedAt(hero, armed, 3), "three tiles is inside the horizon")
            assert(Combat.abilityRange(armed, hero, { range = 6 }) == 3, "the company's own reach stops at 3")
            assert(Combat.flatStat(hero, "defense") == Combat.flatStat(unitOf(plain, ph), "defense") + 2, "+2 defense")
        end,
    },
    {
        -- I5: one way for the company's own marks on foes, twice as fast for what it wears.
        name = "The Reversed Hourglass freezes what the company lays on foes and hurries what it wears",
        fn = function()
            local c, h, f = fightWith({ "relic_reversed_hourglass" })
            local hero, foe = unitOf(c, h), unitOf(c, f)
            Status.apply(c, foe, "status_burn", { applier = hero, duration = 6 })
            Status.apply(c, foe, "status_stun", { applier = hero, duration = 6 })
            Status.apply(c, hero, "status_hasted", { duration = 20 })
            Status.tick(c, 5)
            assert(Status.get(foe, "status_burn").remaining == 6, "the company's Burn on a foe does not run down")
            assert(Status.get(foe, "status_stun") == nil or Status.get(foe, "status_stun").remaining < 6,
                "hard control still wears off a foe")
            assert(Status.get(hero, "status_hasted").remaining == 10, "the company's own Haste runs at 2x")

            -- A plain company is untouched.
            local c2, h2, f2 = fightWith({})
            local hero2, foe2 = unitOf(c2, h2), unitOf(c2, f2)
            Status.apply(c2, foe2, "status_burn", { applier = hero2, duration = 6 })
            Status.tick(c2, 5)
            assert(Status.get(foe2, "status_burn").remaining == 1, "without the relic a Burn runs down as ever")
        end,
    },
    {
        -- R1: the plain words, on the card and before the bell.
        name = "The Rooted Oath says plainly what it stops, on the card and on a ground fight's deploy screen",
        fn = function()
            local blurb = Relic.blurbAt("relic_rooted_oath", 1)
            assert(blurb:find("The company cannot walk. Reach, escort and escape fights need abilities that move.", 1, true),
                "the card says it in the author's words: " .. blurb)
            local _, s = bagFor({ "relic_rooted_oath" })
            local player = { descentRun = { relicState = s } }
            assert(Relic.deployNotice(player, { objective = { type = "reach" } }) == Relic.ROOTED_NOTICE,
                "a reach fight's deploy screen says it")
            assert(Relic.deployNotice(player, { objective = { type = "killAll" } }) == nil,
                "a kill-all fight says nothing")
            local _, empty = bagFor({})
            assert(Relic.deployNotice({ descentRun = { relicState = empty } }, { objective = { type = "reach" } }) == nil,
                "and nor does a company not holding the Oath")
        end,
    },
}
