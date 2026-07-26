-- Tests for the new combat items and the engine seams they introduced (models/combat.lua,
-- models/status.lua, models/trait.lua): unarmed-fist modifiers (Iron/Shadow/Swift/Drunken Fist),
-- max-resource passives (Toughness), raw armor-piercing damage (Penetrating Strike), the
-- record-state-while-active system (Fury), Thorns reflection, Second Wind revival, Charge, and
-- Taunt steering the enemy AI. Pure logic, so it runs headless.

local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local arena = Fixture.new

-- A { char, x, y } spawn entry on the bandit blueprint, stripped to a bare grid so each mechanic is
-- isolated from a blueprint's incidental kit. Thin wrapper over Fixture.unit for this spec's
-- positional style; `opts.id` picks a different blueprint.
local function mkunit(x, y, opts)
    opts = opts or {}
    return Fixture.unit(opts.id or "character_bandit", x, y, {
        isolate = "bare",
        stats = opts.stats,
        items = opts.items,
    })
end

local openTurn = Fixture.openTurn

-- Deal one unarmed strike from `attacker` at `target` and return the damage dealt.
local function punch(c, attacker, target)
    openTurn(c, attacker)
    local _, res = Combat.useItem(c, attacker, attacker.char.unarmed, target.x, target.y)
    return res.damageDealt
end

-- An item's Power, straight off the blueprint at level 0. Every expected number below is built from
-- these rather than typed in, so retuning a curve retunes the test with it: what these cases assert
-- is the RULE each item adds (the fist gains flat Power, the strike ignores armor, the charm drinks
-- back a share), never the balance number the rule currently lands on.
local function power(id)
    return Combat.abilityMagnitude(Item.instantiate(id).activeAbility)
end

-- A bare fist's Power, the baseline every fist-charm case is measured against.
local function fistPower(unit)
    return Combat.abilityMagnitude(unit.char.unarmed.activeAbility)
end

-- What a fist charm contributes, read off its own unarmedBonus block.
local function fistBonus(id, field)
    return (Item.instantiate(id).unarmedBonus or {})[field or "damage"] or 0
end

return {
    {
        name = "Iron Fist adds flat Power to the bare fist, and nothing to a crafted weapon",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "utility_iron_fist" } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            -- The charm's whole rule: bare Power plus its flat bonus, against a defenseless target.
            local bonus = fistBonus("utility_iron_fist")
            assert(bonus > 0, "this case needs a charm that actually adds Power")
            assert(punch(c, hero, foe) == fistPower(hero) + bonus,
                "the iron fist should add its " .. bonus .. " to the bare strike")
            -- A crafted weapon is untouched by the fist bonus (identity check on char.unarmed): it
            -- lands at its own Power and nothing more.
            local sword = Item.instantiate("weapon_iron_sword")
            assert(Combat.computeDamage(c, hero, foe, sword) == power("weapon_iron_sword"),
                "iron fist must not buff a weapon")
        end,
    },
    {
        name = "Shadow Fist lengthens the fist's reach by a tile",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "utility_shadow_fist" } }) },
                { mkunit(4, 2, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            local ab = hero.char.unarmed.activeAbility
            assert(Combat.abilityRange(c, hero, ab) == 2, "shadow fist -> unarmed range 2")
            -- The foe is two tiles away: out of a normal fist's reach, in range now.
            openTurn(c, hero)
            local ok = Combat.useItem(c, hero, hero.char.unarmed, foe.x, foe.y)
            assert(ok, "the lengthened fist reaches a foe two tiles off")
        end,
    },
    {
        name = "Swift Fist makes the bare strike land twice",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "utility_swift_fist" } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            -- The rule is the SECOND hit, so the expectation is the bare fist doubled -- whatever a
            -- bare fist currently hits for.
            assert(punch(c, hero, foe) == fistPower(hero) * 2,
                "the swift fist should land the bare strike twice")
        end,
    },
    {
        name = "Drunken Fist only adds Power while the striker is Drunk",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "utility_drunken_fist" } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            local sober = fistPower(hero)
            assert(punch(c, hero, foe) == sober, "sober: just the bare fist's Power")

            -- Drunk, three things stack: the bare Power, the status's own Damage bonus, and the
            -- charm's drunk-only Power. All three come off their blueprints, so the case states the
            -- STACKING rule and survives a retune of any of them.
            local drunkDamage = Status.defs.status_drunk.statBonus.damage
            local drunkFist = fistBonus("utility_drunken_fist", "drunkDamage")
            assert(drunkFist > 0, "this case needs a charm that pays out while drunk")

            Status.apply(c, hero, "status_drunk")
            assert(punch(c, hero, foe) == sober + drunkDamage + drunkFist,
                "drunk: the bare fist, the tipsy Damage, and the charm's own Power all stack")
        end,
    },
    {
        name = "Toughness raises the health ceiling a heal can reach",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 100 }, items = { "utility_toughness" } }) },
                { mkunit(5, 5, {}) })
            local hero = c.units[1]
            -- The charm's rule is "lift the ceiling by its own maxBonus, and let a heal reach it".
            local base = hero.char.stats.health.max
            local lift = (Item.instantiate("utility_toughness").maxBonus or {}).health or 0
            assert(lift > 0, "this case needs a charm that actually raises the ceiling")
            local raised = base + lift
            assert(Combat.unreservedMax(hero.char, "health") == raised,
                "toughness lifts the cap to " .. raised)
            hero.char.stats.health.current = base
            Combat.applyHeal(c, hero, lift * 2) -- more than the new headroom: it should just fill it
            assert(hero.char.stats.health.current == raised, "the heal fills into the raised ceiling")
        end,
    },
    {
        name = "Penetrating Strike lands raw, ignoring the target's armor",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "weapon_iron_sword", "ability_penetrating_strike" } }) },
                { mkunit(2, 3, { stats = { defense = 100, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            local pen = hero.char.inventory[2]
            -- The target's armor is set far above the strike's Power on purpose: a MITIGATED hit
            -- would floor at 1, so landing the whole Power is only possible if defense was skipped.
            local raw = power("ability_penetrating_strike")
            assert(foe.char.stats.defense > raw, "the fixture needs armor that would otherwise swallow this")
            openTurn(c, hero)
            local _, res = Combat.useItem(c, hero, pen, foe.x, foe.y)
            assert(res.damageDealt == raw,
                "penetrating strike ignores " .. foe.char.stats.defense .. " defense, dealing its Power " .. raw)
        end,
    },
    {
        name = "the Fury ability drops the caster to 1 HP and opens the berserk window",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 80 }, items = { "ability_fury" } }) },
                { mkunit(5, 5, {}) })
            local hero = c.units[1]
            openTurn(c, hero)
            assert(Combat.useItem(c, hero, hero.char.inventory[1], hero.x, hero.y), "cast Fury on self")
            assert(hero.char.stats.health.current == 1, "Fury spends the caster down to 1 HP")
            assert(Status.has(hero, "status_fury"), "the Fury status is active")
        end,
    },
    {
        name = "Vampiric Strike makes an adjacent weapon heal its wielder on a hit",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0, health = 100 },
                                 items = { "weapon_iron_sword", "utility_vampiric_strike" } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            -- The charm's rule is a SHARE of whatever landed, so the share is read off the charm and
            -- the damage off the sword: neither number is typed in.
            local share = Item.instantiate("utility_vampiric_strike").aura.lifesteal
            assert(share and share > 0, "this case needs a charm that actually drinks")
            local wounded = 50 -- leave room for the lifesteal heal to show
            hero.char.stats.health.current = wounded
            openTurn(c, hero)
            local _, res = Combat.useItem(c, hero, hero.char.inventory[1], foe.x, foe.y)
            assert(res.damageDealt == power("weapon_iron_sword"), "the sword lands for its Power")
            assert(res.healed == math.floor(res.damageDealt * share),
                "the wielder drinks back its share (" .. share .. ") of what landed")
            assert(hero.char.stats.health.current == wounded + res.healed,
                "the lifesteal heal lands on the wielder")
        end,
    },
    {
        name = "previewing/hovering Fury never touches the caster's real HP",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 90 }, items = { "ability_fury" } }) },
                { mkunit(5, 5, {}) })
            local hero = c.units[1]
            local fury = hero.char.inventory[1]
            Combat.previewAbility(c, hero, fury, hero.x, hero.y) -- aim preview (dry run)
            Combat.abilityOutput(hero, fury)                     -- inventory-hover tooltip (dry run)
            assert(hero.char.stats.health.current == 90,
                "a dry-run of Fury must not spend the caster's health")
        end,
    },
    {
        name = "Fury cannot die, banks the damage it deals, and heals half of it when it ends",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 100, damage = 0 } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            Status.apply(c, hero, "status_fury")
            hero.char.stats.health.current = 1

            -- Bank damage: a sword strike against defense 0, so the whole Power lands and is banked.
            local dealt = Combat.dealDamage(c, hero, foe, Item.instantiate("weapon_iron_sword"))
            assert(dealt == power("weapon_iron_sword"), "the strike lands for its Power")
            assert(Status.get(hero, "status_fury").recorded == dealt, "Fury banks what it dealt")

            -- A lethal blow cannot fell it while raging: it holds at 1 HP.
            Combat.dealFlatDamage(c, hero, 9999, { "physical" }, "a lethal blow")
            assert(hero.alive and hero.char.stats.health.current == 1, "Fury keeps the bearer up at 1 HP")

            -- When the window closes it heals for half of what it banked. The fraction is the
            -- status's own (status_fury's onExpire), named here so the sum stays readable.
            local PAYBACK = 0.5
            Status.tick(c, 99)
            assert(not Status.has(hero, "status_fury"), "the Fury window has closed")
            assert(hero.char.stats.health.current == 1 + math.floor(dealt * PAYBACK),
                "on expiry Fury heals half the banked damage")
        end,
    },
    {
        name = "Thorns turns a share of a melee blow back on the attacker",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 200, defense = 0 }, items = { "armor_spike_mail" } }) },
                { mkunit(2, 3, { stats = { health = 100, damage = 30, defense = 0 } }) })
            local wearer, foe = c.units[1], c.units[2]
            local foeHp0 = foe.char.stats.health.current
            -- The foe strikes the spiked wearer; capture what actually landed, then check the reflect.
            -- The foe carries 0 defense, so the reflected hit isn't itself mitigated (it would be, in
            -- general -- the spikes bite armor too) and lands at the full 40% share.
            local Trait = require("models.trait")
            local share = Trait.defs.trait_thorns.magnitude -- percent of the blow reflected
            local dealt = Combat.dealDamage(c, foe, wearer, Item.instantiate("weapon_iron_sword"))
            local reflected = foeHp0 - foe.char.stats.health.current
            assert(reflected == math.floor(dealt * share / 100),
                "thorns returns " .. share .. "% of the blow")
            assert(reflected > 0, "the reflection actually bit")
        end,
    },
    {
        name = "Second Wind catches the first lethal blow and rises at half health",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 100 }, items = { "utility_second_wind" } }) },
                { mkunit(5, 5, {}) })
            local hero = c.units[1]
            -- The fraction is the trait's own (data/traits/trait_second_wind.lua stands the bearer
            -- up at half its unreserved max), named here rather than left as a bare 50.
            local RISE = 0.5
            local max = hero.char.stats.health.max
            Combat.dealFlatDamage(c, hero, 9999, { "physical" }, "a killing blow")
            assert(hero.alive, "Second Wind refuses the first killing blow")
            assert(hero.char.stats.health.current == math.floor(max * RISE),
                "it stands the bearer up at half of max")
            -- Spent: the next lethal blow finishes it.
            Combat.dealFlatDamage(c, hero, 9999, { "physical" }, "the second blow")
            assert(not hero.alive, "Second Wind saves only once a battle")
        end,
    },
    {
        name = "Charge drives the pinned foe and the charger three tiles down the lane",
        fn = function()
            local c = Combat.new(arena(8, 6),
                { mkunit(2, 3, { stats = { stamina = 50 }, items = { "ability_charge" } }) },
                { mkunit(3, 3, { stats = { health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            openTurn(c, hero)
            assert(Combat.useItem(c, hero, hero.char.inventory[1], foe.x, foe.y), "charge the pinned foe")
            assert(foe.x == 6 and foe.y == 3, "the foe is driven three tiles ahead to (6,3)")
            assert(hero.x == 5 and hero.y == 3, "the charger follows one tile behind to (5,3)")
        end,
    },
    {
        name = "Taunt forces the enemy AI onto the taunter, ignoring a nearer foe",
        fn = function()
            -- Enemy flanked by two party units, both adjacent. Without a taunt it could hit either;
            -- taunted, it must go for the taunter.
            local c = Combat.new(arena(8, 8),
                { mkunit(4, 5, {}), mkunit(6, 5, {}) }, -- [1] decoy-near, [2] the taunter
                { mkunit(5, 5, { stats = { stamina = 50 } }) })
            local other, taunter, enemy = c.units[1], c.units[2], c.units[3]
            local st = Status.apply(c, enemy, "status_taunt")
            st.taunter = taunter
            local plan = Combat.planEnemyAction(c, enemy)
            assert(plan.item, "the taunted enemy takes an attack action")
            assert(plan.tx == taunter.x and plan.ty == taunter.y,
                "it swings at the taunter, not the equally-close other foe")
        end,
    },
    {
        name = "a taunter's death strips the Taunt it was holding off every foe",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { mkunit(6, 5, { stats = { health = 1 } }) }, -- the taunter, one blow from falling
                { mkunit(5, 5, {}), mkunit(4, 5, {}) })       -- two foes it had provoked
            local taunter, foeA, foeB = c.units[1], c.units[2], c.units[3]
            for _, foe in ipairs({ foeA, foeB }) do
                local st = Status.apply(c, foe, "status_taunt")
                st.taunter = taunter
            end
            Combat.dealFlatDamage(c, taunter, 9999, {}, "test")
            assert(not taunter.alive, "the taunter has fallen")
            assert(not Status.get(foeA, "status_taunt"), "the first foe's Taunt is gone")
            assert(not Status.get(foeB, "status_taunt"), "the second foe's Taunt is gone")
        end,
    },
    {
        name = "Shout taunts every foe in its area and marks who provoked them",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { mkunit(4, 4, { stats = { stamina = 50 }, items = { "ability_shout" } }) },
                { mkunit(4, 5, { stats = { health = 100 } }), mkunit(4, 3, { stats = { health = 100 } }) })
            local knight, foeA, foeB = c.units[1], c.units[2], c.units[3]
            openTurn(c, knight)
            -- Aim the tile between the two foes; the diamond around it catches both.
            assert(Combat.useItem(c, knight, knight.char.inventory[1], 4, 4), "shout at the crowd")
            for _, foe in ipairs({ foeA, foeB }) do
                local st = Status.get(foe, "status_taunt")
                assert(st, "each nearby foe is taunted")
                assert(st.taunter == knight, "the taunt points back at the shouter")
            end
        end,
    },
    {
        name = "the Spear thrust spits the two tiles directly in front",
        fn = function()
            local c = Combat.new(arena(8, 6),
                { mkunit(2, 3, { stats = { damage = 0, stamina = 50 }, items = { "weapon_iron_spear" } }) },
                { mkunit(3, 3, { stats = { defense = 0, health = 100 } }),
                  mkunit(4, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, near, far = c.units[1], c.units[2], c.units[3]
            local n0, f0 = near.char.stats.health.current, far.char.stats.health.current
            openTurn(c, hero)
            assert(Combat.useItem(c, hero, hero.char.inventory[1], 3, 3), "thrust straight ahead")
            assert(near.char.stats.health.current < n0, "the first tile in line is hit")
            assert(far.char.stats.health.current < f0, "and the second tile behind it too")
        end,
    },
}
