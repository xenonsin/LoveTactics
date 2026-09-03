-- THE RARE TIER'S INVERSIONS, driven through real combat.
--
-- Separate from tests/relic_spec.lua on purpose. That file tests the REGISTRY -- what is held, what a
-- pool draws, what a magnitude ladders to -- and needs no board. This one tests that each rule actually
-- reaches the game: a declared rule nobody consumes is the exact failure mode this whole tier was at
-- risk of (the rules shipped declared-but-inert once already), and a spec that only asserted the data
-- would have gone green over it. So every case here builds a fight and asks the board.
--
-- The pattern throughout: stamp `relicBonus` on the party unit the way states/battle.lua does at setup,
-- re-fold the passives, and then measure the thing the player would see -- a reach, a budget, a pool, a
-- number of damage. `Relic.resolvedRules` is used to build the bag rather than hand-written literals, so
-- a relic re-tiered or re-scaled in data moves these cases with it instead of leaving them asserting a
-- number the shelf no longer has.

local Combat = require("models.combat")
local Relic = require("models.relic")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

-- The bag battle setup stamps, built from a real run state so the magnitudes are the shipped ones.
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

-- A one-on-one fight with the party unit carrying `ids`. Mirrors states/battle.lua's setup order:
-- stamp the bag, re-fold the passives, then apply the structural rules.
local function fightWith(ids, opts)
    opts = opts or {}
    local map = Fixture.new(10, 10)
    local hero = Fixture.unit(opts.hero or "character_knight", 2, 2,
        { isolate = "bare", items = opts.items or { "weapon_iron_sword" } })
    local foe = Fixture.unit("character_bandit", opts.fx or 2, opts.fy or 4,
        { isolate = "bare", stats = { defense = 0, health = 200 } })
    local combat = Fixture.combat(map, hero, foe)
    local bag = bagFor(ids)
    for _, u in ipairs(combat.units) do
        if u.side == "party" then u.relicBonus = bag end
    end
    Combat.applyPassives(combat)
    Combat.applyRelicRules(combat)
    return combat, hero, foe, bag
end

local function partyUnit(combat)
    for _, u in ipairs(combat.units) do if u.side == "party" then return u end end
end

return {
    {
        -- THE FAR MARK (uncommon): +1 reach on everything, -3 against anything in contact.
        name = "The Far Mark lengthens every reach and charges for contact",
        fn = function()
            local plain = select(1, fightWith({}))
            local armed = select(1, fightWith({ "relic_far_mark" }))
            local pu, au = partyUnit(plain), partyUnit(armed)
            local ab = { range = 3 }
            local before = Combat.abilityRange(plain, pu, ab)
            local after = Combat.abilityRange(armed, au, ab)
            assert(after == before + 1, "one Far Mark buys a tile of reach; " .. before .. " -> " .. after)

            -- ...and the contact penalty comes off a blow thrown at an adjacent body, not a distant one.
            local far = select(2, (function()
                local c, h, f = fightWith({ "relic_far_mark" }, { fx = 2, fy = 5 })
                return c, Combat.computeDamage(c, partyUnit(c), f, Fixture.itemNamed(h.char, "weapon_iron_sword"))
            end)())
            local near = select(2, (function()
                local c, h, f = fightWith({ "relic_far_mark" }, { fx = 2, fy = 3 })
                return c, Combat.computeDamage(c, partyUnit(c), f, Fixture.itemNamed(h.char, "weapon_iron_sword"))
            end)())
            assert(near < far, "a blow in contact is worth less than the same blow at range; "
                .. near .. " vs " .. far)
        end,
    },
    {
        -- THE ROOTED OATH (rare): the company cannot move; every ability reaches further and hits harder.
        name = "The Rooted Oath roots the company and pays for it in reach and power",
        fn = function()
            local plain, ph = fightWith({})
            local armed = fightWith({ "relic_rooted_oath" })
            local pu, au = partyUnit(plain), partyUnit(armed)
            assert(Combat.moveBudget(pu) > 0, "an ordinary company can walk")
            assert(Combat.moveBudget(au) == 0, "a rooted one cannot")
            local ab = { range = 2 }
            assert(Combat.abilityRange(armed, au, ab) == Combat.abilityRange(plain, pu, ab) + 3,
                "and it buys three tiles of reach for the rooting")
        end,
    },
    {
        -- THE WHETTED VOW (rare): x2 damage, half the maximum health. Both halves ladder.
        name = "The Whetted Vow doubles the blow and halves the body, and deepens both",
        fn = function()
            local plain, ph, pf = fightWith({})
            local one, oh, of = fightWith({ "relic_whetted_vow" })
            local two = fightWith({ "relic_whetted_vow", "relic_whetted_vow" })

            local base = Combat.unreservedMax(partyUnit(plain).char, "health")
            local half = Combat.unreservedMax(partyUnit(one).char, "health")
            local third = Combat.unreservedMax(partyUnit(two).char, "health")
            assert(half == math.floor(base / 2), "one copy halves the ceiling; " .. base .. " -> " .. half)
            assert(third == math.floor(base / 3), "two copies take it to a third; got " .. third)

            local sword = Fixture.itemNamed(ph.char, "weapon_iron_sword")
            local flat = Combat.computeDamage(plain, partyUnit(plain), pf, sword)
            local doubled = Combat.computeDamage(one, partyUnit(one), of, Fixture.itemNamed(oh.char, "weapon_iron_sword"))
            assert(doubled > flat * 1.8, "and the blow roughly doubles; " .. flat .. " -> " .. doubled)
        end,
    },
    {
        -- THE HELD BREATH (rare): health pinned at 1, both armours climbing with what is missing.
        name = "The Held Breath pins the pool at 1 and pays in armour for what is missing",
        fn = function()
            local plain = fightWith({})
            local armed = fightWith({ "relic_held_breath" })
            local pu, au = partyUnit(plain), partyUnit(armed)
            assert(au.char.stats.health.current == 1, "the pool is pinned at one")
            local gained = Combat.flatStat(au, "defense") - Combat.flatStat(pu, "defense")
            local missing = Combat.unreservedMax(au.char, "health") - 1
            assert(gained == math.floor(missing * 0.25),
                "armour is a quarter of what is missing; expected " .. math.floor(missing * 0.25)
                .. " got " .. gained)
            assert(Combat.flatStat(au, "magicDefense") > Combat.flatStat(pu, "magicDefense"),
                "and both armours climb, not just the physical one")

            -- IT IS LIVE, not banked at the bell: healing the body back up must give the armour back.
            au.char.stats.health.current = Combat.unreservedMax(au.char, "health")
            assert(Combat.flatStat(au, "defense") == Combat.flatStat(pu, "defense"),
                "a body healed to full is missing nothing, so the relic pays nothing")
        end,
    },
    {
        -- THE YOKED COMPANY (rare): one pool for everyone, and a blow on one is a blow on all.
        name = "The Yoked Company puts the party on one bar, and damage moves all of it",
        fn = function()
            local map = Fixture.new(10, 10)
            local a = Fixture.unit("character_knight", 2, 2, { isolate = "bare", items = { "weapon_iron_sword" } })
            local b = Fixture.unit("character_mage", 3, 2, { isolate = "bare" })
            local foe = Fixture.unit("character_bandit", 2, 5, { isolate = "bare", stats = { health = 200 } })
            local combat = Combat.new(map, { a, b }, { foe })
            local bag = bagFor({ "relic_yoked_company" })
            for _, u in ipairs(combat.units) do if u.side == "party" then u.relicBonus = bag end end
            Combat.applyPassives(combat)
            Combat.applyRelicRules(combat)

            -- The BUILT units, not the descriptors Fixture.unit returns: `sharedPool` is stamped on the
            -- unit, and damage is dealt to a unit.
            local ua, ub
            for _, u in ipairs(combat.units) do
                if u.char == a.char then ua = u elseif u.char == b.char then ub = u end
            end
            local ah, bh = a.char.stats.health, b.char.stats.health
            assert(ah.max == bh.max, "both members hold the same ceiling -- it is one pool")
            assert(ah.current == ah.max and bh.current == bh.max, "and both open it full")
            assert(ua.sharedPool and ub.sharedPool, "both units are yoked")
            local pooled = ah.max

            Combat.dealFlatDamage(combat, ua, 20, { "physical" }, nil, nil)
            assert(ah.current == bh.current, "a blow on one lands on both; " .. ah.current .. " vs " .. bh.current)
            assert(ah.current < pooled, "and it actually came off the pool")
        end,
    },
    {
        -- THE OVERDRAFT (rare): mana stops being the currency; the price is paid in health.
        name = "The Overdraft pays a cast's price in health instead of mana",
        fn = function()
            local combat, hero = fightWith({ "relic_overdraft" })
            local unit = partyUnit(combat)
            local hp, mana = unit.char.stats.health, unit.char.stats.mana
            mana.current = mana.max
            local hp0, mana0 = hp.current, mana.current
            Combat.spendCost(combat, unit, { stat = "mana", amount = 6 })
            assert(mana.current == mana0, "no mana is spent under the Overdraft")
            assert(hp.current == hp0 - 6, "the whole price comes out of health at one copy; "
                .. hp0 .. " -> " .. hp.current)

            -- IT WOUNDS BUT NEVER FELLS. The swap is applied past costBlock (deliberately, so committing
            -- to an action you could just afford is a real risk), so the floor is the only thing standing
            -- between a caster and a silent death that would not even run killUnit.
            hp.current = 4
            Combat.spendCost(combat, unit, { stat = "mana", amount = 40 })
            assert(hp.current == 1, "a ruinous price leaves the caster on one, never at zero; got "
                .. hp.current)
            hp.current = 1
            Combat.spendCost(combat, unit, { stat = "mana", amount = 10 })
            assert(hp.current == 1, "and a caster already on one pays nothing at all")

            -- A second copy makes the swap CHEAPER -- the one rare whose deepening is relief.
            local c2 = fightWith({ "relic_overdraft", "relic_overdraft" })
            local u2 = partyUnit(c2)
            local before = u2.char.stats.health.current
            Combat.spendCost(c2, u2, { stat = "mana", amount = 8 })
            assert(before - u2.char.stats.health.current == 6, "two copies charge three quarters; got "
                .. (before - u2.char.stats.health.current))
        end,
    },
    {
        -- THE QUICK DRAW / THE OVERREACH (uncommon): a flat surcharge on every action's price.
        name = "the surcharge relics tax every action they name, and only that pool",
        fn = function()
            local combat = fightWith({ "relic_quick_draw" })
            local unit = partyUnit(combat)
            local st = unit.char.stats.stamina
            st.current = st.max
            local before = st.current
            Combat.spendCost(combat, unit, { stat = "stamina", amount = 5 })
            assert(before - st.current == 7, "The Quick Draw adds two stamina to a five-cost; got "
                .. (before - st.current))

            local c2 = fightWith({ "relic_overreach" })
            local u2 = partyUnit(c2)
            local mana = u2.char.stats.mana
            mana.current = mana.max
            local m0 = mana.current
            Combat.spendCost(c2, u2, { stat = "mana", amount = 4 })
            assert(m0 - mana.current == 7, "The Overreach adds three mana to a four-cost; got "
                .. (m0 - mana.current))
            -- ...and it does not touch the other pool.
            local s0 = u2.char.stats.stamina.current
            Combat.spendCost(c2, u2, { stat = "stamina", amount = 3 })
            assert(s0 - u2.char.stats.stamina.current == 3, "a mana surcharge leaves stamina alone")
        end,
    },
    {
        -- THE OPEN WOUND (rare): nothing the company wears ever runs out.
        name = "The Open Wound stops every status on the company from expiring",
        fn = function()
            local plain = fightWith({})
            local armed = fightWith({ "relic_open_wound" })
            local pu, au = partyUnit(plain), partyUnit(armed)
            Status.apply(plain, pu, "status_hasted", { duration = 3 })
            Status.apply(armed, au, "status_hasted", { duration = 3 })
            Status.tick(plain, 10)
            Status.tick(armed, 10)
            assert(not Status.has(pu, "status_hasted"), "an ordinary haste runs out")
            assert(Status.has(au, "status_hasted"), "under the Open Wound it does not")

            -- AND THE OTHER HALF OF THE BARGAIN: a curse does not run out either.
            Status.apply(armed, au, "status_burn", { duration = 2 })
            Status.tick(armed, 20)
            assert(Status.has(au, "status_burn"), "so does the burn -- that is the price")

            -- HARD CONTROL IS THE ONE EXEMPTION. A permanent Stun is not a steep price, it is a body
            -- that has stopped being a character -- it could never counter, parry or dodge again and
            -- nothing the player does could lift it. Everything else here is fightable; this is not.
            Status.apply(armed, au, "status_stun", { duration = 3 })
            Status.tick(armed, 20)
            assert(not Status.has(au, "status_stun"), "a disable still runs out under the Open Wound")
            assert(Status.has(au, "status_hasted"), "while everything around it still does not")
        end,
    },
    {
        -- The Rooted Oath stops the company WALKING and nothing else. Pinned because it is an explicit
        -- design expectation rather than an accident of where the check landed: the answer to a rooted
        -- company is to move with abilities (a blink, a charge, a shove), and a future change to
        -- moveBudget or to the blink gate could silently take that away.
        name = "The Rooted Oath blocks the walk, never ability-driven movement",
        fn = function()
            local combat = fightWith({ "relic_rooted_oath" },
                { items = { "weapon_iron_sword", "ability_blink" } })
            local unit = partyUnit(combat)
            assert(Combat.moveBudget(unit) == 0, "the walk is gone")

            -- A blink is offered and lands: it never consults the move budget (it pays its own cost per
            -- jump and reaches its own range instead).
            Fixture.openTurn(combat, unit)
            unit.blinkArmed = true
            assert(Combat.blinkReady(unit), "a rooted unit can still arm its blink")
            local ok = Combat.blink(combat, unit, unit.x + 2, unit.y)
            assert(ok, "and it can take the jump")

            -- Forced movement is likewise untouched -- a shove still moves a rooted body.
            local before = unit.y
            Combat.teleportUnit(combat, unit, unit.x, unit.y + 1)
            assert(unit.y ~= before, "and something else can still move it")
        end,
    },
    {
        -- THE LONG WAIT (rare): a burst of actions against a turn that costs a multiple of the timeline.
        -- Authored in INITIATIVE because there are no rounds here. Both halves are pinned: the actions
        -- ladder with copies, the multiplier does not -- which is what makes a second copy a net gain
        -- rather than re-buying the same wash.
        name = "The Long Wait grants a burst, and the timeline charges a stated multiple",
        fn = function()
            -- Combat.startTurn opens the turn for whoever the timeline says is up, so put the company
            -- there: lowest initiative acts next.
            local function openPartyTurn(combat)
                local unit = partyUnit(combat)
                for _, u in ipairs(combat.units) do u.initiative = (u == unit) and 0 or 50 end
                combat.turn = nil
                Combat.startTurn(combat)
                return unit
            end

            local combat = fightWith({ "relic_long_wait" })
            local unit = openPartyTurn(combat)
            assert((unit.extraActions or 0) == 1,
                "one copy is two actions in the turn, so one extra; got " .. tostring(unit.extraActions))

            local c2 = fightWith({ "relic_long_wait", "relic_long_wait" })
            local u2 = openPartyTurn(c2)
            assert((u2.extraActions or 0) == 2, "two copies is three actions; got " .. tostring(u2.extraActions))

            -- ...and an ordinary company gets none, so the grant is the relic and not the turn.
            local plain = fightWith({})
            assert((openPartyTurn(plain).extraActions or 0) == 0, "no relic, no burst")

            -- THE PRICE IS THE STATED MULTIPLE, not whatever the extra actions happened to bank. Run a
            -- whole turn out -- one action, then the surged one, then the settle -- and compare the
            -- initiative charged against an ordinary company doing the same thing once.
            -- Combat.focus is the cheapest public path that settles through endTurn (Combat.wait has its
            -- own settle and is deliberately NOT multiplied -- see endTurn). The burst re-opens the turn,
            -- so keep acting until it really closes.
            local function turnCost(c)
                local u = openPartyTurn(c)
                local before = u.initiative
                for _ = 1, 8 do
                    if not c.turn then break end
                    Combat.focus(c, u)
                end
                return u.initiative - before
            end
            local plainCost = turnCost(fightWith({}))
            local waitCost = turnCost(fightWith({ "relic_long_wait" }))
            assert(waitCost == plainCost * 2,
                "one copy costs exactly double a plain turn; " .. plainCost .. " -> " .. waitCost)

            -- ...and the SECOND copy buys a third action without raising that price, which is the whole
            -- reason the multiplier is flat: it is the rung where the relic stops being a wash.
            local deepCost = turnCost(fightWith({ "relic_long_wait", "relic_long_wait" }))
            assert(deepCost == plainCost * 2,
                "a second copy does not re-buy the price; " .. deepCost .. " vs " .. (plainCost * 2))
        end,
    },
    {
        -- THE UNPAID TITHE (rare): the company recovers nothing between fights.
        name = "The Unpaid Tithe gags every restore and multiplies the blow",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_unpaid_tithe")
            Relic.grant(s, "relic_deep_larder") -- the relic it is meant to silence
            local hurt = { id = "a", name = "a", stats = { health = { current = 10, max = 60 } } }
            local ctx = {
                player = { party = { hurt }, gold = 0 }, party = { hurt }, state = s,
                cell = { x = 1, y = 1 },
            }
            Relic.dispatch("encounterCleared", ctx)
            assert(hurt.stats.health.current == 10,
                "the larder pays nothing under the tithe; got " .. hurt.stats.health.current)

            -- ...and without the tithe the same larder does pay, so the gag is the relic and not a bug.
            local s2 = Relic.newState()
            Relic.grant(s2, "relic_deep_larder")
            local ok = { id = "b", name = "b", stats = { health = { current = 10, max = 60 } } }
            Relic.dispatch("encounterCleared", {
                player = { party = { ok }, gold = 0 }, party = { ok }, state = s2, cell = { x = 1, y = 1 },
            })
            assert(ok.stats.health.current == 16, "and it pays 6 when nothing is gagging it")

            -- The damage half, on the board.
            local plain, ph, pf = fightWith({})
            local armed, ah, af = fightWith({ "relic_unpaid_tithe" })
            local flat = Combat.computeDamage(plain, partyUnit(plain), pf, Fixture.itemNamed(ph.char, "weapon_iron_sword"))
            local more = Combat.computeDamage(armed, partyUnit(armed), af, Fixture.itemNamed(ah.char, "weapon_iron_sword"))
            assert(more > flat, "and the company hits harder for it; " .. flat .. " -> " .. more)
        end,
    },
    {
        -- Two multipliers COMPOSE, because each is a separate bargain the player made.
        name = "two damage-multiplying relics multiply together",
        fn = function()
            local one = Relic.resolvedRules((function()
                local s = Relic.newState(); Relic.grant(s, "relic_unpaid_tithe"); return s
            end)())
            local both = Relic.resolvedRules((function()
                local s = Relic.newState()
                Relic.grant(s, "relic_unpaid_tithe")
                Relic.grant(s, "relic_rooted_oath")
                return s
            end)())
            assert(both.damageMultiplier > one.damageMultiplier,
                "holding both is worth more than holding either")
            assert(math.abs(both.damageMultiplier - 1.5 * 1.5) < 0.001,
                "and they multiply rather than replacing; got " .. both.damageMultiplier)
        end,
    },
    {
        -- Every rule a relic declares has to be READ by something. This is the check that would have
        -- caught the whole tier shipping declared-but-inert, and it is written as a source scan for the
        -- same reason the content report is: a rule consumed nowhere is invisible to any data assertion.
        name = "every rule a relic declares is consumed somewhere in the tree",
        fn = function()
            local names = {}
            for _, def in pairs(Relic.defs) do
                for name in pairs(def.rules or {}) do names[name] = true end
            end
            assert(next(names), "the shelf declares rules at all")

            local sources = {}
            for _, path in ipairs({ "models/combat.lua", "models/status.lua", "models/relic.lua",
                                    "states/game.lua", "states/battle.lua" }) do
                local f = io.open(path, "r")
                if f then sources[#sources + 1] = f:read("*a"); f:close() end
            end
            local blob = table.concat(sources, "\n")
            for name in pairs(names) do
                -- Two mentions: the declaration in data does not count, and a rule read exactly once is
                -- still read. Searching for the bare name is enough -- these are distinctive.
                assert(blob:find(name, 1, true),
                    "rule '" .. name .. "' is declared by a relic but consumed nowhere -- it is inert")
            end
        end,
    },
}
