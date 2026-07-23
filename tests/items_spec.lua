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

return {
    {
        name = "Iron Fist adds flat Power to the bare fist, and nothing to a crafted weapon",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "utility_iron_fist" } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            -- Unarmed Power 2 + damage 0 + Iron Fist +4 = 6, against defense 0.
            assert(punch(c, hero, foe) == 6, "iron fist should push the fist to 6 damage")
            -- A crafted weapon is untouched by the fist bonus (identity check on char.unarmed).
            local sword = Item.instantiate("weapon_iron_sword") -- power 6 + damage 0 = 6, NOT 10
            assert(Combat.computeDamage(c, hero, foe, sword) == 6, "iron fist must not buff a weapon")
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
            -- Two hits of Power 2 each = 4 total.
            assert(punch(c, hero, foe) == 4, "swift fist should deal two 2-damage hits")
        end,
    },
    {
        name = "Drunken Fist only adds Power while the striker is Drunk",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { damage = 0 }, items = { "utility_drunken_fist" } }) },
                { mkunit(2, 3, { stats = { defense = 0, health = 100 } }) })
            local hero, foe = c.units[1], c.units[2]
            assert(punch(c, hero, foe) == 2, "sober: just the bare fist's Power 2")
            Status.apply(c, hero, "status_drunk") -- +3 Damage (statBonus) and +6 drunk fist Power
            -- base = damage 2 + damage(0 + drunk 3) + drunkDamage 6 = 11.
            assert(punch(c, hero, foe) == 11, "drunk: fist swells to 11 damage, got")
        end,
    },
    {
        name = "Toughness raises the health ceiling a heal can reach",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { mkunit(2, 2, { stats = { health = 100 }, items = { "utility_toughness" } }) },
                { mkunit(5, 5, {}) })
            local hero = c.units[1]
            assert(Combat.unreservedMax(hero.char, "health") == 120, "toughness lifts the cap to 120")
            hero.char.stats.health.current = 100
            Combat.applyHeal(c, hero, 30)
            assert(hero.char.stats.health.current == 120, "the heal fills into the raised ceiling")
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
            openTurn(c, hero)
            local _, res = Combat.useItem(c, hero, pen, foe.x, foe.y)
            -- Power 8 with NO defense subtracted (raw). A mitigated hit would floor at 1.
            assert(res.damageDealt == 8, "penetrating strike ignores 100 defense, dealing its Power 8")
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
            hero.char.stats.health.current = 50 -- leave room for the lifesteal heal to show
            openTurn(c, hero)
            local _, res = Combat.useItem(c, hero, hero.char.inventory[1], foe.x, foe.y)
            assert(res.damageDealt == 6, "the sword lands for 6")
            assert(res.healed == 3, "the wielder drinks back half the damage (3)")
            assert(hero.char.stats.health.current == 53, "the lifesteal heal lands on the wielder")
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

            -- Bank damage: a sword strike of Power 6 against defense 0.
            local dealt = Combat.dealDamage(c, hero, foe, Item.instantiate("weapon_iron_sword"))
            assert(dealt == 6, "the strike lands for 6")
            assert(Status.get(hero, "status_fury").recorded == 6, "Fury banks the 6 damage dealt")

            -- A lethal blow cannot fell it while raging: it holds at 1 HP.
            Combat.dealFlatDamage(c, hero, 9999, { "physical" }, "a lethal blow")
            assert(hero.alive and hero.char.stats.health.current == 1, "Fury keeps the bearer up at 1 HP")

            -- When the window closes it heals for half of what it banked (floor(6*0.5) = 3).
            Status.tick(c, 99)
            assert(not Status.has(hero, "status_fury"), "the Fury window has closed")
            assert(hero.char.stats.health.current == 1 + 3, "on expiry Fury heals half the banked damage")
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
            local dealt = Combat.dealDamage(c, foe, wearer, Item.instantiate("weapon_iron_sword"))
            local reflected = foeHp0 - foe.char.stats.health.current
            assert(reflected == math.floor(dealt * 40 / 100), "thorns returns 40% of the blow")
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
            Combat.dealFlatDamage(c, hero, 9999, { "physical" }, "a killing blow")
            assert(hero.alive, "Second Wind refuses the first killing blow")
            assert(hero.char.stats.health.current == 50, "it stands the bearer up at half of max")
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
